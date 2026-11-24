#!/bin/bash

set -e

source "$(dirname "$0")/backup-utils.sh"

# The URL can be overridden, e.g. to test the backup copy with an unavailable source
ESTONIA_OSM_URL=${ESTONIA_OSM_URL:-https://download.geofabrik.de/europe/estonia/estonia-latest-OUTAGE-TEST.osm.pbf}

# The Estonia extract is about 125 MB and does not shrink; a smaller file is a failed or partial download.
MIN_ESTONIA_BYTES=100000000

function valid_estonia_pbf {
    [ "$(file_size "$1")" -ge $MIN_ESTONIA_BYTES ] && head -c 100 "$1" | grep -aq OSMHeader
}

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

echo 'Loading OSM data...'
sas=$(backup_sas BLOB_SAS)
curl -sS -O -L --fail "$BACKUP_BLOB_URL/hsl_geocode_appendix.osm.pbf${sas:+?$sas}"
fetch_with_backup backup/estonia-latest.osm.pbf estonia-latest.osm.pbf valid_estonia_pbf \
    curl -sS -L --fail --retry 3 -o estonia-latest.osm.pbf $ESTONIA_OSM_URL

echo '##### Loaded OSM data'
