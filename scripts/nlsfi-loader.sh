#!/bin/bash

# errors should break the execution
set -e

URL=$(node $SCRIPTS/parse_nlsfi_url.js)

mkdir -p $DATA/nls-places
cd $DATA/nls-places

# Download nls paikat data
set +e
echo 'Loading nlsfi data'
echo $URL
wget -O paikat.zip $URL
NAME=$(ls *.zip)
unzip -o $NAME
rm $NAME

echo '##### Loaded nlsfi data'
