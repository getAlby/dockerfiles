FROM alpine:latest

RUN apk add --no-cache postgresql-client=17.0-r0 gzip bash curl gnupg || (echo 'Falling back to default postgresql-client version' && apk add --no-cache postgresql-client gzip bash curl gnupg)

RUN curl -L https://fly.io/install.sh | sh && \
    mv /root/.fly/bin/flyctl /usr/local/bin/flyctl

COPY fly-db-dump.sh /fly-db-dump.sh
RUN chmod +x /fly-db-dump.sh

ENV PG_HOST=localhost
ENV PG_PORT=5432
ENV PG_USER=postgres
ENV BACKUP_DIR=/backups

RUN mkdir -p /backups

RUN wget -O /tmp/s5cmd.tar.gz https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-64bit.tar.gz \
    && tar -xzf /tmp/s5cmd.tar.gz -C /usr/local/bin s5cmd \
    && chmod +x /usr/local/bin/s5cmd \
    && rm /tmp/s5cmd.tar.gz

ENV S3_ENDPOINT_URL=https://storage.googleapis.com
ENV S3_BUCKET=nwcs-fly-psql-db

ENTRYPOINT ["/bin/sh", "-c", "flyctl proxy 5432:5432 -a hub-db-fra & sleep 10 && /fly-db-dump.sh"]
