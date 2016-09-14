#!/bin/bash

# this import script indexes openaddresses data

# errors should break the execution
set -e

# first import swedish docs
node $TOOLS/openaddresses/import --language=sv

# then import and merge fi data with sv docs
node $TOOLS/openaddresses/import --language=fi --merge --merge-fields=name

echo 'OK' >> /tmp/indexresults
