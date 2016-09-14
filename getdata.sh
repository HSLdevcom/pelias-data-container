#!/bin/bash

#=============
# Folder setup
#=============

export TOOLS=/mnt/tools
export DATA=/mnt/data

mkdir -p $TOOLS
mkdir -p $DATA

# Auxiliary folders
mkdir -p $DATA/openstreetmap
mkdir -p $DATA/openaddresses
mkdir -p $DATA/nls-places

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

$TOOLS/install-dbclient.sh &
$TOOLS/install-schema.sh &
$TOOLS/install-wof-pip-service.sh &

#must sync here, next installations will link with packages above
wait

$TOOLS/install-wof-admin-lookup &
$TOOLS/install-openstreetmap &
$TOOLS/install-openaddresses &
$TOOLS/install-polylines &
$TOOLS/install-pelias-nlsfi-places-importer &
$TOOLS/install-pelias-gtfs &

wait

ok_count=$(cat /tmp/npmlog | grep 'OK' | wc -l )
if [ $ok_count -ne 9 ]; then
    exit 1;
fi

#==============
# Download data
#==============

#run multiple downloads in parallel to save time
$TOOLS/oa-loader.sh &
$TOOLS/osm-loader.sh &
$TOOLS/nlsfi-loader.sh &
$TOOLS/gtfs-loader.sh &

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
$TOOLS/index1.sh &
$TOOLS/index2.sh &

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
