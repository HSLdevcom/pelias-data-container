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
sleep 60
service elasticsearch status &> /dev/null
if [ $? -ne 0 ]; then
    cat  /var/log/elasticsearch/elasticsearch.log
    exit 1
fi

curl localhost:9200 &> /dev/null
if [ $? -ne 0 ]; then
    echo 'curl cound not connect with elastic'
    cat /var/log/elasticsearch/elasticsearch.log
fi

# download and index
$SCRIPTS/dl-and-index.sh

#shutdown ES in a friendly way
service elasticsearch stop

sleep 5
