This demo builds a Kafka event streaming application using ksqlDB and Kafka Streams for stream processing. Follow the accompanying guided tutorial that steps through the demo so that you can learn how it all works together.

The use case is a Kafka event streaming application for real-time edits to real Wikipedia pages. Wikimedia Foundation has introduced the EventStreams service that allows anyone to subscribe to recent changes to Wikimedia data: edits happening to real wiki pages (e.g. #en.wikipedia, #en.wiktionary) in real time.


The connectors

Using Kafka Connect, a Kafka source connector [Server Sent Events Source Connector](https://www.confluent.io/hub/cjmatta/kafka-connect-sse) (kafka-connect-sse) streams raw messages from Wkimedia data, and a custom Kafka Connect transform [Kafka Connect JSON Schema Trasformations](https://www.confluent.io/hub/jcustenborder/kafka-connect-json-schema) (kafka-connect-json-schema) transforms these messages and then the messages are written to a Kafka cluster. 
This demo uses ksqlDB and a Kafka Streams application for data processing. Then a Kafka sink connector [ElasticSearch Sink Connector](https://www.confluent.io/hub/confluentinc/kafka-connect-elasticsearch) (kafka-connect-elasticsearch) streams the data out of Kafka, and the data is materialized into Elasticsearch for analysis by Kibana. [Confluent Kafka Replicator](https://www.confluent.io/hub/confluentinc/kafka-connect-replicator) (kafka-connect-replicator) is also copying messages from a topic to another topic in the same cluster. All data is using Confluent Schema Registry and Avro.

In the folder ./connectors you find the Connectors described above, downloaded from Confluent Hub.

Data pattern is as follows:

+-------------------------------------+--------------------------------+---------------------------------------+
| Components                          | Consumes From                  | Produces To                           |
+=====================================+================================+=======================================+
| SSE source connector                | Wikipedia                      | ``wikipedia.parsed``                  |
+-------------------------------------+--------------------------------+---------------------------------------+
| ksqlDB                              | ``wikipedia.parsed``           | ksqlDB streams and tables             |
+-------------------------------------+--------------------------------+---------------------------------------+
| Kafka Streams application           | ``wikipedia.parsed``           | ``wikipedia.parsed.count-by-domain``  |
+-------------------------------------+--------------------------------+---------------------------------------+
| Confluent Replicator                | ``wikipedia.parsed``           | ``wikipedia.parsed.replica``          |
+-------------------------------------+--------------------------------+---------------------------------------+
| Elasticsearch sink connector        | ``WIKIPEDIABOT`` (from ksqlDB) | Elasticsearch/Kibana                  |
+-------------------------------------+--------------------------------+---------------------------------------+


The docker-compose file

The     docker-compose.yml  file defines the services to launch:


paste here

Note that we have two brokers: Kafka1 and Kafka2. Topics are partitioned, meaning a topic is spread over a number of "buckets" located on the two Kafka brokers. This distributed placement of the data is very important for scalability because it allows client applications to both read and write the data from/to two brokers at the same time.
To make the data fault-tolerant and highly-available, every topic is replicated so that there are always two brokers that have a copy of the data just in case things go wrong, you want to do maintenance on the brokers, and so on. 


Bring up the entire stack by running:

    docker-compose up -d
    
Create the connector between Wikimedia and Kafka topic 'wikipedia.parsed':

    CREATE SOURCE CONNECTOR wikipedia-sse WITH (
        "connector.class": "com.github.cjmatta.kafka.connect.sse.ServerSentEventsSourceConnector",
        "sse.uri": "https://stream.wikimedia.org/v2/stream/recentchange",
        "topic": "wikipedia.parsed",
        "transforms": "extractData, parseJSON",
        "transforms.extractData.type": "org.apache.kafka.connect.transforms.ExtractField\$Value",
        "transforms.extractData.field": "data",
        "transforms.parseJSON.type": "com.github.jcustenborder.kafka.connect.json.FromJson\$Value",
        "transforms.parseJSON.json.exclude.locations": "#/properties/log_params,#/properties/\$schema,#/\$schema",
        "transforms.parseJSON.json.schema.location": "Url",
        "transforms.parseJSON.json.schema.url": "https://raw.githubusercontent.com/wikimedia/mediawiki-event-schemas/master/jsonschema/mediawiki/recentchange/1.0.0.json",
        "transforms.parseJSON.json.schema.validation.enabled": "false",
        "producer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor",
        "value.converter": "io.confluent.connect.avro.AvroConverter",
        "value.converter.schema.registry.url": "http://schema-registry:8081",
        "tasks.max": "1"
    );

    
runnare docker ksqldb CLI:

    docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
    
Run this query in ksql:

    CREATE STREAM wikipedia WITH (kafka_topic='wikipedia.parsed', value_format='AVRO');
    
    CREATE STREAM wikipedianobot AS SELECT *, (length->new - length->old) AS BYTECHANGE FROM wikipedia WHERE bot = false AND length IS NOT NULL AND length->new IS              NOT NULL AND length->old IS NOT NULL;
    
    CREATE STREAM wikipediabot AS SELECT *, (length->new - length->old) AS BYTECHANGE FROM wikipedia WHERE bot = true AND length IS NOT NULL AND length->new IS NOT NULL AND length->old IS NOT NULL;
    
    CREATE TABLE wikipedia_count_gt_1 WITH (key_format='JSON') AS SELECT user, meta->uri AS URI, count(*) AS COUNT FROM wikipedia WINDOW TUMBLING (size 300 second) WHERE meta->domain = 'commons.wikimedia.org' GROUP BY user, meta->uri HAVING count(*) > 1;
    
Now we want to create the connector with Kibana/Elasticsearch and create the index pattern:

Run the 'set_elasticsearch_mapping_bot.sh' file and 'set_elasticsearch_mapping_count.sh' in the folder dashboard.
Create the connector:

    #!/bin/bash

    HEADER="Content-Type: application/json"
    DATA=$( cat << EOF
    {
      "name": "elasticsearch-ksqldb",
      "config": {
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

      }
    }
    EOF
    )
    
Create the dashboards to visualize the data on Kibana, running the file 'configure_kibana_dashboard.sh' in the folder dashboard.


    docker-compose exec connect curl -X POST -H "${HEADER}" --data "${DATA}" http://connect:8083/connectors || exit 1

 
#Add the custom query property earliest for the auto.offset.reset parameter. This instructs ksqlDB queries to read all available topic data from the beginning. This configuration is used for each subsequent query:

     SET 'auto.offset.reset'='earliest';
    
creare connettore SSE tra Wikimedia e il topic di Kafka "wikipedia.parsed": ./submit_wikipedia_sse_config.sh

create a topic: 

    docker-compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic wikipedia.parsed
    
 TODO: crearli tutti automatizzati con create-topics.sh e functions.sh
 
 eseguire query sql in statements
