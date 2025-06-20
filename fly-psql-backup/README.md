# fly-psql-backup

This directory contains a simple yet powerful PostgreSQL backup script for use with Fly.io or any environment where you need to back up multiple databases and upload them to an S3-compatible storage (such as Google Cloud Storage, AWS S3, or MinIO).

## Features
- Dumps all PostgreSQL databases whose names start with the prefix `nwc`.
- Each database is backed up individually.
- Backups are compressed with gzip.
- Backups are encrypted with GPG using the database password as the passphrase (if set).
- Encrypted backups are uploaded to an S3-compatible bucket, organized by database name as a path prefix.
- Local backup files are stored in a configurable directory.

## How It Works
1. The script connects to the PostgreSQL server and lists all databases with names starting with `nwc`.
2. For each database:
   - Dumps the database using `pg_dump`.
   - Compresses the dump with `gzip`.
   - Optionally encrypts the compressed file with GPG (if `PGPASSWORD` is set).
   - Uploads the encrypted file to the specified S3 bucket under the path `<bucket>/<database>/<datetime>.sql.gz.gpg`.
   - Removes the unencrypted local file after encryption.

## Requirements
- Bash shell
- `psql` and `pg_dump` (PostgreSQL client tools)
- `gzip`
- `gpg`
- [`s5cmd`](https://github.com/peak/s5cmd) (for fast S3 uploads)

## Environment Variables
| Variable                | Description                                                      | Default         |
|-------------------------|------------------------------------------------------------------|-----------------|
| `PG_HOST`               | PostgreSQL host                                                  | `localhost`     |
| `PG_PORT`               | PostgreSQL port                                                  | `5432`          |
| `PG_USER`               | PostgreSQL user                                                  | `postgres`      |
| `PGPASSWORD` / `PG_PASSWORD` | PostgreSQL password (also used as GPG passphrase)           | (empty)         |
| `BACKUP_DIR`            | Local directory to store backups                                 | `./backups`     |
| `S3_ACCESS_KEY_ID`      | S3 access key                                                    | (required)      |
| `S3_SECRET_ACCESS_KEY`  | S3 secret key                                                    | (required)      |
| `S3_ENDPOINT_URL`       | S3 endpoint URL (e.g., for GCS, MinIO, etc.)                    | (required)      |
| `S3_BUCKET`             | S3 bucket name                                                   | (required)      |

## Usage
1. Install all required tools (`psql`, `pg_dump`, `gzip`, `gpg`, `s5cmd`).
2. Set the required environment variables (see above).
3. Run the script:

```bash
./fly-db-dump.sh
```

## Example
```bash
export PG_HOST=localhost
export PG_PORT=5432
export PG_USER=postgres
export PGPASSWORD=supersecret
export S3_ACCESS_KEY_ID=your-access-key
export S3_SECRET_ACCESS_KEY=your-secret-key
export S3_ENDPOINT_URL=https://storage.googleapis.com
export S3_BUCKET=my-backup-bucket

./fly-db-dump.sh
```

This will back up all databases with names starting with `nwc`, encrypt and upload them to the S3 bucket `my-backup-bucket` under paths like:

```
s3://my-backup-bucket/nwc_database1/20240611_123456.sql.gz.gpg
s3://my-backup-bucket/nwc_database2/20240611_123457.sql.gz.gpg
```

## Notes
- Only databases with names starting with `nwc` are backed up. Edit the script if you need a different filter.
- The script will skip encryption if `PGPASSWORD` is not set.
- Local backup files are stored in the directory specified by `BACKUP_DIR` and are removed after encryption.
- Make sure your S3 credentials and bucket permissions are correct.

## License
MIT 