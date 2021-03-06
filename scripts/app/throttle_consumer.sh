#!/bin/bash

# Usage
if [[ -z "$1" ]] || [[ -z "$2" ]]; then
  echo "Usage: ./throttle_consumer.sh [id 1|2|3] [quota add|delete]"
  exit 1
fi

ID=$1
ACTION=$2

if [ "$ACTION" == "add" ]; then
  # Rate should be low enough to create lag but high enough to not stall the consumer
  CONFIG="--add-config consumer_byte_rate=1024"
else
  CONFIG="--delete-config consumer_byte_rate"
fi

CONSUMER_GROUP="app"

echo "docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --entity-type clients --entity-name consumer_app_1 --alter --delete-config consumer_byte_rate"
docker-compose exec kafka1 bash -c "kafka-configs --bootstrap-server kafka1:9092 --entity-type clients --entity-name consumer_app_1 --alter --delete-config consumer_byte_rate"

echo "docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --entity-type clients --describe"
docker-compose exec kafka1 bash -c 'kafka-configs --bootstrap-server kafka1:9092 --entity-type clients --describe'

echo "docker-compose exec kafka1 kafka-consumer-groups --bootstrap-server kafka1:9092 --describe --group app
docker-compose exec kafka1 kafka-consumer-groups --bootstrap-server kafka1:9092 --describe --group app

