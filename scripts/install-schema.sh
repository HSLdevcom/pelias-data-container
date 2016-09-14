#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/pelias/schema $TOOLS/schema
cd $TOOLS/schema
npm install
#make the package locally available
npm link
echo 'OK' >> /tmp/npmlog