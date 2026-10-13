#!/usr/bin/env bash
set -euo pipefail

# Random alphanumeric secret (safe for sed and SQL)
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

for v in DB_PASSWORD DB_ADMIN_PASSWORD BAREOS_DIR_PASSWORD BAREOS_SD_PASSWORD \
	BAREOS_FD_PASSWORD BAREOS_WEBUI_PASSWORD; do
	file_env "${v}"
done

DB_INIT="${DB_INIT:-false}"
DB_UPDATE="${DB_UPDATE:-false}"
SENDER_MAIL="${SENDER_MAIL:-}"
WEBHOOK_NOTIFICATION="${WEBHOOK_NOTIFICATION:-false}"

if [ ! -f /etc/bareos/bareos-config.control ]; then
	tar xzf /bareos-dir.tgz --backup=simple --suffix=.before-control

	# Admin console for bareos-webui (pinned copy of upstream example)
	if [ ! -f /etc/bareos/bareos-dir.d/console/admin.conf ]; then
		cp /usr/local/share/bareos/admin.conf /etc/bareos/bareos-dir.d/console/admin.conf
	fi

	# Rotate every password generated at image build time (listed in .rndpwd),
	# otherwise all containers built from the same image share them
	if [ -f /etc/bareos/.rndpwd ]; then
		while IFS='=' read -r key value; do
			[ -n "${value}" ] || continue
			if [ "${key}" = 'XXX_REPLACE_WITH_DIRECTOR_PASSWORD_XXX' ]; then
				new="${BAREOS_DIR_PASSWORD:-$(gen_password)}"
			else
				new="$(gen_password)"
			fi
			grep -rlF -- "${value}" /etc/bareos | xargs -r sed -i "s|${value}|${new}|g"
		done </etc/bareos/.rndpwd
		rm -f /etc/bareos/.rndpwd
	fi

	# Update bareos-director configs
	# Director / mycatalog & mail report
	sed -i 's#dbuser = "bareos"#dbuser = '\""${DB_USER}"\"'#' \
		/etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
	sed -i 's#dbpassword = ""#dbpassword = '\""${DB_PASSWORD}"\"'#' \
		/etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
	sed -i 's#dbname = "bareos"#dbname = '\""${DB_NAME}"\"'\n  dbaddress = '\""${DB_HOST}"\"'\n  dbport = '\""${DB_PORT}"\"'#' \
		/etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
	for conf in Daemon Standard; do
		if [ -n "${SENDER_MAIL}" ]; then
			sed -i "s#<%r#<${SENDER_MAIL}#g" /etc/bareos/bareos-dir.d/messages/${conf}.conf
		fi
		sed -i "s#/usr/bin/bsmtp -h localhost#/usr/bin/bsmtp -h ${SMTP_HOST}#" \
			/etc/bareos/bareos-dir.d/messages/${conf}.conf
		sed -i "s#mail = root#mail = ${ADMIN_MAIL}#" \
			/etc/bareos/bareos-dir.d/messages/${conf}.conf

		# Setup webhook
		if [ "${WEBHOOK_NOTIFICATION}" = true ]; then
			sed -i 's#/usr/bin/bsmtp -h.*#/usr/local/bin/webhook-notify %t %e %c %l %n"#' \
				/etc/bareos/bareos-dir.d/messages/${conf}.conf
		fi
	done

	# storage daemon
	sed -i 's#Address = .*#Address = '\""${BAREOS_SD_HOST}"\"'#' \
		/etc/bareos/bareos-dir.d/storage/File.conf
	sed -i 's#Password = .*#Password = '\""${BAREOS_SD_PASSWORD}"\"'#' \
		/etc/bareos/bareos-dir.d/storage/File.conf

	# client/file daemon
	sed -i 's#Address = .*#Address = '\""${BAREOS_FD_HOST}"\"'#' \
		/etc/bareos/bareos-dir.d/client/bareos-fd.conf
	sed -i 's#Password = .*#Password = '\""${BAREOS_FD_PASSWORD}"\"'#' \
		/etc/bareos/bareos-dir.d/client/bareos-fd.conf

	# webUI
	sed -i 's#Password = .*#Password = '\""${BAREOS_WEBUI_PASSWORD}"\"'#' \
		/etc/bareos/bareos-dir.d/console/admin.conf

	# MyCatalog Backup
	sed -i "s#/var/lib/bareos/bareos.sql#/var/lib/bareos-director/bareos.sql#" \
		/etc/bareos/bareos-dir.d/fileset/Catalog.conf
	# Its bootstrap file is mailed as well: use the relay and the admin address
	sed -i -e "s#/usr/bin/bsmtp -h localhost#/usr/bin/bsmtp -h ${SMTP_HOST}#" \
		-e "s#\(Bootstrap for Job %j\\\\\" \)root\"#\1${ADMIN_MAIL}\"#" \
		/etc/bareos/bareos-dir.d/job/BackupCatalog.conf

	# Control file
	touch /etc/bareos/bareos-config.control
fi

if [ -z "${CI_TEST:-}" ]; then
	# Waiting Postgresql is up
	until pg_isready --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_ADMIN_USER}"; do
		echo "Waiting for postgresql..."
		sleep 5
	done
	echo "...postgresql is alive"
fi

export PGUSER="${DB_ADMIN_USER}"
export PGHOST="${DB_HOST}"
export PGPORT="${DB_PORT}"
export PGPASSWORD="${DB_ADMIN_PASSWORD}"

if [ ! -f /etc/bareos/bareos-db.control ] && [ "${DB_INIT}" = 'true' ]; then
	# Idempotent: the control file lives in the config volume, the data in the
	# DB volume, and the two may be reset independently
	role_exists=$(psql -tA -v ON_ERROR_STOP=1 -v u="${DB_USER}" <<'SQL'
SELECT 1 FROM pg_roles WHERE rolname = :'u';
SQL
	)
	if [ "${role_exists}" = 1 ]; then
		echo "Bareos DB init: role ${DB_USER} exists, syncing password"
		psql -q -v ON_ERROR_STOP=1 -v user="${DB_USER}" -v password="${DB_PASSWORD}" <<'SQL'
ALTER USER :"user" WITH PASSWORD :'password';
SQL
	else
		echo "Bareos DB init: create role ${DB_USER}"
		psql -q -v ON_ERROR_STOP=1 -v user="${DB_USER}" -v password="${DB_PASSWORD}" <<'SQL'
CREATE USER :"user" WITH CREATEDB CREATEROLE LOGIN PASSWORD :'password';
SQL
	fi

	db_exists=$(psql -tA -v ON_ERROR_STOP=1 -v d="${DB_NAME}" <<'SQL'
SELECT 1 FROM pg_database WHERE datname = :'d';
SQL
	)
	if [ "${db_exists}" = 1 ]; then
		echo "Bareos DB init: database ${DB_NAME} exists, skipping creation"
	else
		echo "Bareos DB init: create database ${DB_NAME}"
		/usr/lib/bareos/scripts/create_bareos_database
		/usr/lib/bareos/scripts/make_bareos_tables
	fi
	/usr/lib/bareos/scripts/grant_bareos_privileges

	# Control file
	touch /etc/bareos/bareos-db.control
fi

if [ "${DB_UPDATE}" = 'true' ]; then
	echo "Bareos DB update: Update tables"
	/usr/lib/bareos/scripts/update_bareos_tables
	echo "Bareos DB update: Grant privileges"
	/usr/lib/bareos/scripts/grant_bareos_privileges
fi

# Fix permissions
find /etc/bareos ! -user bareos -exec chown bareos {} +
chown -R bareos:bareos /var/lib/bareos

# Secrets are on disk now: keep them out of the daemon environment
# (WEBHOOK_URL stays, webhook-notify runs as a child of the director)
unset PGUSER PGHOST PGPORT PGPASSWORD DB_PASSWORD DB_ADMIN_PASSWORD \
	BAREOS_DIR_PASSWORD BAREOS_SD_PASSWORD BAREOS_FD_PASSWORD BAREOS_WEBUI_PASSWORD \
	DB_PASSWORD_FILE DB_ADMIN_PASSWORD_FILE BAREOS_DIR_PASSWORD_FILE \
	BAREOS_SD_PASSWORD_FILE BAREOS_FD_PASSWORD_FILE BAREOS_WEBUI_PASSWORD_FILE

# Run Dockerfile CMD
exec "$@"
