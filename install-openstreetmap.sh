#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/pelias/openstreetmap $TOOLS/openstreetmap
cd $TOOLS/openstreetmap
npm install
npm link pelias-dbclient
npm link pelias-wof-admin-lookup
echo 'OK' >> /tmp/npmlog
