# Dockerfile Bareos storage daemon

FROM ubuntu:24.04

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

RUN apt update -qq \
 && apt -qq -y install --no-install-recommends curl tzdata gnupg ca-certificates
RUN curl -Ls --insecure $BAREOS_KEY -o /tmp/bareos.key
RUN cat /tmp/bareos.key
RUN apt-key --keyring /etc/apt/trusted.gpg.d/breos-keyring.gpg add /tmp/bareos.key
RUN echo "deb $BAREOS_REPO /" > /etc/apt/sources.list.d/bareos.list
RUN apt update
RUN apt install -y --no-install-recommends \
    bareos-storage bareos-tools bareos-storage-tape mtx scsitools \
    sg3-utils mt-st bareos-storage-droplet 
RUN apt clean 
RUN rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

RUN tar czf /bareos-sd.tgz /etc/bareos/bareos-sd.d

EXPOSE 9103

VOLUME /etc/bareos
VOLUME /var/lib/bareos/storage

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-sd", "-u", "bareos", "-f"]
