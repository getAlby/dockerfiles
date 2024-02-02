# s3-lastmodified-checker
Lightweight s3 checker for lastmodified file in bucket + prefix
Will notify Sentry by HTTP Curl if configured appropriate SENTRY_CRONS is set

## Basic usage

```sh
$ docker run ghcr.io/getalby/s3-lastmodified-checker
```

## Environment variables


S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=
S3_ENDPOINT=
S3_PREFIX=
HOURS_AGO=

(Optional for notifying Sentry CRONs)

SENTRY_CRONS=
