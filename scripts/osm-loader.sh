#!/bin/bash

set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

echo 'Loading OSM data...'
curl -sS -O -L --fail https://geocoding.blob.core.windows.net/vrk/hsl_geocode_appendix.osm.pbf
curl -sS -O -L --fail https://download.geofabrik.de/europe/estonia-latest.osm.pbf

echo '##### Loaded OSM data'
