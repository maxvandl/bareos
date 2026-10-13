#!/usr/bin/env bash
set -euo pipefail

bareos_fd_config="/etc/bareos/bareos-fd.d/director/bareos-dir.conf"
bareos_mon_config="/etc/bareos/bareos-fd.d/director/bareos-mon.conf"
bareos_myself_config="/etc/bareos/bareos-fd.d/client/myself.conf"

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

file_env BAREOS_FD_PASSWORD

if [ "${FORCE_ROOT:-false}" = true ]; then
	BAREOS_DAEMON_USER='root'
	BAREOS_DAEMON_GROUP='root'
fi

if [ "$(id -u)" = '0' ]; then
	if [ -n "${PUID:-}" ]; then usermod -u "${PUID}" "${BAREOS_DAEMON_USER}"; fi
	if [ -n "${PGID:-}" ]; then groupmod -g "${PGID}" "${BAREOS_DAEMON_GROUP}"; fi

	if [ ! -f /etc/bareos/bareos-config.control ]; then
		tar xzf /bareos-fd.tgz --backup=simple --suffix=.before-control

		# Force client/file daemon password
		sed -i 's#Password = .*#Password = '\""${BAREOS_FD_PASSWORD}"\"'#' "${bareos_fd_config}"
		# Monitor password is generated at image build time: rotate it
		sed -i 's#Password = .*#Password = '\""$(gen_password)"\"'#' "${bareos_mon_config}"
		# Default name is the build host name, use a stable one
		sed -i 's#^\( *\)Name = .*#\1Name = '"${BAREOS_FD_NAME:-bareos-fd}"'#' "${bareos_myself_config}"

		# Control file
		touch /etc/bareos/bareos-config.control
	fi

	# Fix permissions
	find /etc/bareos ! -user "${BAREOS_DAEMON_USER}" \
		-exec chown "${BAREOS_DAEMON_USER}:${BAREOS_DAEMON_GROUP}" {} +
	chown -R "${BAREOS_DAEMON_USER}:${BAREOS_DAEMON_GROUP}" /var/lib/bareos /var/log/bareos

	unset BAREOS_FD_PASSWORD BAREOS_FD_PASSWORD_FILE

	# Drop privileges (setpriv instead of gosu: Go binaries crash under amd64 emulation)
	if [ "${BAREOS_DAEMON_USER}" != 'root' ]; then
		exec setpriv --reuid="${BAREOS_DAEMON_USER}" --regid="${BAREOS_DAEMON_GROUP}" \
			--init-groups "${BASH_SOURCE[0]}" "$@"
	fi
fi

exec "$@"
