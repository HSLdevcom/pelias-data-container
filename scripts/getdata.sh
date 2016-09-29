''#!/bin/bash

# main Docker script has already created these:
export TOOLS=/mnt/tools
export DATA=/mnt/data
SCRIPTS=$TOOLS/scripts

#=========================================
# Install importers and their dependencies
#=========================================

# note: we cannot run parallel npm installs!

# param1: organization name
# param2: git project name
# note: changes cd to new project dir
function install_node_project {
    git clone --depth 1 --single-branch https://github.com/$1/$2 $TOOLS/$2
    cd $TOOLS/$2
    npm install

    #make the package locally available
    npm link
}

set -x
set -e
apt-get update
echo 'APT::Acquire::Retries "20";' >> /etc/apt/apt.conf
apt-get install -y --no-install-recommends git unzip python python-pip python-dev build-essential gdal-bin rlwrap
rm -rf /var/lib/apt/lists/*

mkdir -p $TOOLS
curl -sS https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.15-1nodesource1~jessie1_amd64.deb > $TOOLS/node.deb
dpkg -i $TOOLS/node.deb

install_node_project HSLdevcom dbclient

install_node_project pelias schema

install_node_project HSLdevcom wof-pip-service

install_node_project HSLdevcom wof-admin-lookup
npm link pelias-wof-pip-service

install_node_project HSLdevcom openstreetmap
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

install_node_project HSLdevcom openaddresses
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

install_node_project pelias polylines
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

install_node_project HSLdevcom pelias-nlsfi-places-importer
npm link pelias-dbclient

install_node_project HSLdevcom pelias-gtfs
npm link pelias-dbclient
npm link pelias-wof-admin-lookup


#==============
# Download data
#==============

#run multiple downloads in parallel to save time
$SCRIPTS/oa-loader.sh &
$SCRIPTS/osm-loader.sh &
$SCRIPTS/nlsfi-loader.sh &
$SCRIPTS/gtfs-loader.sh &

#launch also Elasticsearch at this point
$SCRIPTS/start-ES.sh &

#sync
wait

ok_count=$(cat /tmp/loadresults | grep 'OK' | wc -l )
if [ $ok_count -ne 5 ]; then
    exit 1;
fi

#=================
# Index everything
#=================

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
