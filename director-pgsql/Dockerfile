# Bareos director Dockerfile

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
ENV DEBIAN_FRONTEND noninteractive
ENV BAREOS_KEY https://download.bareos.org/current/xUbuntu_22.04/Release.key
ENV BAREOS_REPO https://download.bareos.org/current/xUbuntu_22.04/
ENV BAREOS_DPKG_CONF bareos-database-common bareos-database-common




SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt update -qq \
 && apt -qq -y install --no-install-recommends curl tzdata gnupg ca-certificates \
 && curl -Ls $BAREOS_KEY -o /tmp/bareos.key \
 && apt-key --keyring /etc/apt/trusted.gpg.d/breos-keyring.gpg \
    add /tmp/bareos.key \
 && echo "deb $BAREOS_REPO /" > /etc/apt/sources.list.d/bareos.list \
 && echo "${BAREOS_DPKG_CONF}/dbconfig-install boolean false" \
    | debconf-set-selections \
 && echo "${BAREOS_DPKG_CONF}/install-error select ignore" \
    | debconf-set-selections \
 && echo "${BAREOS_DPKG_CONF}/database-type select pgsql" \
    | debconf-set-selections \
 && echo "${BAREOS_DPKG_CONF}/missing-db-package-error select ignore" \
    | debconf-set-selections \
 && echo 'postfix postfix/main_mailer_type select No configuration' \
    | debconf-set-selections \
 && apt update -qq \
 && apt install -qq -y --no-install-recommends \
    bareos postgresql-client bareos-tools \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

RUN tar czf /bareos-dir.tgz /etc/bareos

COPY webhook-notify /usr/local/bin/webhook-notify
RUN chmod u+x /usr/local/bin/webhook-notify

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9101

VOLUME /etc/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
