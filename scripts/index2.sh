#!/bin/bash

# errors should break the execution
set -e

# param: zip name containing gtfs data
function import_gtfs {
    unzip -o $1
    prefix=$(echo $1 | sed 's/.zip//g')
    prefix=${prefix^^}
    node $TOOLS/pelias-gtfs/import -d $DATA/router-finland --prefix=$prefix
}

cd $DATA/router-finland
targets=(`ls *.zip`)
for target in "${targets[@]}"
do
    import_gtfs $target
done

cd  $TOOLS/openaddresses

# first import swedish docs
bin/parallel 2 --language=sv

# then import and merge fi data with sv docs
bin/parallel 2 --language=fi --merge --merge-fields=name

echo 'OK' >> /tmp/indexresults
