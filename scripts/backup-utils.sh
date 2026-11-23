#!/bin/bash

# Helpers for keeping a backup copy of external source data in Azure Blob Storage.
# A successful download refreshes the backup, and the backup is used when the source is unavailable.
# Source this file; it does not change shell options.
#
# Optional settings (without BLOB_WRITE_SAS backups are not updated, without BLOB_READ_SAS the
# backup is read anonymously):
#   BACKUP_BLOB_URL - container URL, defaults to the geocoding storage account
#   BLOB_READ_SAS   - SAS token with read permission
#   BLOB_WRITE_SAS  - SAS token with create and write permissions
# The tokens are read from the environment or, preferably, from BuildKit secrets
# (/run/secrets/<name>), which keeps them out of the image history.

BACKUP_BLOB_URL=${BACKUP_BLOB_URL:-https://geocoding.blob.core.windows.net/vrk}

# param1: token variable name
function backup_sas {
    local value
    value=$(printenv "$1" || true)
    if [ -z "$value" ] && [ -r "/run/secrets/$1" ]; then
        value=$(cat "/run/secrets/$1")
    fi
    # accept the token with or without the leading question mark
    echo "${value#\?}"
}

function file_size {
    wc -c < "$1" | tr -d ' '
}

# param1: blob name
# param2: file to upload
# A failed upload only logs a warning, because the data itself has already been loaded.
function upload_backup {
    local sas
    sas=$(backup_sas BLOB_WRITE_SAS)
    if [ -z "$sas" ]; then
        echo "Backup of $1 not updated: BLOB_WRITE_SAS is not set"
        return 0
    fi
    # a single Put Blob request replaces the blob atomically
    if curl -sS --fail --retry 3 --connect-timeout 30 -X PUT -T "$2" \
        -H "x-ms-blob-type: BlockBlob" -H "x-ms-version: 2021-08-06" \
        -o /dev/null "$BACKUP_BLOB_URL/$1?$sas"; then
        echo "Updated backup copy $1 ($(file_size "$2") bytes)"
    else
        echo "WARNING: updating backup copy $1 failed"
    fi
    return 0
}

# param1: blob name
# param2: destination file
function restore_backup {
    local sas
    sas=$(backup_sas BLOB_READ_SAS)
    echo "WARNING: using backup copy $BACKUP_BLOB_URL/$1"
    curl -sS --fail --retry 3 --connect-timeout 30 -L -o "$2" "$BACKUP_BLOB_URL/$1${sas:+?$sas}"
}

# Download with `download command...`; if that fails or the result is not valid, restore the
# backup copy instead. A valid download refreshes the backup.
# param1: blob name of the backup
# param2: downloaded file
# param3: name of a validation function, which gets the file as its argument
# rest: download command, which must create param2
function fetch_with_backup {
    local name=$1 file=$2 validate=$3
    shift 3
    rm -f "$file"
    if "$@" && "$validate" "$file"; then
        upload_backup "$name" "$file"
        return 0
    fi
    echo "WARNING: downloading $file from the source failed"
    rm -f "$file"
    restore_backup "$name" "$file" || return 1
    if ! "$validate" "$file"; then
        echo "ERROR: backup copy of $file is not valid"
        return 1
    fi
}
