#! /bin/sh

set -eo pipefail
set -o pipefail

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" -a "${POSTGRES_BACKUP_ALL}" != "true" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "${GPG_PASSWORD}" = "**None**" ]; then
  echo "You need to set the GPG_PASSWORD environment variable."
  exit 1
fi


if [ "${S3_ENDPOINT}" == "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

if [ -z ${S3_PREFIX+x} ]; then
  S3_PREFIX="/"
else
  S3_PREFIX="/${S3_PREFIX}/"  
fi

if [ "${SENTRY_CRON_ENDPOINT}" != "**None**" ]; then
  curl "${SENTRY_CRON_ENDPOINT}?status=in_progress"
fi

BACKUP_START_TIME=$(date +%s)
echo "Starting backup at $(date -Iseconds)"

if [ "${POSTGRES_BACKUP_ALL}" == "true" ]; then
  echo "Creating dump of all databases from ${POSTGRES_HOST}..."
  echo "Uploading dump to $S3_BUCKET"

  BACKUP_URI="s3://${S3_BUCKET}${S3_PREFIX}all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz.gpg"
  IN_PROGRESS_URI="${BACKUP_URI}.in-progress"
  if ! pg_dumpall -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" \
      | gzip \
      | gpg -c --batch --pinentry-mode loopback --passphrase "$GPG_PASSWORD" --output - \
      | aws $AWS_ARGS s3 cp - "$IN_PROGRESS_URI"; then
    echo "SQL backup failed; removing any partial upload"
    aws $AWS_ARGS s3 rm "$IN_PROGRESS_URI" || true
    exit 2
  fi

  if ! aws $AWS_ARGS s3 mv "$IN_PROGRESS_URI" "$BACKUP_URI"; then
    echo "SQL backup promotion failed; removing the in-progress upload"
    aws $AWS_ARGS s3 rm "$IN_PROGRESS_URI" || true
    exit 2
  fi

  echo "SQL backup uploaded successfully"
else
  OIFS="$IFS"
  IFS=','
  for DB in $POSTGRES_DATABASE
  do
    IFS="$OIFS"

    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    echo "Uploading dump to $S3_BUCKET"

    BACKUP_URI="s3://${S3_BUCKET}${S3_PREFIX}${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz.gpg"
    IN_PROGRESS_URI="${BACKUP_URI}.in-progress"
    if ! pg_dump $POSTGRES_HOST_OPTS "$DB" \
        | gzip \
        | gpg -c --batch --pinentry-mode loopback --passphrase "$GPG_PASSWORD" --output - \
        | aws $AWS_ARGS s3 cp - "$IN_PROGRESS_URI"; then
      echo "SQL backup failed; removing any partial upload"
      aws $AWS_ARGS s3 rm "$IN_PROGRESS_URI" || true
      exit 2
    fi

    if ! aws $AWS_ARGS s3 mv "$IN_PROGRESS_URI" "$BACKUP_URI"; then
      echo "SQL backup promotion failed; removing the in-progress upload"
      aws $AWS_ARGS s3 rm "$IN_PROGRESS_URI" || true
      exit 2
    fi

    echo "SQL backup uploaded successfully"
  done
fi

BACKUP_END_TIME=$(date +%s)
BACKUP_DURATION=$((BACKUP_END_TIME - BACKUP_START_TIME))
BACKUP_DURATION_FORMATTED=$(date -u -d @${BACKUP_DURATION} +"%H:%M:%S")
echo "Backup completed at $(date -Iseconds)"
echo "Total backup duration: ${BACKUP_DURATION_FORMATTED} (${BACKUP_DURATION} seconds)"

if [ "${SENTRY_CRON_ENDPOINT}" != "**None**" ]; then
  curl "${SENTRY_CRON_ENDPOINT}?status=ok"
fi
