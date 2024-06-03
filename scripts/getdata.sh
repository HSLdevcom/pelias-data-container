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

gosu elasticsearch /usr/share/elasticsearch/bin/elasticsearch -p /tmp/elasticsearch-pid -d

sleep 40

curl localhost:9200 &> /dev/null
if [ $? -ne 0 ]; then
    echo 'curl cound not connect with elastic'
    cat /var/log/elasticsearch/elasticsearch.log
fi

# download and index
$SCRIPTS/dl-and-index.sh

#shutdown ES in a friendly way
pid=$(cat /tmp/elasticsearch-pid)
kill -SIGTERM $pid

sleep 5
