#!/usr/bin/env bash
set -euo pipefail

# JWT signing key: set BAREOS_API_SECRET to keep tokens valid across restarts
secret="${BAREOS_API_SECRET:-$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')}"

# Generate api.ini config
umask 077
cat <<CONF >/home/bareos/api.ini
[Director]
Name=${BAREOS_DIR_HOST}
Address=${BAREOS_DIR_HOST}
Port=9101

[JWT]
secret_key = ${secret}
algorithm = HS256
access_token_expire_minutes = 30
CONF

# Run Dockerfile CMD
exec "$@"
