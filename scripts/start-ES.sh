#!/bin/bash

# errors should break the execution
set -e

cd /root

#start elasticsearch, create index and run importers
gosu elasticsearch elasticsearch -d

sleep 20

#schema script runs only from current dir
cd $TOOLS/schema/
node scripts/create_index

echo 'OK' >> /tmp/loadresults
