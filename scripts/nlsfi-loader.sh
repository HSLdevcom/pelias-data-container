#!/bin/bash
# Note: a valid MMLAPIKEY env var must be set when calling this script
# errors should break the execution
set -e

source "$(dirname "$0")/backup-utils.sh"

# Backup copy of the nlsfi data (places.xml + the xsd files the importer reads), used when the
# NLS file service is unavailable. It is refreshed after every successful download.
BACKUP_NAME=backup/nls-places-fallback.zip

mkdir -p $DATA/nls-places
cd $DATA/nls-places

function load_from_nls {
    echo 'Extracting nlsfi data address...'
    local url
    url=$(timeout 120 node $SCRIPTS/parse_nlsfi_url.js) || return 1
    # the script prints errors to stdout and exits 0, so check that we really got a URL
    [[ "$url" == http* ]] || return 1

    echo 'Loading nlsfi data...'
    curl -k -sS -o $NAME -L --fail --connect-timeout 30 --max-time 1800 "$url" || return 1
    valid_zip $NAME || return 1
    unzip -o $NAME || return 1
}

function valid_zip {
    [ -s "$1" ] && unzip -tq "$1" > /dev/null
}

NAME=paikat.zip

if load_from_nls; then
    upload_backup $BACKUP_NAME $NAME
else
    backup_warn "loading nlsfi data from NLS failed"
    rm -rf $DATA/nls-places/*
    restore_backup $BACKUP_NAME $NAME
    valid_zip $NAME
    unzip -o $NAME
fi

rm -f $NAME

echo '##### Loaded nlsfi data'
