#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/nls-places
cd $DATA/nls-places

# Download nls paikat data
curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2017_01.zip
unzip paikat_2016_01.zip
rm paikat_2016_01.zip

echo 'OK' >> /tmp/loadresults
