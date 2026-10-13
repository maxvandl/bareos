#!/usr/bin/env bash
set -euo pipefail

bareos_sd_config="/etc/bareos/bareos-sd.d/director/bareos-dir.conf"
bareos_mon_config="/etc/bareos/bareos-sd.d/director/bareos-mon.conf"

# Random alphanumeric secret (safe for sed)
gen_password() {
	head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-40
}

# Resolve VAR from VAR_FILE (compose/docker secrets) when the file variant is set
file_env() {
	local var="$1" file_var="${1}_FILE"
	if [ -n "${!file_var:-}" ]; then
		if [ -n "${!var:-}" ]; then
			echo "Both ${var} and ${file_var} are set" >&2
			exit 1
		fi
		printf -v "${var}" '%s' "$(<"${!file_var}")"
		export "${var?}"
	fi
}

file_env BAREOS_SD_PASSWORD

if [ ! -f /etc/bareos/bareos-config.control ]; then
	tar xzf /bareos-sd.tgz --backup=simple --suffix=.before-control

	# Update bareos-storage configs
	sed -i 's#Password = .*#Password = '\""${BAREOS_SD_PASSWORD}"\"'#' "${bareos_sd_config}"
	# Monitor password is generated at image build time: rotate it
	sed -i 's#Password = .*#Password = '\""$(gen_password)"\"'#' "${bareos_mon_config}"

	# Control file
	touch /etc/bareos/bareos-config.control
fi

# Fix permissions
find /var/lib/bareos ! -user bareos -exec chown bareos {} +
find /etc/bareos/bareos-sd.d ! -user bareos -exec chown bareos {} +
find /dev -regex "/dev/[n]?st[0-9]+" ! -user bareos -exec chown bareos {} +
find /dev -regex "/dev/tape/.*" ! -user bareos -exec chown bareos {} +

unset BAREOS_SD_PASSWORD BAREOS_SD_PASSWORD_FILE

# Run Dockerfile CMD
exec "$@"
