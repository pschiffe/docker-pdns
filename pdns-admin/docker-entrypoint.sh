#!/bin/bash

set -euo pipefail

# Configure db env vars
: "${PDNS_ADMIN_SQLA_DB_TYPE:=mysql}" # or postgres
: "${PDNS_ADMIN_SQLA_DB_HOST:=${MYSQL_ENV_MYSQL_HOST:-mysql}}"
: "${PDNS_ADMIN_SQLA_DB_PORT:=${MYSQL_ENV_MYSQL_PORT:-3306}}"
: "${PDNS_ADMIN_SQLA_DB_USER:=${MYSQL_ENV_MYSQL_USER:-${PGSQL_ENV_POSTGRES_USER:-root}}}"
if [ "${PDNS_ADMIN_SQLA_DB_USER}" = "root" ]; then
    : "${PDNS_ADMIN_SQLA_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}"
fi
: "${PDNS_ADMIN_SQLA_DB_PASSWORD:=${MYSQL_ENV_MYSQL_PASSWORD:-${PGSQL_ENV_POSTGRES_PASSWORD:-powerdnsadmin}}}"
: "${PDNS_ADMIN_SQLA_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-${PGSQL_ENV_POSTGRES_DB:-powerdnsadmin}}}"

# Cleanup quotes from db env vars
PDNS_ADMIN_SQLA_DB_TYPE="${PDNS_ADMIN_SQLA_DB_TYPE//[\'\"]}"
PDNS_ADMIN_SQLA_DB_HOST="${PDNS_ADMIN_SQLA_DB_HOST//[\'\"]}"
PDNS_ADMIN_SQLA_DB_PORT="${PDNS_ADMIN_SQLA_DB_PORT//[\'\"]}"
PDNS_ADMIN_SQLA_DB_USER="${PDNS_ADMIN_SQLA_DB_USER//[\'\"]}"
PDNS_ADMIN_SQLA_DB_PASSWORD="${PDNS_ADMIN_SQLA_DB_PASSWORD//[\'\"]}"
PDNS_ADMIN_SQLA_DB_NAME="${PDNS_ADMIN_SQLA_DB_NAME//[\'\"]}"

export PDNS_ADMIN_SQLA_DB_TYPE PDNS_ADMIN_SQLA_DB_HOST PDNS_ADMIN_SQLA_DB_PORT PDNS_ADMIN_SQLA_DB_USER PDNS_ADMIN_SQLA_DB_PASSWORD PDNS_ADMIN_SQLA_DB_NAME

# Configure pdns server env vars
: "${PDNS_API_URL:=http://${PDNS_ENV_PDNS_webserver_host:-pdns}:${PDNS_ENV_PDNS_webserver_port:-8081}/}"
: "${PDNS_API_KEY:=${PDNS_ENV_PDNS_api_key:-}}"
: "${PDNS_VERSION:=${PDNS_ENV_VERSION:-}}"

# Generate secret key
[ -f /root/secret-key ] || tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 32 > /root/secret-key || true
PDNS_ADMIN_SECRET_KEY="$(cat /root/secret-key)"

export PDNS_ADMIN_SECRET_KEY

subvars --prefix 'SSL_' < '/Caddyfile.tpl' > '/etc/caddy/Caddyfile'
subvars --prefix 'PDNS_ADMIN_' < '/config.py.tpl' > '/opt/powerdns-admin/powerdnsadmin/default_config.py'

# Initialize DB if needed
if [[ "${PDNS_ADMIN_SQLA_DB_TYPE}" == 'mysql' ]]; then
    SQL_COMMAND="mysql -h ${PDNS_ADMIN_SQLA_DB_HOST} -P ${PDNS_ADMIN_SQLA_DB_PORT} -u ${PDNS_ADMIN_SQLA_DB_USER} -p${PDNS_ADMIN_SQLA_DB_PASSWORD} -e"
elif [[ "${PDNS_ADMIN_SQLA_DB_TYPE}" == 'postgres' ]]; then
    PGPASSWORD="${PDNS_ADMIN_SQLA_DB_PASSWORD}"
    export PGPASSWORD
    SQL_COMMAND="psql -h ${PDNS_ADMIN_SQLA_DB_HOST} -p ${PDNS_ADMIN_SQLA_DB_PORT} -U ${PDNS_ADMIN_SQLA_DB_USER} -c"
else
    >&2 echo "Invalid DB type: ${PDNS_ADMIN_SQLA_DB_TYPE}"
    exit 1
fi

until $SQL_COMMAND ';' ; do
    >&2 echo 'DB is unavailable - sleeping'
    sleep 1
done

if [[ "${SKIP_DB_CREATE:-false}" != 'true' ]]; then
    if [[ "${PDNS_ADMIN_SQLA_DB_TYPE}" == 'mysql' ]]; then
        $SQL_COMMAND "CREATE DATABASE IF NOT EXISTS ${PDNS_ADMIN_SQLA_DB_NAME}"
    elif [[ "${PDNS_ADMIN_SQLA_DB_TYPE}" == 'postgres' ]]; then
        echo "SELECT 'CREATE DATABASE ${PDNS_ADMIN_SQLA_DB_NAME}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PDNS_ADMIN_SQLA_DB_NAME}')\gexec" | ${SQL_COMMAND::-3}
    fi
fi

flask db upgrade

# initial settings if not available in the DB
$SQL_COMMAND "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_url', '${PDNS_API_URL//[\'\"]}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_url') LIMIT 1;" "${PDNS_ADMIN_SQLA_DB_NAME}"
$SQL_COMMAND "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_key', '${PDNS_API_KEY//[\'\"]}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_key') LIMIT 1;" "${PDNS_ADMIN_SQLA_DB_NAME}"
$SQL_COMMAND "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_version', '${PDNS_VERSION//[\'\"]}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_version') LIMIT 1;" "${PDNS_ADMIN_SQLA_DB_NAME}"

# update pdns api settings if env changed
$SQL_COMMAND "UPDATE setting SET value='${PDNS_API_URL//[\'\"]}' WHERE name='pdns_api_url';" "${PDNS_ADMIN_SQLA_DB_NAME}"
$SQL_COMMAND "UPDATE setting SET value='${PDNS_API_KEY//[\'\"]}' WHERE name='pdns_api_key';" "${PDNS_ADMIN_SQLA_DB_NAME}"
$SQL_COMMAND "UPDATE setting SET value='${PDNS_VERSION//[\'\"]}' WHERE name='pdns_version';" "${PDNS_ADMIN_SQLA_DB_NAME}"

mkdir -p /run/uwsgi
chown uwsgi: /run/uwsgi

exec "$@"
