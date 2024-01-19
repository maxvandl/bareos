# Use the official Ubuntu 22.04 base image
FROM barcus/bareos-webui:latest

# Update the package list and install required dependencies
RUN rm -f /etc/apt/sources.list.d/bareos.list 
RUN apt update -y
RUN apt install wget gnupg ca-certificates
RUN wget https://download.bareos.org/current/xUbuntu_22.04/add_bareos_repositories.sh
RUN chmod +x add_bareos_repositories.sh
RUN ./add_bareos_repositories.sh
RUN  apt update -y
RUN apt install bareos-webui=23.0.1~pre57.8e89bfe0a-40 -y
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh
EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]



