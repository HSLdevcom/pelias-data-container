#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/hsldevcom/pelias-nlsfi-places-importer $TOOLS/pelias-nlsfi-places-importer
cd $TOOLS/pelias-nlsfi-places-importer
npm install
npm link pelias-dbclient
echo 'OK' >> /tmp/npmlog
