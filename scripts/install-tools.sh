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
}

set -x
set -e
apt-get update
echo 'APT::Acquire::Retries "20";' >> /etc/apt/apt.conf
apt-get install -y --no-install-recommends git unzip python3 python3-pip python3-dev build-essential gdal-bin rlwrap procps emacs curl
rm -rf /var/lib/apt/lists/*

mkdir -p $SCRIPTS

curl -sL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y --no-install-recommends nodejs

cd $SCRIPTS

#install npm packaged deps
npm install

#install source repo deps
install_node_project hsldevcom pelias-schema
install_node_project HSLdevcom openstreetmap
install_node_project HSLdevcom pelias-vrk
install_node_project HSLdevcom pelias-nlsfi-places-importer
install_node_project HSLdevcom pelias-gtfs
install_node_project HSLdevcom bikes-pelias
install_node_project HSLdevcom parking-areas-pelias
