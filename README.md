# KSQLDB

download zip for connector wikimedia sse:

https://www.confluent.io/hub/cjmatta/kafka-connect-sse

download zip for connector json schema trasformation:

https://www.confluent.io/hub/jcustenborder/kafka-connect-json-schema

metterli nella cartella connectors entrambi in una cartella


per startare tutti i docker del docker-compose.yml:

    docker-compose up
    
Create the connector between Wikimedia and Kafka topic 'wikipedia.parsed':

    #!/bin/bash

    HEADER="Content-Type: application/json"
    DATA=$( cat << EOF
    {
      "name": "wikipedia-sse",
      "config": {
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
      }
    }
    EOF
    )

    
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
