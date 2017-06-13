#!/bin/bash

# errors should break the execution
set -e

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

echo 'OK' >> /tmp/indexresults
