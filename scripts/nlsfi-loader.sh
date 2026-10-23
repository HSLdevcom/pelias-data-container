#!/bin/bash
# Note: a valid MMLAPIKEY env var must be set when calling this script
# errors should break the execution
set -e

# Temporary fallback: a copy of the nlsfi data (places.xml + the xsd files the importer
# reads), used when the NLS file service is unavailable. NLS place data changes rarely.
FALLBACK_URL=https://geocoding.blob.core.windows.net/vrk/nls-places-fallback.zip

mkdir -p $DATA/nls-places
cd $DATA/nls-places

function load_from_nls {
    echo 'Extracting nlsfi data address...'
    local url
    url=$(timeout 120 node $SCRIPTS/parse_nlsfi_url.js) || return 1
    # the script prints errors to stdout and exits 0, so check that we really got a URL
    [[ "$url" == http* ]] || return 1

    echo 'Loading nlsfi data...'
    curl -k -sS -o $NAME -L --fail --connect-timeout 30 --max-time 1800 "$url" || return 1
    unzip -o $NAME || return 1
}

NAME=paikat.zip

if ! load_from_nls; then
    echo "WARNING: Loading nlsfi data from NLS failed, using fallback copy $FALLBACK_URL"
    rm -rf $DATA/nls-places/*
    curl -sS -o $NAME -L --fail --retry 3 $FALLBACK_URL
    unzip -o $NAME
fi

rm -f $NAME

echo '##### Loaded nlsfi data'
