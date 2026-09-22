#!/bin/bash

# This script is run inside base docker container to add the geocoding data to ES

# errors should break the execution
set -e

# main Docker script has already created these:
export TOOLS=/mnt/tools
export DATA=/mnt/data
export SCRIPTS=$TOOLS/scripts

# Launch Elasticsearch
cd /root

service elasticsearch start

# Poll for Elasticsearch readiness instead of a fixed sleep, so we proceed as
# soon as it's up and still fail fast (with logs) if it never comes up.
ES_WAIT_MAX_ATTEMPTS=60
ES_WAIT_INTERVAL=2
attempt=1
until curl -sS -o /dev/null localhost:9200; do
    if [ $attempt -ge $ES_WAIT_MAX_ATTEMPTS ]; then
        echo "ERROR: Elasticsearch did not become ready in time"
        service elasticsearch status
        cat /var/log/elasticsearch/elasticsearch.log
        exit 1
    fi
    echo "Waiting for Elasticsearch to start (attempt $attempt/$ES_WAIT_MAX_ATTEMPTS)..."
    attempt=$((attempt + 1))
    sleep $ES_WAIT_INTERVAL
done
echo "Elasticsearch is up"

# download and index
$SCRIPTS/dl-and-index.sh

#shutdown ES in a friendly way
service elasticsearch stop

sleep 5
