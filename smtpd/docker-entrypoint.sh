#!/usr/bin/env bash
set -euo pipefail

# Relay-only Postfix: accepts mail from RELAY_NETWORKS on port 8025 and
# delivers it directly or through SMARTHOST (host:port, exim style host::port also accepted)
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

file_env SMTP_PASSWORD

relay_hostname="${RELAY_HOSTNAME:-bareos.local}"
relay_networks="${RELAY_NETWORKS:-127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"
smarthost="${SMARTHOST:-}"
smtp_username="${SMTP_USERNAME:-}"
smtp_password="${SMTP_PASSWORD:-}"

touch /etc/postfix/main.cf
# $myhostname is a Postfix variable, not a shell one
# shellcheck disable=SC2016
postconf -e \
	"compatibility_level=3.6" \
	"myhostname=${relay_hostname}" \
	'myorigin=$myhostname' \
	"mydestination=" \
	"local_recipient_maps=" \
	"alias_maps=" \
	"alias_database=" \
	"inet_interfaces=all" \
	"inet_protocols=ipv4" \
	"mynetworks=${relay_networks}" \
	"smtpd_relay_restrictions=permit_mynetworks,reject" \
	"smtpd_recipient_restrictions=permit_mynetworks,reject" \
	'smtpd_banner=$myhostname ESMTP' \
	"disable_vrfy_command=yes" \
	"smtp_tls_security_level=may" \
	"smtp_tls_CAfile=/etc/ssl/certs/ca-certificates.crt" \
	"maillog_file=/dev/stdout"

# Listen on 8025 only; no chroot anywhere so DNS changes from Docker are picked up
postconf -M -e "8025/inet=8025 inet n - n - - smtpd"
postconf -M# "smtp/inet" 2>/dev/null || true
postconf -F '*/*/chroot=n'

if [ -n "${smarthost}" ]; then
	host="${smarthost%%:*}"
	port="${smarthost##*:}"
	[ "${port}" = "${smarthost}" ] && port=587
	postconf -e "relayhost=[${host}]:${port}" "smtp_tls_security_level=encrypt"
	if [ "${port}" = "465" ]; then
		postconf -e "smtp_tls_wrappermode=yes"
	fi
	if [ -n "${smtp_username}" ]; then
		umask 077
		printf '[%s]:%s %s:%s\n' "${host}" "${port}" "${smtp_username}" "${smtp_password}" \
			>/etc/postfix/sasl_passwd
		postmap /etc/postfix/sasl_passwd
		postconf -e \
			"smtp_sasl_auth_enable=yes" \
			"smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd" \
			"smtp_sasl_security_options=noanonymous"
	fi
else
	postconf -e "relayhost="
fi

postfix check
unset SMTP_PASSWORD SMTP_PASSWORD_FILE smtp_password

exec "$@"
