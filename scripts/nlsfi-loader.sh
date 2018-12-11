#!/bin/bash
# Note: a valid MMLAPIKEY env var must be set when calling this script
# errors should break the execution
set -e

NAME=paikat.zip
URL=$(node $SCRIPTS/parse_nlsfi_url.js)

mkdir -p $DATA/nls-places
cd $DATA/nls-places

# Download nls paikat data
echo 'Loading nlsfi data'

wget -O $NAME $URL
unzip -o $NAME
rm $NAME

echo '##### Loaded nlsfi data'
