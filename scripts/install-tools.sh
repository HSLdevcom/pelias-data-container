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
# some networks route apt's fetches to nodesource.com over an unreliable IPv6
# path, causing intermittent connection timeouts on larger .deb downloads;
# forcing IPv4 avoids that, and raising retries helps with other transient
# failures.
echo 'APT::Acquire::Retries "20";' >> /etc/apt/apt.conf
echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf
apt-get update
apt-get install -y --no-install-recommends git unzip python3 python3-pip python3-dev build-essential gdal-bin rlwrap procps emacs curl
rm -rf /var/lib/apt/lists/*

mkdir -p $SCRIPTS

# the nodesource setup script's repo config and apt-get install nodejs can
# each intermittently fail against nodesource's CDN (e.g. a truncated fetch
# that curl doesn't treat as an error without --fail/pipefail); retry the
# whole sequence a few times before giving up.
set -o pipefail
for i in 1 2 3 4 5; do
    curl -sL --fail https://deb.nodesource.com/setup_18.x | bash - \
        && apt-get install -y --no-install-recommends nodejs \
        && break
    if [ "$i" -eq 5 ]; then
        echo "Failed to install nodejs after $i attempts" >&2
        exit 1
    fi
    echo "nodejs setup/install failed (attempt $i), retrying..." >&2
    sleep 5
done
set +o pipefail

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
