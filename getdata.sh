#!/bin/bash

#=============
# Folder setup
#=============

TOOLS=/mnt/tools
DATA=/mnt/data

mkdir -p $TOOLS
mkdir -p $DATA

# Auxiliary folders
mkdir -p $DATA/openstreetmap
mkdir -p $DATA/openaddresses
mkdir -p $DATA/nls-places
mkdir -p $DATA/whosonfirst

#=========================================
# Install importers and their dependencies
#=========================================

# param1: organization name
# param2: git project name
# note: changes cd to new project dir
function install_node_project {
    git clone --single-branch https://github.com/$1/$2 $TOOLS/$2
    cd $TOOLS/$2
    npm install

    #make the package locally available
    npm link
}

set -x
set -e
apt-get update
apt-get install -y --no-install-recommends git unzip python python-pip python-dev build-essential gdal-bin rlwrap golang-go
rm -rf /var/lib/apt/lists/*

mkdir -p $TOOLS
curl -sS https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.15-1nodesource1~jessie1_amd64.deb > $TOOLS/node.deb
dpkg -i $TOOLS/node.deb

# deduper does not seem to work well with our data
#git clone https://github.com/openvenues/address_deduper.git $TOOLS/address_deduper
#cd $TOOLS/address_deduper
#pip install -r requirements.txt

install_node_project HSLdevcom dbclient

install_node_project pelias schema

install_node_project HSLdevcom wof-pip-service

install_node_project HSLdevcom wof-admin-lookup
npm link pelias-wof-pip-service

install_node_project pelias openstreetmap
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

# Download OpenStreetMap data
cd $DATA/openstreetmap
curl -sS -O http://download.geofabrik.de/europe/finland-latest.osm.pbf

# Download all '/fi/' entries from OpenAddresses
cd $DATA/openaddresses
curl -sS http://results.openaddresses.io/state.txt | sed -e 's/\s\+/\n/g' | grep '/fi/.*\.zip' | xargs -n 1 curl -O -sS
ls *.zip | xargs -n 1 unzip -o
rm *.zip README.*

# Download nls paikat data
cd $DATA/nls-places
curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2016_01.zip
unzip paikat_2016_01.zip
rm paikat_2016_01.zip

# Download gtfs stop data
cd $DATA
curl -sS -O http://dev-api.digitransit.fi/routing-data/v1/router-hsl.zip
unzip router-hsl.zip
cd router-hsl
unzip -o hsl.zip

cd /root

#=================
# Index everything
#=================

#start elasticsearch, create index and run importers
gosu elasticsearch elasticsearch -d

#we currently do not use deduping
#python $TOOLS/address_deduper/app.py serve &

sleep 30

#schema script runs only from local folder
cd $TOOLS/schema/
node scripts/create_index
cd /root
node $TOOLS/pelias-nlsfi-places-importer/lib/index -d $DATA/nls-places
node $TOOLS/polylines/bin/cli.js --config --db
node $TOOLS/pelias-gtfs/import -d $DATA/router-hsl
node $TOOLS/openaddresses/import --language=sv
node $TOOLS/openaddresses/import --language=fi --merge --merge-fields=name
node $TOOLS/openstreetmap/index

#=======
#cleanup
#=======

rm -r $DATA
rm -r $TOOLS
dpkg -r nodejs
apt-get purge -y git unzip python python-pip python-dev build-essential gdal-bin rlwrap golang-go
apt-get clean
