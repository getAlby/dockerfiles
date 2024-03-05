FROM alpine:latest

# Update package repository and install bash and jq
RUN apk update && apk add --no-cache \
    bash \
    jq

RUN apk add --no-cache curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

ADD run.sh /scripts/
RUN chmod 755 /scripts/run.sh

ENTRYPOINT ["/scripts/run.sh"]
