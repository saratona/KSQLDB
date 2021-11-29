# KSQLDB

download zip for connector wikimedia sse:

https://www.confluent.io/hub/cjmatta/kafka-connect-sse

download zip for connector json schema trasformation:

https://www.confluent.io/hub/jcustenborder/kafka-connect-json-schema

metterli nella cartella connectors entrambi in una cartella


per startare tutti i docker del docker-compose.yml:

    docker-compose up
    
runnare docker ksqldb CLI:

    docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
 
Add the custom query property earliest for the auto.offset.reset parameter. This instructs ksqlDB queries to read all available topic data from the beginning. This configuration is used for each subsequent query:

     SET 'auto.offset.reset'='earliest';
    
creare connettore SSE tra Wikimedia e il topic di Kafka "wikipedia.parsed": ./submit_wikipedia_sse_config.sh

create a topic: 

    docker-compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic wikipedia.parsed
    
 TODO: crearli tutti automatizzati con create-topics.sh e functions.sh
 
 eseguire query sql in statements
