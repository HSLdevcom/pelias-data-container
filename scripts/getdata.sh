#!/bin/bash

# This script is run inside base docker container to add the geocoding data to ES

# errors should break the execution
set -e

# main Docker script has already created these:
export TOOLS=/mnt/tools
export DATA=/mnt/data

# Launch Elasticsearch
cd /root

gosu elasticsearch elasticsearch -d
sleep 20

# download and index
$TOOLS/scripts/dl-and-index.sh

#shutdown ES in a friendly way
pkill -SIGTERM -u elasticsearch
sleep 3
