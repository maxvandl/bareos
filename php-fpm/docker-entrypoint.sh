#!/usr/bin/env ash

# Set environments
sed -i "s|;*daemonize\s*=\s*yes|daemonize = no|g" /usr/local/etc/php-fpm.conf
sed -i "s|;*listen\s*=\s*127.0.0.1:9000|listen = 9000|g" /usr/local/etc/php-fpm.d/www.conf
sed -i "s|;*listen\s*=\s*/||g" /usr/local/etc/php-fpm.d/www.conf
echo "date.timezone = ${TIMEZONE}" > /usr/local/etc/php.ini
sed -i 's/pm.max_children = 5/pm.max_children = 5/g' /usr/local/etc/php-fpm.d/www.conf
sed -i 's/pm.start_servers = 2/pm.start_servers = 2/g' /usr/local/etc/php-fpm.d/www.conf
sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 3/g' /usr/local/etc/php-fpm.d/www.conf
exec "$@"