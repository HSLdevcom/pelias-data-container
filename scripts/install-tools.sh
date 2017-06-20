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
