# Use the official Ubuntu 22.04 base image
FROM barcus/bareos-webui:latest@sha256:990fb1626e49803fc1f96bafeb5dfe6441c67b7aa7751b9a30d1926b80a5242d

# Update the package list and install required dependencies
RUN rm -f /etc/apt/sources.list.d/bareos.list 
RUN apt update -y
RUN apt install wget gnupg ca-certificates
RUN wget https://download.bareos.org/current/xUbuntu_22.04/add_bareos_repositories.sh
RUN chmod +x add_bareos_repositories.sh
RUN ./add_bareos_repositories.sh
RUN  apt update -y
RUN apt install bareos-webui -y
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh
EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]



# # Bareos Web-ui Dockerfile
# FROM ubuntu:22.04

# LABEL maintainer="barcus@tou.nu"

# ARG BUILD_DATE
# ARG NAME
# ARG VCS_REF
# ARG VERSION

# LABEL org.label-schema.schema-version="1.0" \
#       org.label-schema.build-date=$BUILD_DATE \
#       org.label-schema.name=$NAME \
#       org.label-schema.vcs-ref=$VCS_REF \
#       org.label-schema.vcs-url="https://github.com/barcus/bareos" \
#       org.label-schema.version=$VERSION

# ENV BAREOS_KEY https://download.bareos.org/current/xUbuntu_22.04/Release.key
# ENV BAREOS_REPO https://download.bareos.org/current/xUbuntu_22.04/
# ENV DEBIAN_FRONTEND noninteractive
# ENV TZ=Asia/Jerusalem
# SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# RUN apt-get update -qq 
# RUN apt-get -qq -y install --no-install-recommends curl tzdata gnupg ca-certificates
# RUN curl -Ls --insecure $BAREOS_KEY -o /tmp/bareos.key 
# RUN apt-key --keyring /etc/apt/trusted.gpg.d/breos-keyring.gpg \
#     add /tmp/bareos.key 
# RUN echo "deb $BAREOS_REPO /" > /etc/apt/sources.list.d/bareos.list \
#  && apt-get update -qq \
#  && apt-get install -qq -y --no-install-recommends \
#     bareos-webui \
#  && apt-get clean \
#  && rm -rf /var/lib/apt/lists/*

# COPY docker-entrypoint.sh /docker-entrypoint.sh
# RUN chmod u+x /docker-entrypoint.sh

# RUN tar czf /bareos-webui.tgz /etc/bareos-webui

# EXPOSE 80

# VOLUME /etc/bareos-webui

# ENTRYPOINT ["/docker-entrypoint.sh"]
# CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]