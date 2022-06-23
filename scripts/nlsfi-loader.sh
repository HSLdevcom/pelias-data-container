#!/bin/bash
# Note: a valid MMLAPIKEY env var must be set when calling this script
# errors should break the execution
set -e

echo 'Extracting nlsfi data address...'
NAME=paikat.zip
#URL=$(node $SCRIPTS/parse_nlsfi_url.js)
URL="https://tiedostopalvelu.maanmittauslaitos.fi/tp/tilauslataus/tuotteet/nimisto/paikat/etrs89/gml/paikat_2022_01.zip?api_key=$MMLAPIKEY"

mkdir -p $DATA/nls-places
cd $DATA/nls-places

# Download nls paikat data
echo 'Loading nlsfi data...'

curl -sS -o $NAME -L --fail $URL
unzip -o $NAME
rm $NAME

echo '##### Loaded nlsfi data'
