#!/bin/bash

set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

echo 'Loading OSM data...'

# allow failures so that curl can be retried many times
set +e
for i in $(seq 0 10)
do
    # Download osm data
    curl -sS -O -L --fail https://karttapalvelu.storage.hsldev.com/finland.osm/finland.osm.pbf
    if [ $? -eq 0 ]; then
        echo '##### Loaded OSM data'
        exit 0
    fi
    sleep 120
done

# exit with an error
exit 1
