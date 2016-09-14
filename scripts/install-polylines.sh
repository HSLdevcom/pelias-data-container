#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/pelias/polylines $TOOLS/polylines
cd $TOOLS/polylines
npm install
npm link pelias-dbclient
npm link pelias-wof-admin-lookup
echo 'OK' >> /tmp/npmlog
