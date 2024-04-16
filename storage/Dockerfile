# Dockerfile Bareos storage daemon
FROM ubuntu:22.04@sha256:1b8d8ff4777f36f19bfe73ee4df61e3a0b789caeff29caa019539ec7c9a57f95

LABEL maintainer="barcus@tou.nu"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/barcus/bareos" \
      org.label-schema.version=$VERSION

ENV BAREOS_KEY https://download.bareos.org/current/xUbuntu_22.04/Release.key
ENV BAREOS_REPO https://download.bareos.org/current/xUbuntu_22.04/
ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -qq \
 && apt-get -qq -y install --no-install-recommends curl tzdata gnupg ca-certificates
RUN curl -Ls --insecure $BAREOS_KEY -o /tmp/bareos.key
RUN cat /tmp/bareos.key
RUN apt-key --keyring /etc/apt/trusted.gpg.d/breos-keyring.gpg add /tmp/bareos.key
RUN echo "deb $BAREOS_REPO /" > /etc/apt/sources.list.d/bareos.list
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    bareos-storage bareos-tools bareos-storage-tape mtx scsitools \
    sg3-utils mt-st bareos-storage-droplet 
RUN apt-get clean 
RUN rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

RUN tar czf /bareos-sd.tgz /etc/bareos/bareos-sd.d

EXPOSE 9103

VOLUME /etc/bareos
VOLUME /var/lib/bareos/storage

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-sd", "-u", "bareos", "-f"]
