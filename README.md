# ksqlDB Tutorial
## Wikipedia changes analysis

This demo builds a Kafka event streaming application using ksqlDB and Kafka Streams for stream processing. Follow the accompanying guided tutorial that steps through the demo so that you can learn how it all works together.

The use case is a Kafka event streaming application for real-time edits to real Wikipedia pages. Wikimedia Foundation has introduced the EventStreams service that allows anyone to subscribe to recent changes to Wikimedia data: edits happening to real wiki pages (e.g. #en.wikipedia, #en.wiktionary) in real time.


## The connectors

Kafka Connect is an open source component of Apache Kafka® that simplifies loading and exporting data between Kafka and external systems. 
Using ksqlDB, you can run any Kafka Connect connector by embedding it in ksqlDB's servers: ksqlDB can double as a Connect server and will run a Distributed Mode cluster co-located on the ksqlDB server instance.

A Kafka source connector [Server Sent Events Source Connector](https://www.confluent.io/hub/cjmatta/kafka-connect-sse) (kafka-connect-sse) streams raw messages from Wkimedia data, a custom Kafka Connect transform [Kafka Connect JSON Schema Trasformations](https://www.confluent.io/hub/jcustenborder/kafka-connect-json-schema) (kafka-connect-json-schema) transforms these messages and then the messages are written to a Kafka cluster. 
This demo uses ksqlDB and a Kafka Streams application for data processing. Then a Kafka sink connector [ElasticSearch Sink Connector](https://www.confluent.io/hub/confluentinc/kafka-connect-elasticsearch) (kafka-connect-elasticsearch) streams the data out of Kafka, and the data is materialized into Elasticsearch for analysis by Kibana. [Confluent Kafka Replicator](https://www.confluent.io/hub/confluentinc/kafka-connect-replicator) (kafka-connect-replicator) is also copying messages from a topic to another topic in the same cluster. All data is using Confluent Schema Registry and Avro.

In the folder ./connectors you find the Connectors described above, downloaded from Confluent Hub.

Data pattern is as follows:

| Components                          | Consumes From                  | Produces To                           |
|-------------------------------------|--------------------------------|-------------------------------------|
| SSE source connector                | Wikipedia                      | ``wikipedia.parsed``                  |
| ksqlDB                              | ``wikipedia.parsed``           | ksqlDB streams and tables             |
| Kafka Streams application           | ``wikipedia.parsed``           | ``wikipedia.parsed.count-by-domain``  |
| Confluent Replicator                | ``wikipedia.parsed``           | ``wikipedia.parsed.replica``          |
| Elasticsearch sink connector        | ``WIKIPEDIABOT`` (from ksqlDB) | Elasticsearch/Kibana                  |


## The docker-compose file

The `docker-compose.yml` file defines the services to launch:

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
              #KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR: 2
              #KAFKA_CONFLUENT_BALANCER_HEAL_BROKER_FAILURE_THRESHOLD_MS: 30000

              KAFKA_DELETE_TOPIC_ENABLE: 'true'
              KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
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
              #KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR: 2
              #KAFKA_CONFLUENT_BALANCER_HEAL_BROKER_FAILURE_THRESHOLD_MS: 30000

              KAFKA_DELETE_TOPIC_ENABLE: 'true'
              KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
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
              #SCHEMA_REGISTRY_CONFLUENT_METADATA_BOOTSTRAP_SERVER_URLS: "kafka1:9092,kafka2:9091"
      
        ksqldb-server:
            image: confluentinc/ksqldb-server:latest
            hostname: ksqldb-server
            container_name: ksqldb-server
            depends_on:
              - kafka1
              - kafka2
              - connect
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

              #KSQL_CONFLUENT_METADATA_BOOTSTRAP_SERVER_URLS: http://kafka1:9092,http://kafka2:9091

        #      KSQL_CONNECT_GROUP_ID: "ksql-connect-cluster"
        #      KSQL_CONNECT_BOOTSTRAP_SERVERS: "kafka1:9092,kafka:9091"
        #      KSQL_CONNECT_KEY_CONVERTER: "org.apache.kafka.connect.storage.StringConverter"
        #      KSQL_CONNECT_VALUE_CONVERTER: "io.confluent.connect.avro.AvroConverter"
        #      KSQL_CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
        #      KSQL_CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: "http://schema-registry:8081"
        #      KSQL_CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE: "false"
        #      KSQL_CONNECT_CONFIG_STORAGE_TOPIC: "ksql-connect-configs"
        #      KSQL_CONNECT_OFFSET_STORAGE_TOPIC: "ksql-connect-offsets"
        #      KSQL_CONNECT_STATUS_STORAGE_TOPIC: "ksql-connect-statuses"
        #      KSQL_CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 2
        #      KSQL_CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 2
        #      KSQL_CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 2
        #      KSQL_CONNECT_PLUGIN_PATH: "/usr/share/kafka/plugins"

        ksqldb-cli:
            image: confluentinc/ksqldb-cli:latest
            container_name: ksqldb-cli
            depends_on:
              - kafka1
              - kafka2
              - connect
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

        connect:
            image: confluentinc/cp-kafka-connect:latest
            container_name: connect
            depends_on:
              - kafka1
              - kafka2
              - schema-registry
            ports:
              - 8083:8083
            volumes:
              - "./connectors/:/usr/share/confluent-hub-components"
            environment:
              CONNECT_BOOTSTRAP_SERVERS: "kafka1:9092,kafka2:9091"
              CONNECT_REST_PORT: 8083
              CONNECT_LISTENERS: http://0.0.0.0:8083
              CONNECT_GROUP_ID: "connect-cluster"
              CONNECT_PRODUCER_CLIENT_ID: "connect-worker-producer"
              CONNECT_PRODUCER_ENABLE_IDEMPOTENCE: 'true'

              CONNECT_CONFIG_STORAGE_TOPIC: connect-configs
              CONNECT_OFFSET_STORAGE_TOPIC: connect-offsets
              CONNECT_STATUS_STORAGE_TOPIC: connect-statuses

              CONNECT_REPLICATION_FACTOR: 2
              CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 2
              CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 2
              CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 2

              CONNECT_KEY_CONVERTER: "org.apache.kafka.connect.storage.StringConverter"
              CONNECT_VALUE_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"

              CONNECT_REST_ADVERTISED_HOST_NAME: connect
              CONNECT_PLUGIN_PATH: "/usr/share/java,/usr/share/confluent-hub-components"

              # Reduce Connect memory utilization
              KAFKA_JVM_PERFORMANCE_OPTS: -server -XX:+UseG1GC -XX:GCTimeRatio=1
                          -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=20
                          -XX:MaxGCPauseMillis=10000 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent
                          -XX:MaxInlineLevel=15 -Djava.awt.headless=true
 

Note that we have two brokers: Kafka1 and Kafka2. Topics are partitioned, meaning a topic is spread over a number of "buckets" located on the two Kafka brokers. This distributed placement of the data is very important for scalability because it allows client applications to both read and write the data from/to two brokers at the same time.
To make the data fault-tolerant and highly-available, every topic is replicated so that there are always two brokers that have a copy of the data just in case things go wrong, you want to do maintenance on the brokers, and so on. 
Schema registry manages the event schemas and maps the schemas to topics, so that producers know which topics are accepting which schemas of events, and consumers know how to read and parse events in a topic.

    #The connect worker’s embedded producer is configured to be idempotent, exactly-once in order semantics per partition (in the event of an error that causes a producer retry, the same message—which is still sent by the producer multiple times—will only be written to the Kafka log on the broker once).


Bring up the entire stack by running:

    docker-compose up -d
    
## Kafka and ksqlDB
    
Create the connector between Wikimedia and Kafka topic 'wikipedia.parsed':

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

In this way the source connector kafka-connect-sse streams the server-sent events (SSE) from https://stream.wikimedia.org/v2/stream/recentchange and a custom connect transform kafka-connect-json-schema extracts the JSON from these messages and then are written to the cluster.
Note that the creation of the connector with the configuration parameter "topic" create the topic with name "wikipedia.parsed" because the configuration KAFKA_AUTO_CREATE_TOPICS_ENABLE of the broker Kafka1 is set to 'true'.
In this way the topic is created with the schema correctly registered. To check it run this command and verify that wikipedia.parsed-value is in the list:

    docker-compose exec schema-registry curl -s -X GET http://schema-registry:8081/subjects
    
Describe the topic, which is the topic that the kafka-connect-sse source connector is writing to. Notice that it also has enabled Schema Validation:

    docker-compose exec kafka1 kafka-topics --describe --topic wikipedia.parsed --bootstrap-server kafka1:9092

Run ksqlDB CLI to get to the ksqlDB CLI prompt:

    docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
    
Create the stream of data from the source:

    CREATE STREAM wikipedia WITH (kafka_topic='wikipedia.parsed', value_format='AVRO');
    
This demo creates two streams `WIKIPEDIANOBOT` and `WIKIPEDIABOT` which respectively filter for bot=falase and bot=true that suggests if the change at the wikipedia page was made by a bot or not.

    CREATE STREAM wikipedianobot AS SELECT *, (length->new - length->old) AS BYTECHANGE FROM wikipedia WHERE bot = false AND length IS NOT NULL AND length->new IS NOT NULL AND length->old IS NOT NULL;
    
    CREATE STREAM wikipediabot AS SELECT *, (length->new - length->old) AS BYTECHANGE FROM wikipedia WHERE bot = true AND length IS NOT NULL AND length->new IS NOT NULL AND length->old IS NOT NULL;
 
Created also a table with a tumbling window which groups and count the changes for users:

    CREATE TABLE wikipedia_count_gt_1 WITH (key_format='JSON') AS SELECT user, meta->uri AS URI, count(*) AS COUNT FROM wikipedia WINDOW TUMBLING (size 300 second) WHERE meta->domain = 'commons.wikimedia.org' GROUP BY user, meta->uri HAVING count(*) > 1;
  

To view the existing ksqlDB streams type `SHOW STREAMS;`

To describe the schema (fields or columns) of an existing ksqlDB stream, for istance WIKIPEDIA type `DESCRIBE WIKIPEDIA;`

View the existing tables typing `SHOW TABLES;`

View the existing ksqlDB queries, which are continuously running: `SHOW QUERIES;`
    
You can view messages from different ksqlDB streams and tables. For instance the following query will show results for newly arriving data:

    select * from WIKIPEDIA EMIT CHANGES;

Run the `SHOW PROPERTIES;` statement and you can see the configured ksqlDB server properties; check these values with the docker-compose.yml file.

!!VEDERE PUNTO 11 DI KSQL

!!consumers?
 
## Replication

Replication is the process of having multiple copies of the data for the sole purpose of availability in case one of the brokers goes down and is unavailable to serve the requests.
In Kafka, replication happens at the partition granularity i.e. copies of the partition are maintained at multiple broker instances using the partition’s write-ahead log. Replication factor defines the number of copies of the partition that needs to be kept; in this demo is set to 2.

Confluent Replicator copies data from a source Kafka cluster to a destination Kafka cluster. The source and destination clusters are typically different clusters, but in this demo, Replicator is doing intra-cluster replication, i.e., the source and destination Kafka clusters are the same.
Replicator is a Kafka Connect source connector and has a corresponding consumer group `connect-replicator`. To create the connector run this:
    
    CREATE SOURCE CONNECTOR replicate-topic WITH (
        "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
        "topic.whitelist": "wikipedia.parsed",
        "topic.rename.format": "\${topic}.replica",
        "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
        "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",

        "dest.kafka.bootstrap.servers": "kafka1:9092",

        "confluent.topic.replication.factor": 1,
        "src.kafka.bootstrap.servers": "kafka1:9092",

        "src.consumer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor",
        "src.consumer.confluent.monitoring.interceptor.bootstrap.servers": "kafka1:9092",

        "src.consumer.group.id": "connect-replicator",

        "src.kafka.timestamps.producer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor",
        "src.kafka.timestamps.producer.confluent.monitoring.interceptor.bootstrap.servers": "kafka1:9092",

        "offset.timestamps.commit": "false",
        "tasks.max": "1",
        "provenance.header.enable": "false"
    ); 
    
In this way it is created a new topic `wikipedia.parsed.replica`. Register the same schema for the replicated topic wikipedia.parsed.replica as was created for the original topic wikipedia.parsed:

    SCHEMA=$docker-compose exec schema-registry curl -s -X GET http://schema-registry:8081/subjects/wikipedia.parsed-value/versions/latest | jq .schema)
    
    docker-compose exec schema-registry curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data "{\"schema\": $SCHEMA}" http://schema-registry:8081/subjects/wikipedia.parsed.replica-value/versions
        
    (se non va -copia risultato del prima comando al posto di $SCHEMA -usa test.sh)

In this case the replicated topic will register with the same schema ID as the original topic. Verify wikipedia.parsed.replica topic is populated and schema is registered:

    docker-compose exec schema-registry curl -s -X GET http://schema-registry:8081/subjects
    
checking if wikipedia.parsed.replica-value is in the list.

Describe the topic just created, which is the topic that Replicator has replicated from wikipedia.parsed:

    docker-compose exec kafka1 kafka-topics --describe --topic wikipedia.parsed.replica --bootstrap-server kafka1:9092
    
## Failed Broker

To simulate a failed broker, stop the Docker container running one of the two Kafka brokers.
Stop the Docker container running Kafka broker 2:

    docker-compose stop kafka2
    
This command will give you the list of the active brokers between brackets:
./bin/zookeeper-shell.sh localhost:2181 ls /brokers/ids

or /usr/local/bin/zookeeper-shell localhost:2181, ls /brokers/ids

docker-compose start kafka2

## Monitoring

Now that the ksqlD is up and the stream of data is correctly created, we want to visualize and do some analysis with Kibana/Elasticsearch.

Run the 'set_elasticsearch_mapping_bot.sh' file and 'set_elasticsearch_mapping_count.sh' in the folder dashboard.
Run the following connector to sink the topic:

    CREATE SINK CONNECTOR elasticsearch-ksqldb WITH (
        "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
        "consumer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor",
        "topics": "WIKIPEDIABOT",
        "topic.index.map": "WIKIPEDIABOT:wikipediabot",
        "connection.url": "http://elasticsearch:9200",
        "type.name": "_doc",
        "key.ignore": true,
        "key.converter.schema.registry.url": "http://schema-registry:8081",
        "value.converter": "io.confluent.connect.avro.AvroConverter",
        "value.converter.schema.registry.url": "http://schema-registry:8081",
        "schema.ignore": true
    );

Check that the data arrived in the index at this location: ADD_LINK

Create the dashboards to visualize the data on Kibana, running the file 'configure_kibana_dashboard.sh' in the folder dashboard.

Go to ADD_LINK to visualize the created dashboards.

foto della dashboard!

## Teardown

To view the connectors created in this demo type:

    SHOW | LIST CONNECTORS;
    
When you're done, tear down the stack by running:
    
    docker-compose down

######################## utility

rimuovere kafka connect


    #docker-compose exec connect curl -X POST -H "${HEADER}" --data "${DATA}" http://connect:8083/connectors || exit 1

 
#Add the custom query property earliest for the auto.offset.reset parameter. This instructs ksqlDB queries to read all available topic data from the beginning. This configuration is used for each subsequent query:

     SET 'auto.offset.reset'='earliest';

create a topic: 

    docker-compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic wikipedia.parsed
