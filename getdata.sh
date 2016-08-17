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
curl -sS https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.13-1nodesource1~jessie1_amd64.deb > $TOOLS/node.deb
dpkg -i $TOOLS/node.deb

git clone https://github.com/whosonfirst/go-whosonfirst-clone.git $TOOLS/wof-clone
cd $TOOLS/wof-clone
make deps
make bin

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

install_node_project HSLdevcom pelias-nlsfi-places-importer


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
curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2016_01.zip
unzip paikat_2016_01.zip
rm paikat_2016_01.zip

cd /root

#=================
# Index everything
#=================

#start elasticsearch, create index and run importers
gosu elasticsearch elasticsearch -d
sleep 30

#schema script runs only from local folder
cd $TOOLS/schema/
node scripts/create_index
cd /root
node $TOOLS/pelias-nlsfi-places-importer/lib/index -d $DATA/nls-places
node $TOOLS/openaddresses/import --admin-values --language=sv
node $TOOLS/openaddresses/import --admin-values --language=fi --merge --merge-fields=name
node $TOOLS/openstreetmap/index

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
