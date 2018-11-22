#!/bin/bash

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
: "${PDNS_API_URL:=http://${PDNS_ENV_PDNS_webserver_host:-pdns}:${PDNS_ENV_PDNS_webserver_port:-8081}/}"
: "${PDNS_API_KEY:=${PDNS_ENV_PDNS_api_key:-}}"
: "${PDNS_VERSION:=${PDNS_ENV_VERSION:-}}"

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

flask db upgrade

# initial settings if not available in the DB
$MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME//\'/} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_url', '${PDNS_API_URL}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_url') LIMIT 1;"
$MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME//\'/} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_key', '${PDNS_API_KEY}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_key') LIMIT 1;"
$MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME//\'/} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_version', '${PDNS_VERSION}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_version') LIMIT 1;"

# update pdns api settings if env changed
$MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME//\'/} -e "UPDATE setting SET value='${PDNS_API_URL}' WHERE name='pdns_api_url';"
$MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME//\'/} -e "UPDATE setting SET value='${PDNS_API_KEY}' WHERE name='pdns_api_key';"
$MYSQL_COMMAND ${PDNS_ADMIN_SQLA_DB_NAME//\'/} -e "UPDATE setting SET value='${PDNS_VERSION}' WHERE name='pdns_version';"

mkdir -p /run/uwsgi
chown uwsgi: /run/uwsgi

exec "$@"
