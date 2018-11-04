#!/bin/sh

set -euo pipefail

# Configure mysql env vars
: "${PDNS_ADMIN_SQLA_DB_HOST:='${MYSQL_ENV_MYSQL_HOST:-mysql}'}"
: "${PDNS_ADMIN_SQLA_DB_PORT:='${MYSQL_ENV_MYSQL_PORT:-3306}'}"
: "${PDNS_ADMIN_SQLA_DB_USER:='${MYSQL_ENV_MYSQL_USER:-root}'}"
if [ "${PDNS_ADMIN_SQLA_DB_USER}" = "'root'" ]; then
    : "${PDNS_ADMIN_SQLA_DB_PASSWORD:='$MYSQL_ENV_MYSQL_ROOT_PASSWORD'}"
fi
: "${PDNS_ADMIN_SQLA_DB_PASSWORD:='${MYSQL_ENV_MYSQL_PASSWORD:-powerdnsadmin}'}"
: "${PDNS_ADMIN_SQLA_DB_NAME:='${MYSQL_ENV_MYSQL_DATABASE:-powerdnsadmin}'}"

export PDNS_ADMIN_SQLA_DB_HOST PDNS_ADMIN_SQLA_DB_PORT PDNS_ADMIN_SQLA_DB_USER PDNS_ADMIN_SQLA_DB_PASSWORD PDNS_ADMIN_SQLA_DB_NAME

# Configure pdns server env vars
: "${PDNS_ADMIN_PDNS_STATS_URL:='http://${PDNS_ENV_PDNS_webserver_host:-pdns}:${PDNS_ENV_PDNS_webserver_port:-8081}/'}"
: "${PDNS_ADMIN_PDNS_API_KEY:='${PDNS_ENV_PDNS_api_key:-}'}"
: "${PDNS_ADMIN_PDNS_VERSION:='${PDNS_ENV_VERSION:-}'}"

export PDNS_ADMIN_PDNS_STATS_URL PDNS_ADMIN_PDNS_API_KEY PDNS_ADMIN_PDNS_VERSION

# Generate secret key
[ -f /root/secret-key ] || tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 32 > /root/secret-key || true
PDNS_ADMIN_SECRET_KEY="'$(cat /root/secret-key)'"

export PDNS_ADMIN_SECRET_KEY

envtpl < /config.py.tpl > /opt/powerdns-admin/config.py

# Initialize DB if needed
MYSQL_COMMAND="mysql -h ${PDNS_ADMIN_SQLA_DB_HOST//\'/} -P ${PDNS_ADMIN_SQLA_DB_PORT//\'/} -u ${PDNS_ADMIN_SQLA_DB_USER//\'/} -p${PDNS_ADMIN_SQLA_DB_PASSWORD//\'/}"

until $MYSQL_COMMAND -e ';' ; do
    >&2 echo 'MySQL is unavailable - sleeping'
    sleep 1
done

$MYSQL_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${PDNS_ADMIN_SQLA_DB_NAME//\'/}"

MYSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${PDNS_ADMIN_SQLA_DB_NAME//\'/}';"
MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_HAS_TABLE")
if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
    python2 /opt/powerdns-admin/create_db.py
fi

# python2 /opt/powerdns-admin/db_upgrade.py

mkdir -p /run/uwsgi
chown uwsgi: /run/uwsgi

exec "$@"
