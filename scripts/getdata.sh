#!/bin/bash

# main Docker script has already created these:
export TOOLS=/mnt/tools
export DATA=/mnt/data
SCRIPTS=$TOOLS/scripts

#=========================================
# Install importers and their dependencies
#=========================================

set -x
set -e
apt-get update
apt-get install -y --no-install-recommends git unzip python python-pip python-dev build-essential gdal-bin rlwrap
rm -rf /var/lib/apt/lists/*

mkdir -p $TOOLS
curl -sS https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.15-1nodesource1~jessie1_amd64.deb > $TOOLS/node.deb
dpkg -i $TOOLS/node.deb

# install npm packages in parallel
# NOTE!!! update package count check below if you add new npm install lines

$SCRIPTS/install-dbclient.sh &
$SCRIPTS/install-schema.sh &
$SCRIPTS/install-wof-pip-service.sh &

#must sync here, next installations will link with packages above
wait

$SCRIPTS/install-wof-admin-lookup &
$SCRIPTS/install-openstreetmap &
$SCRIPTS/install-openaddresses &
$SCRIPTS/install-polylines &
$SCRIPTS/install-pelias-nlsfi-places-importer &
$SCRIPTS/install-pelias-gtfs &

wait

ok_count=$(cat /tmp/npmlog | grep 'OK' | wc -l )
if [ $ok_count -ne 9 ]; then
    exit 1;
fi

#==============
# Download data
#==============

#run multiple downloads in parallel to save time
$SCRIPTS/oa-loader.sh &
$SCRIPTS/osm-loader.sh &
$SCRIPTS/nlsfi-loader.sh &
$SCRIPTS/gtfs-loader.sh &

#sync
wait

ok_count=$(cat /tmp/loadresults | grep 'OK' | wc -l )
if [ $ok_count -ne 4 ]; then
    exit 1;
fi

cd /root

#=================
# Index everything
#=================

#start elasticsearch, create index and run importers
gosu elasticsearch elasticsearch -d

sleep 10

#schema script runs only from current dir
cd $TOOLS/schema/
node scripts/create_index

#run two imports in parallel to save time
$SCRIPTS/index1.sh &
$SCRIPTS/index2.sh &

wait

ok_count=$(cat /tmp/indexresults | grep 'OK' | wc -l )
if [ $ok_count -ne 2 ]; then
    exit 1;
fi

#=======
#cleanup
#=======

rm -r $DATA
rm -r $TOOLS
dpkg -r nodejs
apt-get purge -y git unzip python python-pip python-dev build-essential gdal-bin rlwrap
apt-get clean
