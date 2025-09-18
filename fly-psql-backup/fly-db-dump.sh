#!/bin/bash

set -e

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_PASSWORD="${PGPASSWORD:-}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
DATE_SUFFIX=$(date +"%Y%m%d_%H%M%S")

if [ -n "$PG_PASSWORD" ]; then
    export PGPASSWORD="$PG_PASSWORD"
fi

mkdir -p "$BACKUP_DIR"

echo "Testing PostgreSQL connection..."
if ! psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo "ERROR: Failed to connect to PostgreSQL at $PG_HOST:$PG_PORT with user $PG_USER" >&2
    exit 1
fi
echo "PostgreSQL connection successful"

dbs=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d postgres -t -c \
    "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'template0', 'template1') AND datname LIKE 'nwc%' ORDER BY datname;" | sed 's/^ *//' | sed '/^$/d')

if [ -z "$dbs" ]; then
    echo "ERROR: No databases found matching the criteria (datname LIKE 'nwc%')" >&2
    exit 1
fi

echo "Found databases to backup: $(echo "$dbs" | tr '\n' ' ')"

for db in $dbs; do
    outfile="${BACKUP_DIR}/${DATE_SUFFIX}.sql.gz"
    echo "Backing up $db to $outfile"
    pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$db" | gzip > "$outfile"
    echo "Done $db"

    # Encrypt the backup with GPG using PGPASSWORD as passphrase
    gpg_outfile="$outfile.gpg"
    if [ -n "$PGPASSWORD" ]; then
        echo "$PGPASSWORD" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$gpg_outfile" "$outfile"
        rm -f "$outfile"
        echo "Encrypted $outfile to $gpg_outfile"
    else
        echo "PGPASSWORD not set; skipping encryption for $outfile"
        gpg_outfile="$outfile"
    fi

    # Upload to S3-compatible bucket (Google Cloud Storage)
    if [ -n "$S3_ACCESS_KEY_ID" ] && [ -n "$S3_SECRET_ACCESS_KEY" ] && [ -n "$S3_ENDPOINT_URL" ] && [ -n "$S3_BUCKET" ]; then
        s3_path="s3://$S3_BUCKET/$db/${DATE_SUFFIX}.sql.gz.gpg"
        AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID" \
        AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY" \
        /usr/local/bin/s5cmd --endpoint-url "$S3_ENDPOINT_URL" cp "$gpg_outfile" "$s3_path"
        echo "Uploaded $gpg_outfile to $s3_path"
    else
        echo "S3 credentials or bucket info not set; skipping upload for $gpg_outfile"
    fi

done

echo "All backups complete. Files are in $BACKUP_DIR"
