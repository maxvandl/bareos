# Bareos director Dockerfile

ARG UBUNTU_VERSION=26.04
# Base images pinned by digest; UBUNTU_VERSION selects the variant:
# 26.04 = latest release (default), 24.04 = previous LTS
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55 AS base-24.04
FROM ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7 AS base-26.04
# hadolint ignore=DL3006
FROM base-${UBUNTU_VERSION}
ARG UBUNTU_VERSION

LABEL maintainer="MAYANGINDEX LLC" \
      org.opencontainers.image.description="Bareos Director with PostgreSQL catalog support" \
      org.opencontainers.image.source="https://github.com/maxvandl/bareos" \
      org.opencontainers.image.licenses="MIT"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION
ARG PG_CLIENT_VERSION=18
# Community repo by default; for the subscription repo pass
# --build-arg BAREOS_REPO=https://download.bareos.com/bareos/release/<ver>/xUbuntu_<UBUNTU_VERSION>/
# and --secret id=bareos_auth,src=auth.conf (apt auth.conf format)
ARG BAREOS_REPO=https://download.bareos.org/current/xUbuntu_${UBUNTU_VERSION}/
# Fingerprint of the repository signing key; empty disables the check (subscription repo uses another key)
ARG BAREOS_KEY_FPR=82834CF002D89BA55C1ED0AA42DA24A6DFEF9127

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/maxvandl/bareos" \
      org.label-schema.version=$VERSION
ENV TZ="UTC"
ENV DEBIAN_FRONTEND=noninteractive
ENV BAREOS_DPKG_CONF="bareos-database-common bareos-database-common"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN --mount=type=secret,id=bareos_auth,target=/etc/apt/auth.conf.d/bareos.conf,required=false \
    apt-get update -qq \
 && apt-get -qq -y install --no-install-recommends curl tzdata gnupg ca-certificates jq \
 && install -d -m 0755 /etc/apt/keyrings \
 && auth=() \
 && if [ -s /etc/apt/auth.conf.d/bareos.conf ]; then auth=(--netrc-file /etc/apt/auth.conf.d/bareos.conf); fi \
 && curl -fsSL "${auth[@]}" "${BAREOS_REPO}Release.key" -o /tmp/bareos.asc \
 && if [ -n "${BAREOS_KEY_FPR}" ]; then gpg --show-keys --with-colons /tmp/bareos.asc | grep -q "^fpr:*${BAREOS_KEY_FPR}:" || { echo "Bareos repository key fingerprint mismatch" >&2; exit 1; }; fi \
 && gpg --dearmor -o /etc/apt/keyrings/bareos.gpg < /tmp/bareos.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/bareos.gpg] ${BAREOS_REPO} /" \
    > /etc/apt/sources.list.d/bareos.list \
  # PostgreSQL client matching the catalog server major (pg_dump for BackupCatalog)
 && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /tmp/pgdg.asc \
 && gpg --show-keys --with-colons /tmp/pgdg.asc | grep -q "^fpr:*B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8:" || { echo "PGDG key fingerprint mismatch" >&2; exit 1; } \
 && gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg < /tmp/pgdg.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt $(. /etc/os-release && echo "${VERSION_CODENAME}")-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
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
 && apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends \
    bareos "postgresql-client-${PG_CLIENT_VERSION}" bareos-tools \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/*.asc \
 && dpkg-query -W -f='${Version}\n' bareos-director > /etc/bareos-version

RUN tar czf /bareos-dir.tgz /etc/bareos

COPY admin.conf /usr/local/share/bareos/admin.conf
COPY --chmod=0755 webhook-notify /usr/local/bin/webhook-notify
COPY --chmod=0755 docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 9101

VOLUME /etc/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
