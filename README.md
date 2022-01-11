# ksqlDB Tutorial - Wikipedia changes analysis

This material is derived from the [cp-demo](https://docs.confluent.io/5.5.0/tutorials/cp-demo/docs/index.html) in the [confluentinc github](https://github.com/confluentinc/cp-demo).

## Overview

This example and accompanying tutorial show users how to deploy an Apache Kafka® event streaming application using [ksqlDB](https://ksqldb.io/?utm_source=github&utm_medium=demo&utm_campaign=ch.cp-demo_type.community_content.cp-demo) and [Kafka Streams](https://docs.confluent.io/platform/current/streams/index.html?utm_source=github&utm_medium=demo&utm_campaign=ch.cp-demo_type.community_content.cp-demo) for stream processing.

ksqlDB is the streaming SQL engine for Apache Kafka®. It provides an easy-to-use yet powerful interactive SQL interface for stream processing on Kafka, without the need to write code in a programming language such as Java or Python. ksqlDB is scalable, elastic, fault-tolerant, and real-time. It supports a wide range of streaming operations, including data filtering, transformations, aggregations, joins, windowing, and sessionization.

Kafka Streams is a Java API that gives you easy access to all of the computational primitives of stream processing: filtering, grouping, aggregating, joining, and more, keeping you from having to write framework code on top of the consumer API to do all those things. It also provides support for the potentially large amounts of state that result from stream processing computations.

The use case is a Kafka event streaming application for real-time edits to real Wikipedia pages. Wikimedia Foundation has introduced the EventStreams service that allows anyone to subscribe to recent changes to Wikimedia data: edits happening to real wiki pages (e.g. #en.wikipedia, #en.wiktionary) in real time.

Follow the accompanying guided tutorial, broken down step-by-step, to learn how Kafka works with Schema Registry, Kafka Streams and Connect.

## Schema registry

![schemaregistry](https://github.com/saratona/KSQLDB/blob/main/images/schemaregistry-overview.png)
Schema Registry is a standalone server process that runs on a machine external to the Kafka brokers. Its job is to maintain a database of all of the schemas that have been written into topics in the cluster for which it is responsible. That “database” is persisted in an internal Kafka topic and cached in the Schema Registry for low-latency access.

All the applications and connectors used in this demo are configured to automatically read and write Avro-formatted data, leveraging the Schema Registry.

## Kafka Connect

![connect](https://github.com/saratona/KSQLDB/blob/main/images/connect-overview.png)

In the world of information storage and retrieval, some systems are not Kafka. Sometimes you would like the data in those other systems to get into Kafka topics, and sometimes you would like data in Kafka topics to get into those systems. As Apache Kafka's integration API, this is exactly what Kafka Connect does.
Kafka Connect is an open source component of Apache Kafka® that simplifies loading and exporting data between Kafka and external systems. 

Using ksqlDB, you can run any Kafka Connect connector by embedding it in ksqlDB's servers: ksqlDB can double as a Connect server and will run a Distributed Mode cluster co-located on the ksqlDB server instance.

### The connectors

Wikimedia’s EventStreams publishes a continuous stream of real-time edits happening to real wiki pages. A Kafka source connector [Server Sent Events Source Connector](https://www.confluent.io/hub/cjmatta/kafka-connect-sse) (kafka-connect-sse) streams the server-sent events (SSE) from https://stream.wikimedia.org/v2/stream/recentchange, and a custom Connect transform [Kafka Connect JSON Schema Trasformations](https://www.confluent.io/hub/jcustenborder/kafka-connect-json-schema) (kafka-connect-json-schema) extracts the JSON from these messages and then are written to a Kafka cluster. This example uses ksqlDB and a Kafka Streams application for data processing. Then a Kafka sink connector [ElasticSearch Sink Connector](https://www.confluent.io/hub/confluentinc/kafka-connect-elasticsearch) (kafka-connect-elasticsearch) streams the data out of Kafka and is materialized into Elasticsearch for analysis by Kibana. [Replicator](https://www.confluent.io/hub/confluentinc/kafka-connect-replicator) (kafka-connect-replicator) is also copying messages from a topic to another topic in the same cluster. All data is using Schema Registry and Avro.

![kafka](https://github.com/saratona/KSQLDB/blob/main/images/kafka-overview.png)

In the folder ./connectors you find the Connectors described above, downloaded from Confluent Hub.

### Data pattern

| Components                          | Consumes From                  | Produces To                           |
|-------------------------------------|--------------------------------|-------------------------------------|
| SSE source connector                | Wikipedia                      | ``wikipedia.parsed``                  |
| ksqlDB                              | ``wikipedia.parsed``           | ksqlDB streams and tables             |
| Confluent Replicator                | ``wikipedia.parsed``           | ``wikipedia.parsed.replica``          |
| Elasticsearch sink connector        | ``WIKIPEDIABOT`` (from ksqlDB) | Elasticsearch/Kibana                  |

In this demo are removed all the security references.

## The docker-compose file

The `docker-compose.yml` file defines the services to launch:

```yaml
---
version: '2'

services:

  zookeeper:
    image: confluentinc/cp-zookeeper:7.0.1
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_SERVER_CNXN_FACTORY: org.apache.zookeeper.server.NettyServerCnxnFactory

  kafka1:
    image: confluentinc/cp-kafka:7.0.1
    hostname: kafka1
    container_name: kafka1
    depends_on:
      - zookeeper
    ports:
      - "8092:8092"
      - "9092:9092"
      - "29092:29092"
    environment:
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_ZOOKEEPER_CLIENT_CNXN_SOCKET: org.apache.zookeeper.ClientCnxnSocketNetty

      KAFKA_BROKER_ID: 1
      KAFKA_BROKER_RACK: "r1"
      KAFKA_JMX_PORT: 9991

      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka1:9092,PLAINTEXT_HOST://localhost:29092

      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 2
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 2
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1

      KAFKA_DELETE_TOPIC_ENABLE: 'true'
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'false'
      KAFKA_DEFAULT_REPLICATION_FACTOR: 2

      KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL: http://schema-registry:8081

  kafka2:
    image: confluentinc/cp-kafka:7.0.1
    hostname: kafka2
    container_name: kafka2
    depends_on:
      - zookeeper
    ports:
      - "8091:8091"
      - "9091:9091"
      - "29091:29091"
    environment:
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_ZOOKEEPER_CLIENT_CNXN_SOCKET: org.apache.zookeeper.ClientCnxnSocketNetty

      KAFKA_BROKER_ID: 2
      KAFKA_BROKER_RACK: "r2"
      KAFKA_JMX_PORT: 9992

      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka2:9091,PLAINTEXT_HOST://localhost:29091

      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 2
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 2
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1

      KAFKA_DELETE_TOPIC_ENABLE: 'true'
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'false'
      KAFKA_DEFAULT_REPLICATION_FACTOR: 2

      KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL: http://schema-registry:8081

  schema-registry:
    image: confluentinc/cp-schema-registry:7.0.1
    hostname: schema-registry
    container_name: schema-registry
    depends_on:
      - kafka1
      - kafka2
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      #SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL: 'zookeeper:2181'
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka1:9092,kafka2:9091

      SCHEMA_REGISTRY_LISTENERS: "http://0.0.0.0:8081"

      SCHEMA_REGISTRY_KAFKASTORE_TOPIC: _schemas
      SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR: 2

      SCHEMA_REGISTRY_DEBUG: 'true'

  ksqldb-server:
    image: confluentinc/ksqldb-server:0.23.1
    hostname: ksqldb-server
    container_name: ksqldb-server
    depends_on:
      - kafka1
      - kafka2
    ports:
      - "8088:8088"
    volumes:
      - "./connectors/:/usr/share/kafka/plugins/"
      - "./scripts/helper:/tmp/helper"
    environment:
      KSQL_KSQL_SERVICE_ID: "ksql-cluster"
      KSQL_KSQL_STREAMS_REPLICATION_FACTOR: 2
      KSQL_KSQL_INTERNAL_TOPIC_REPLICAS: 2

      # For Demo purposes: improve resource utilization and avoid timeouts
      KSQL_KSQL_STREAMS_NUM_STREAM_THREADS: 1

      KSQL_PRODUCER_ENABLE_IDEMPOTENCE: 'true'

      KSQL_LISTENERS: "http://0.0.0.0:8088"
      KSQL_BOOTSTRAP_SERVERS: "kafka1:9092,kafka2:9091"
      KSQL_HOST_NAME: ksqldb-server
      KSQL_CACHE_MAX_BYTES_BUFFERING: 0

      KSQL_KSQL_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
      COMPOSE_HTTP_TIMEOUT: 90

      KSQL_LOG4J_OPTS: "-Dlog4j.configuration=file:/tmp/helper/log4j.properties"
      KSQL_KSQL_LOGGING_PROCESSING_TOPIC_REPLICATION_FACTOR: 2
      KSQL_KSQL_LOGGING_PROCESSING_TOPIC_AUTO_CREATE: 'true'
      KSQL_KSQL_LOGGING_PROCESSING_STREAM_AUTO_CREATE: 'true'

      #embedded Kafka Connect
      KSQL_CONNECT_GROUP_ID: "ksql-connect-cluster"
      KSQL_CONNECT_BOOTSTRAP_SERVERS: "kafka1:9092,kafka:9091"
      KSQL_CONNECT_KEY_CONVERTER: "org.apache.kafka.connect.storage.StringConverter"
      KSQL_CONNECT_VALUE_CONVERTER: "io.confluent.connect.avro.AvroConverter"
      KSQL_CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
      KSQL_CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
      KSQL_CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE: "false"
      KSQL_CONNECT_CONFIG_STORAGE_TOPIC: "ksql-connect-configs"
      KSQL_CONNECT_OFFSET_STORAGE_TOPIC: "ksql-connect-offsets"
      KSQL_CONNECT_STATUS_STORAGE_TOPIC: "ksql-connect-statuses"
      KSQL_CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 2
      KSQL_CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 2
      KSQL_CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 2
      KSQL_CONNECT_PLUGIN_PATH: "/usr/share/kafka/plugins"

  ksqldb-cli:
    image: confluentinc/ksqldb-cli:0.23.1
    container_name: ksqldb-cli
    depends_on:
      - kafka1
      - kafka2
      - ksqldb-server
    volumes:
      - ./scripts/ksqlDB/statements.sql:/tmp/statements.sql
    entrypoint: /bin/sh
    tty: true

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.0
    hostname: elasticsearch
    container_name: elasticsearch
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      discovery.type: single-node
      ES_JAVA_OPTS: "-Xms1g -Xmx1g"
      cluster.name: "elasticsearch-cp-demo"

  kibana:
    image: docker.elastic.co/kibana/kibana-oss:7.10.0
    container_name: kibana
    depends_on:
      - elasticsearch
    ports:
      - 5601:5601
    environment:
      NEWSFEED_ENABLED: 'false'
      TELEMETRY_OPTIN: 'false'
      TELEMETRY_ENABLED: 'false'
      SERVER_MAXPAYLOADBYTES: 4194304
      KIBANA_AUTOCOMPLETETIMEOUT: 3000
      KIBANA_AUTOCOMPLETETERMINATEAFTER: 2500000
```

There are a few things to notice here: first of all we have two brokers: kafka1 and kafka2. Each broker hosts some set of partitions and handles incoming requests to write new events to those partitions or read events from them. Brokers also handle replication of partitions between each other. Indeed brokers and their underlying storage are susceptible to failure, so we need to copy partition data to other brokers to keep it safe. As you can see from the `docker-compose.yml` in this demo the replication factor is set to 2.

Bring up the entire stack by running:

    docker-compose up -d
    
## ksqlDB
    
Create the topic `wikipedia.parsed`:

    docker-compose exec kafka1 kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 2 --partitions 2 --topic wikipedia.parsed

Open another shell and run ksqlDB CLI to get to the ksqlDB CLI prompt:

    docker exec -it ksqldb-cli ksql http://ksqldb-server:8088

Every ksql command will be run from this shell.

Create the connector between Wikimedia and Kafka topic `wikipedia.parsed` :

```sql
CREATE SOURCE CONNECTOR wikipedia_sse WITH (
    'connector.class' = 'com.github.cjmatta.kafka.connect.sse.ServerSentEventsSourceConnector',
    'sse.uri' = 'https://stream.wikimedia.org/v2/stream/recentchange',
    'topic' = 'wikipedia.parsed',
    'transforms' = 'extractData, parseJSON',
    'transforms.extractData.type' = 'org.apache.kafka.connect.transforms.ExtractField\$Value',
    'transforms.extractData.field' = 'data',
    'transforms.parseJSON.type' = 'com.github.jcustenborder.kafka.connect.json.FromJson\$Value',
    'transforms.parseJSON.json.exclude.locations' = '#/properties/log_params,#/properties/\$schema,#/\$schema',
    'transforms.parseJSON.json.schema.location' = 'Url',
    'transforms.parseJSON.json.schema.url' = 'https://raw.githubusercontent.com/wikimedia/mediawiki-event-schemas/master/jsonschema/mediawiki/recentchange/1.0.0.json',
    'transforms.parseJSON.json.schema.validation.enabled' = 'false',
    'producer.interceptor.classes' = 'io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor',
    'value.converter' = 'io.confluent.connect.avro.AvroConverter',
    'value.converter.schema.registry.url' = 'http://schema-registry:8081',
    'tasks.max' = '1'
);
```

Note that if in the docker configuration of the brokers KAFKA_AUTO_CREATE_TOPICS_ENABLE was set to 'true', the creation of the connector would imply the creation of the topic with name in the configuration parameter 'topic'. The parameter is set to false because the demo requires to set customed configurations in the creation of the topics. For example the default value of partitions is 1 when the auto-creation of the topic is on, but we want it to be equal to 2.

Partitioning takes the single topic log and breaks it into multiple logs, each of which can live on a separate node in the Kafka cluster. This way, the work of storing messages, writing new messages, and processing existing messages can be split among many nodes in the cluster.

The creation of the connector guarantees that the topic's `wikipedia.parsed` value is using a schema registered with Schema Registry. 

To check it run this command to view the Schema Registry subjects for topics that have registered schemas for their keys and/or values:

    docker-compose exec schema-registry curl -s -X GET http://schema-registry:8081/subjects
    
verify that wikipedia.parsed-value is in the list.

Describe the only topic that exists up to now, which is the topic that the kafka-connect-sse source connector is writing to.

    docker-compose exec kafka1 kafka-topics --describe --topic wikipedia.parsed --bootstrap-server kafka1:9092
    
Note the partitions and the replicas.
    
From the ksqlDB CLI prompt create the stream of data from the source:

```sql
CREATE STREAM wikipedia WITH (kafka_topic='wikipedia.parsed', value_format='AVRO');
 ```
 
This demo creates other two streams: `WIKIPEDIANOBOT` and `WIKIPEDIABOT` which respectively filter for bot = falase and bot = true that suggests if the change at the Wikipedia page was made by a bot or not.

```sql
CREATE STREAM wikipedianobot AS SELECT *, (length->new - length->old) AS BYTECHANGE FROM wikipedia WHERE bot = false AND length IS NOT NULL AND length->new IS NOT NULL AND length->old IS NOT NULL;
    
CREATE STREAM wikipediabot AS SELECT *, (length->new - length->old) AS BYTECHANGE FROM wikipedia WHERE bot = true AND length IS NOT NULL AND length->new IS NOT NULL AND length->old IS NOT NULL;
```

Create also a table with a tumbling window which groups and count the changes made by every users (that made at least one modification):

```sql
CREATE TABLE wikipedia_count_gt_1 WITH (key_format='JSON') AS SELECT user, meta->uri AS URI, count(*) AS COUNT FROM wikipedia WINDOW TUMBLING (size 300 second) WHERE meta->domain = 'commons.wikimedia.org' GROUP BY user, meta->uri HAVING count(*) > 1;
```  

To view the existing ksqlDB streams type `SHOW STREAMS;`

To describe the schema (fields or columns) of an existing ksqlDB stream, for istance WIKIPEDIA type `DESCRIBE WIKIPEDIA;`

View the existing tables typing `SHOW TABLES;`

View the existing ksqlDB queries, which are continuously running: `SHOW QUERIES;`
    
You can view messages from different ksqlDB streams and tables. For instance the following query will show results for newly arriving data:

```sql
select * from WIKIPEDIA EMIT CHANGES;
```

Press Ctrl+C for interrupt the streams of data.

Run the `SHOW PROPERTIES;` statement and you can see the configured ksqlDB server properties; check these values with the `docker-compose.yml` file.

## Consumers

Consumer lag is the topic’s high water mark (latest offset for the topic that has been written) minus the current consumer offset (latest offset read for that topic by that consumer group). Keep in mind the topic’s write rate and consumer group’s read rate when you consider the significance the consumer lag’s size.

Consumer lag is available on a per-consumer basis, including the embedded Connect consumers for sink connectors, ksqlDB queries, console consumers.

Create an additional consumer to read from topic WIKIPEDIANOBOT:

    docker exec schema-registry kafka-avro-console-consumer --bootrap-server kafka1:9092,kafka2:9091 --topic WIKIPEDIANOBOT --group listen-consumer > /dev/null 2>&1 &
    
Running this command from the schema-registry docker the consumer will automatically register with Schema Registry.

Visualize the list of the consumers groups:

    docker exec zookeeper kafka-consumer-groups --list --bootstrap-server kafka2:9091

Visualize the list of the consumers in the consumer group listen-consumer:

    docker exec zookeeper kafka-consumer-groups --bootstrap-server kafka2:9091 --describe --group listen-consumer
 
## Replication

Replication is the process of having multiple copies of the data for the sole purpose of availability in case one of the brokers goes down and is unavailable to serve the requests.
In Kafka, replication happens at the partition granularity i.e. copies of the partition are maintained at multiple broker instances using the partition’s write-ahead log. Replication factor defines the number of copies of the partition that needs to be kept.

In this demo Replicator copies data from a source Kafka cluster to a destination Kafka cluster. The source and destination clusters are typically different clusters, but in this demo, Replicator is doing intra-cluster replication, i.e., the source and destination Kafka clusters are the same.
Replicator is a Kafka Connect source connector and has a corresponding consumer group `connect-replicator`. 

Create the connector:
    
```sql
CREATE SOURCE CONNECTOR replicate_topic WITH (
    'connector.class' = 'io.confluent.connect.replicator.ReplicatorSourceConnector',
    'topic.whitelist' = 'wikipedia.parsed',
    'topic.rename.format' = '\${topic}.replica',
    'key.converter' = 'io.confluent.connect.replicator.util.ByteArrayConverter',
    'value.converter' = 'io.confluent.connect.replicator.util.ByteArrayConverter',

    'dest.kafka.bootstrap.servers' = 'kafka1:9092',

    'confluent.topic.replication.factor' = 1,
    'src.kafka.bootstrap.servers' = 'kafka1:9092',

    'src.consumer.group.id' = 'connect-replicator',

    'offset.timestamps.commit' = 'false',
    'tasks.max' = '1',
    'provenance.header.enable' = 'false'
); 
```

In this way it is created a new topic `wikipedia.parsed.replica` that is a replica of `wikipedia.parsed`. 

You have to register the same schema for the replicated topic as was created for the original topic. Run the file schema-replica.sh:
  
    ./scripts/schema-replica.sh

In this file there are two commands:
- the first saves the schema of the topic `wikipedia.parsed` in the variable SCHEMA:

      SCHEMA=$(docker-compose exec schema-registry curl -s -X GET http://schema-registry:8081/subjects/wikipedia.parsed-value/versions/latest | jq .schema
    
- the second gives SCHEMA as schema of the topic `wikipedia.parsed.replica`:

      docker-compose exec schema-registry curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data "{\"schema\": $SCHEMA}" http://schema-registry:8081/subjects/wikipedia.parsed.replica-value/versions

Now verify wikipedia.parsed.replica topic is populated and schema is registered:

    docker-compose exec schema-registry curl -s -X GET http://schema-registry:8081/subjects
    
checking if wikipedia.parsed.replica-value is in the list.

Describe the topic just created, which is the topic that Replicator has replicated from `wikipedia.parsed`:

    docker-compose exec kafka1 kafka-topics --describe --topic wikipedia.parsed.replica --bootstrap-server kafka1:9092
    
## Failed Broker

To simulate a failed broker, stop the Docker container running one of the two Kafka brokers.
Stop the Docker container running Kafka broker 2:

    docker-compose stop kafka2
    
This command will give you the list of the IDs of the active brokers between brackets:

    docker exec zookeeper zookeeper-shell localhost:2181 ls /brokers/ids

Note that there is only the ID 1 because broker 2 (kafka2) has been stopped.
    
From the ksqlDB cli prompt try to view the streams of data as before:

```sql
select * from WIKIPEDIA EMIT CHANGES;
```

and note that all is still working. Press Ctrl+C to interrupt the stream.

Restart the Docker container running Kafka broker 2:

    docker-compose start kafka2

## Monitoring

Now that the ksqlD is up and the stream of data is correctly created, we want to visualize and do some analysis with Kibana/Elasticsearch.

Run the 'set_elasticsearch_mapping_bot.sh' file and 'set_elasticsearch_mapping_count.sh' in the folder dashboard.

    ./dashboard/set_elasticsearch_mapping_bot.sh
    ./dashboard/set_elasticsearch_mapping_count.sh
    
Run the following connector to sink the topic:

```sql
CREATE SINK CONNECTOR elasticsearch_ksqldb WITH (
    'connector.class' = 'io.confluent.connect.elasticsearch.ElasticsearchSinkConnector',
    'topics' = 'WIKIPEDIABOT',
    'topic.index.map' = 'WIKIPEDIABOT:wikipediabot',
    'connection.url' = 'http://elasticsearch:9200',
    'type.name' = '_doc',
    'key.ignore' = true,
    'key.converter.schema.registry.url' = 'http://schema-registry:8081',
    'value.converter' = 'io.confluent.connect.avro.AvroConverter',
    'value.converter.schema.registry.url' = 'http://schema-registry:8081',
    'schema.ignore' = true
);
```

Create the dashboards to visualize the data on Kibana, running the file 'configure_kibana_dashboard.sh' in the folder dashboard.

    ./dashboard/configure_kibana_dashboard.sh

Go to [http://localhost:5601/app/dashboards#/view/Overview](http://localhost:5601/app/dashboards#/view/Overview?_g=h@ac5c3b7&_a=h@295d1b7) to visualize the created dashboards.

![kibana](https://github.com/saratona/KSQLDB/blob/main/images/kibana-dashboard.png)

## Teardown

To view the connectors created in this demo type:

    SHOW | LIST CONNECTORS;
    
When you're done, tear down the stack by running:
    
    docker-compose down
