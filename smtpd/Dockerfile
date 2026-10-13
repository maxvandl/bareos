# Postfix SMTP relay for Bareos job reports
ARG UBUNTU_VERSION=26.04
# Base images pinned by digest; UBUNTU_VERSION selects the variant:
# 26.04 = latest release (default), 24.04 = previous LTS
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55 AS base-24.04
FROM ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7 AS base-26.04
# hadolint ignore=DL3006
FROM base-${UBUNTU_VERSION}
ARG UBUNTU_VERSION

LABEL maintainer="MAYANGINDEX LLC"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/maxvandl/bareos" \
      org.label-schema.version=$VERSION
ENV TZ="UTC"
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections \
 && apt-get update -qq \
 && apt-get -qq -y install --no-install-recommends postfix libsasl2-modules ca-certificates tzdata \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 8025

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["postfix", "start-fg"]
