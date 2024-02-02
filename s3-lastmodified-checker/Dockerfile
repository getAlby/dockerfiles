FROM zulhfreelancer/aws-cli-v2-on-ubuntu

RUN curl --version

#RUN apt-get update && apt-get install -y curl

ADD run.sh /opt/s3-lastmodified-checker/run.sh

WORKDIR /s3-lastmodified-checker

ENTRYPOINT ["/opt/s3-lastmodified-checker/run.sh"]
