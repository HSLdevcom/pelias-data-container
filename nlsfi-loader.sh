#!/bin/bash

# errors should break the execution
set -e

# Download nls paikat data
cd $DATA/nls-places
curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2016_01.zip
unzip paikat_2016_01.zip
rm paikat_2016_01.zip

echo 'OK' >> /tmp/loadresults
