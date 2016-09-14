#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/hsldevcom/pelias-gtfs $TOOLS/pelias-gtfs
cd $TOOLS/pelias-gtfs
npm install
npm link pelias-dbclient
npm link pelias-wof-admin-lookup
echo 'OK' >> /tmp/npmlog
