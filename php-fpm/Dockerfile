FROM php:8.5.6-fpm-alpine@sha256:951d63d36ff6466e4cf6c524ff0d8f54f68f96ab1a4f85f8aa03e22df731ce94
ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="barcus/php-fpm-alpine" \
      org.label-schema.description="Docker image for PHP-fpm" \
      org.label-schema.vcs-url="https://github.com/barcus/docker-php-fpm-alpine" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.version="7.2-fpm-alpine" \
      org.label-schema.image.authors="barcus@tou.nu"

RUN apk update && apk add tzdata
ENV TZ=Asia/Jerusalem

RUN apk add --no-cache gettext && \
    apk add --no-cache --virtual .build-dependencies gettext-dev && \
    docker-php-ext-install gettext mysqli && \
    apk del .build-dependencies 

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/env", "php-fpm"]