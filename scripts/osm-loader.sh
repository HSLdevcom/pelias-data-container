#!/bin/bash

set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

echo 'Loading OSM data...'
curl -sS -O -L --fail  https://geocoding.blob.core.windows.net/vrk/hsl_geocode_appendix.osm.pbf

# allow failures so that curl can be retried many times
set +e
for i in $(seq 0 4)
do
    # Download osm data
    curl -sS -O -L --fail https://karttapalvelu.storage.hsldev.com/finland.osm/finland.osm.pbf
    if [ $? -eq 0 ]; then
        echo '##### Loaded OSM data'
        exit 0
    fi
    sleep 600
done

# exit with an error
exit 1
