#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/vrk
cd $DATA/vrk

echo 'Loading DVV data...'
curl -sS -O -L --fail  https://geocoding.blob.core.windows.net/vrk/fi_vrk_addresses.zip

unzip -o fi_vrk_addresses.zip

mv *.OPT vrk.txt

#convert to utf-8 - no longer needed because csv-parser now accepts encoding parameter
#ls *.OPT | xargs -n 1 iconv -f ISO-8859-1 -t UTF-8 -o vrk.txt

rm *.zip

echo '##### Loaded DVV data'
