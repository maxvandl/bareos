# Bareos REST API Dockerfile
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
ARG BAREOS_RESTAPI_VERSION=25.1.1

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/maxvandl/bareos" \
      org.label-schema.version=$VERSION
ENV TZ="UTC"
ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update -qq \
 && apt-get -qq -y install --no-install-recommends python3 python3-venv ca-certificates tzdata \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/*.asc \
 && useradd --system --uid 10001 --create-home --home-dir /home/bareos bareos

USER 10001
WORKDIR /home/bareos

ENV VIRTUAL_ENV=/home/bareos/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
RUN python3 -m venv "${VIRTUAL_ENV}" \
 && pip install --no-cache-dir "bareos-restapi==${BAREOS_RESTAPI_VERSION}"

COPY --chmod=0755 docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn", "--log-level", "info", "--host", "0.0.0.0", "bareos_restapi:app"]
