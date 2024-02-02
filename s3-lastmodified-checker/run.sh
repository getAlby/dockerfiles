#!/bin/bash

set -eo pipefail
set -o pipefail


if [ "${S3_ACCESS_KEY_ID}" = "" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi


if [ "${S3_ENDPOINT}" == "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION


# AWS CLI command to list objects in the S3 bucket sorted by modification time
latest_file=$(aws $AWS_ARGS s3api list-objects-v2 --bucket $S3_BUCKET --prefix $S3_PREFIX --query 'sort_by(Contents, &LastModified)[-1].Key' --output text)

echo $latest_file

# Get the last modified timestamp of the latest file
last_modified=$(aws $AWS_ARGS s3api head-object --bucket $S3_BUCKET --key "$latest_file" --query 'LastModified' --output text)

#echo $last_modified

# Convert last modified timestamp to epoch time for easier comparison
last_modified_epoch=$(date -d "$last_modified" +%s)

# Calculate the threshold time (e.g., 1 day ago)
threshold_epoch=$(date -d "$HOURS_AGO hours ago" +%s)
#echo $threshold_epoch

# Compare last modified time with threshold time
if [ "$last_modified_epoch" -ge "$threshold_epoch" ]; then
    echo "Latest file is not older than $HOURS_AGO hours."
    if [ "${SENTRY_CRONS}" != "" ]; then
      echo "Calling SENTRY CRON with status=ok"
      curl "${SENTRY_CRONS}?status=ok"
    fi
else
    echo "Latest file is older than $HOURS_AGO hours."
    if [ "${SENTRY_CRONS}" != "" ]; then
      echo "Calling SENTRY CRON with status=error"
      curl "${SENTRY_CRONS}?status=error"
    fi
fi
