#!/bin/bash

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
# param3: optional git commit id
# note: changes cd to new project dir
function install_node_project {
    git clone --single-branch https://github.com/$1/$2 $TOOLS/$2
    cd $TOOLS/$2
    if [ -n "$3" ]; then
        git checkout $3
    fi
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

curl -sL https://deb.nodesource.com/setup_4.x | bash -
apt-get install -y --no-install-recommends nodejs

install_node_project HSLdevcom dbclient

install_node_project pelias schema 6565d7d0b8b686e2e408693c3f4bc4889c3d56af

install_node_project HSLdevcom wof-admin-lookup

install_node_project HSLdevcom openstreetmap
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

install_node_project HSLdevcom openaddresses
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

install_node_project pelias polylines 11a4b8c6dba2bc4e5150698ac7f177de107a3272
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

install_node_project HSLdevcom pelias-nlsfi-places-importer
npm link pelias-dbclient
npm link pelias-wof-admin-lookup

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
    echo 'Data loading failed'
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
    echo 'Indexing failed'
    exit 1;
fi

#=======
#cleanup
#=======

#shutdown ES in a friendly way
pkill -SIGTERM -u elasticsearch
sleep 3

rm -r $DATA
rm -r $TOOLS
dpkg -r nodejs
apt-get purge -y git unzip python python-pip python-dev build-essential gdal-bin rlwrap
apt-get clean
