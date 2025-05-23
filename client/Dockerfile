# Dockerfile Bareos client/file daemon
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
ENV TZ="UTC"
ENV BAREOS_DAEMON_USER bareos
ENV BAREOS_DAEMON_GROUP bareos
ENV DEBIAN_FRONTEND noninteractive
ENV BAREOS_KEY https://download.bareos.org/current/xUbuntu_22.04/Release.key
ENV BAREOS_REPO https://download.bareos.org/current/xUbuntu_22.04/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt update -qq \
 && apt -qq -y install --no-install-recommends curl tzdata gnupg gosu ca-certificates \
 && curl -Ls $BAREOS_KEY -o /tmp/bareos.key \
 && apt-key --keyring /etc/apt/trusted.gpg.d/breos-keyring.gpg \
    add /tmp/bareos.key \
 && echo "deb $BAREOS_REPO /" > /etc/apt/sources.list.d/bareos.list \
 && apt update -qq \
 && apt install -qq -y --no-install-recommends \
    bareos-client mysql-client postgresql-client bareos-tools \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh

RUN tar czf /bareos-fd.tgz /etc/bareos/bareos-fd.d

EXPOSE 9102

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-fd", "-f"]
