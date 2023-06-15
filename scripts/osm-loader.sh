#!/bin/bash

set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

echo 'Loading OSM data...'
curl -sS -O -L --fail https://geocoding.blob.core.windows.net/vrk/hsl_geocode_appendix.osm.pbf
curl -sS -O -L --fail https://download.geofabrik.de/europe/estonia-latest.osm.pbf

# Do not load OSM from unreliable karttapalvelu data service
exit 0

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
