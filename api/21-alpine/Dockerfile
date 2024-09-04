
FROM python:3.12-alpine@sha256:aeff64320ffb81056a2afae9d627875c5ba7d303fb40d6c0a43ee49d8f82641c


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

RUN pip install --no-cache-dir --upgrade pip==22.0.4

RUN adduser -D bareos
USER bareos
WORKDIR /home/bareos

ENV PATH="/home/bareos/.local/bin:${PATH}"
RUN pip install --no-cache-dir "bareos-restapi>=21*,<22*"

COPY --chown=bareos docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn","--log-level", "debug", "--host", "0.0.0.0", "bareos_restapi:app", "--reload"]
