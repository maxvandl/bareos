#!/usr/bin/env bash
set -euo pipefail

if [ ! -f /etc/bareos-webui/bareos-config.control ]; then
	tar xzf /bareos-webui.tgz --backup=simple --suffix=.before-control

	# Update bareos-webui config
	sed -i 's#diraddress.*#diraddress = '\""${BAREOS_DIR_HOST}"\"'#' \
		/etc/bareos-webui/directors.ini

	# Control file
	touch /etc/bareos-webui/bareos-config.control
fi

# Run php-fpm and apache (Dockerfile CMD) side by side; if either exits the
# container exits so the restart policy brings both back
mkdir -p /run/php
php-fpm --nodaemonize &
"$@" &

mapfile -t pids < <(jobs -p)
trap 'kill -TERM "${pids[@]}" 2>/dev/null' TERM INT
set +e
wait -n
code=$?
kill -TERM "${pids[@]}" 2>/dev/null
wait
exit "${code}"
