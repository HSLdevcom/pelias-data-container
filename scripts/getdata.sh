#!/bin/bash

# errors should break the execution
set -e

# main Docker script has already created these:
export TOOLS=/mnt/tools
export DATA=/mnt/data
SCRIPTS=$TOOLS/scripts


#=====================
# Launch Elasticsearch
#=====================
cd /root

gosu elasticsearch elasticsearch -d
sleep 20

#schema script runs only from current dir
cd $TOOLS/schema/
node scripts/create_index


#==============
# Download data
#==============

$SCRIPTS/oa-loader.sh
$SCRIPTS/osm-loader.sh
$SCRIPTS/nlsfi-loader.sh
$SCRIPTS/gtfs-loader.sh


#=================
# Index everything
#=================

node $TOOLS/pelias-nlsfi-places-importer/lib/index -d $DATA/nls-places
echo '###### nlsfi places done'

node $TOOLS/polylines/bin/cli.js --config --db
echo '###### polylines done'

node $TOOLS/openstreetmap/index
echo '###### openstreetmap done'

# param1: zip name containing gtfs data
# param2: import folder name
function import_gtfs {
    unzip -o $1

    # extract feed id
    index=$(sed -n $'1s/,/\\\n/gp' feed_info.txt | grep -nx 'feed_id' | cut -d: -f1)
    prefix=$(cat feed_info.txt | sed -n 2p | cut -d "," -f $index)
    prefix=${prefix^^}
    node $TOOLS/pelias-gtfs/import -d $DATA/$2 --prefix=$prefix
}

function import_router {
    cd $DATA/$1
    targets=(`ls *.zip`)
    for target in "${targets[@]}"
    do
        import_gtfs $target $1
    done
}

import_router router-finland
import_router router-waltti
echo '###### gtfs done'

#import openaddresses data
cd  $TOOLS/openaddresses

# first import swedish OA docs
bin/parallel 2 --language=sv
echo '###### openaddresses/sv done'

# then import and merge fi data with sv docs
bin/parallel 2 --language=fi --merge --merge-fields=name
echo '###### openaddresses/fi done'


#shutdown ES in a friendly way
pkill -SIGTERM -u elasticsearch
sleep 3
