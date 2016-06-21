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

set -x
set -e
apt-get update
apt-get install -y --no-install-recommends git unzip python python-pip python-dev build-essential gdal-bin rlwrap golang-go
rm -rf /var/lib/apt/lists/*

mkdir -p $TOOLS
curl -sS https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.13-1nodesource1~jessie1_amd64.deb > $TOOLS/node.deb
dpkg -i $TOOLS/node.deb

git clone https://github.com/whosonfirst/go-whosonfirst-clone.git $TOOLS/wof-clone
cd $TOOLS/wof-clone
make deps
make bin

git clone https://github.com/HSLdevcom/pelias-nlsfi-places-importer.git $TOOLS/nls-fi-places
cd $TOOLS/nls-fi-places
npm install

# we need a custom pelias dbclient version
git clone https://github.com/HSLdevcom/dbclient.git $TOOLS/dbclient
cd $TOOLS/dbclient
npm install
# make it available for other pelias components
npm link

git clone https://github.com/HSLdevcom/openaddresses.git $TOOLS/openaddresses
cd $TOOLS/openaddresses
npm install
# use custom dbclient
npm link pelias-dbclient

#==============
# Download data
#==============

# Download Whosonfirst admin lookup data
cd $DATA/whosonfirst

URL=https://whosonfirst.mapzen.com/bundles
METADIR=wof_data/meta/
DATADIR=wof_data/data/
mkdir -p $METADIR
mkdir -p $DATADIR

cd $METADIR

admins=( continent borough country county dependency disputed localadmin locality macrocounty macroregion neighbourhood region )

for target in "${admins[@]}"
do
    echo getting $target metadata
    curl -O -sS $URL/wof-$target-latest.csv
    if [ "$target" != "continent" ]
    then
	head -1 wof-$target-latest.csv > temp && cat wof-$target-latest.csv | grep ",FI," >> temp || true
	mv temp wof-$target-latest.csv
    fi
done

cd ../../

for target in "${admins[@]}"
do
    echo getting $target data
    $TOOLS/wof-clone/bin/wof-clone-metafiles -dest $DATADIR $METADIR/wof-$target-latest.csv
done

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
curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2015_05.zip
unzip paikat_2015_05.zip
rm paikat_2015_05.zip

cd /root

#=================
# Index everything
#=================

#start elasticsearch, create index and run importers
gosu elasticsearch elasticsearch -d
npm install -g pelias-cli
sleep 30
pelias schema#12541694e43758f10b106f8d06b636358dcb2206 create_index
node $TOOLS/nls-fi-places/lib/index -d $DATA/nls-places
pelias openstreetmap#831f8c8d36110d3110a4fcce4023e28ec3b87dac import
node $TOOLS/openaddresses/import --admin-values --language=sv
node $TOOLS/openaddresses/import --admin-values --language=fi --merge --merge-fields=name

#=======
#cleanup
#=======

rm -r $DATA
rm -r $TOOLS
rm -r $HOME/.pelias
npm uninstall -g pelias-cli
dpkg -r nodejs
apt-get purge -y git unzip python python-pip python-dev build-essential gdal-bin rlwrap golang-go
apt-get clean
