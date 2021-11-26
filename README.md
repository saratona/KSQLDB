# KSQLDB

download zip for connector wikimedia sse:

https://www.confluent.io/hub/cjmatta/kafka-connect-sse

download zip for connector json schema trasformation:

https://www.confluent.io/hub/jcustenborder/kafka-connect-json-schema

metterli nella cartella connectors entrambi in una cartella

docker-compose up

docker exec -it ksqldb-cli ksql http://ksqldb-server:8088

CREATE SOURCE CONNECTOR wikimedia_sse WITH (
    'connector.class' = 'com.github.cjmatta.kafka.connect.sse.ServerSentEventsSourceConnector',
    'sse.uri' = 'https://stream.wikimedia.org/v2/stream/recentchange',
    'topic' = 'wikipedia.parsed',
    'transforms' = 'extractData, parseJSON',
    'transforms.extractData.type' = 'org.apache.kafka.connect.transforms.ExtractField$Value',
    'transforms.extractData.field' = 'data',
    'transforms.parseJSON.type' = 'com.github.jcustenborder.kafka.connect.json.FromJson$Value',
    'transforms.parseJSON.json.exclude.locations' = '#/properties/log_params,#/properties/$schema,#/$schema',
    'transforms.parseJSON.json.schema.location' = 'Url',
    'transforms.parseJSON.json.schema.url' = 'http://raw.githubusercontent.com/wikimedia/mediawiki-event-schemas/master/jsonschema/mediawiki/recentchange/1.0.0.json',
    'transforms.parseJSON.json.schema.validation.enabled' = 'false',
    'producer.interceptor.classes' = 'io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor',
    'value.converter' = 'io.confluent.connect.avro.AvroConverter',
    'value.converter.schema.registry.url' = 'http://schemaregistry:8085',
    'tasks.max' = '1'
);

create a topic: docker-compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic test
