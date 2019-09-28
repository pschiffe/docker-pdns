#!/bin/sh

set -euo pipefail

# Configure mysql env vars
: "${PDNS_gmysql_host:=${MYSQL_ENV_MYSQL_HOST:-mysql}}"
: "${PDNS_gmysql_port:=${MYSQL_ENV_MYSQL_PORT:-3306}}"
: "${PDNS_gmysql_user:=${MYSQL_ENV_MYSQL_USER:-root}}"
if [ "${PDNS_gmysql_user}" = 'root' ]; then
    : "${PDNS_gmysql_password:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}"
fi
: "${PDNS_gmysql_password:=${MYSQL_ENV_MYSQL_PASSWORD:-powerdns}}"
: "${PDNS_gmysql_dbname:=${MYSQL_ENV_MYSQL_DATABASE:-powerdns}}"

export PDNS_gmysql_host PDNS_gmysql_port PDNS_gmysql_user PDNS_gmysql_password PDNS_gmysql_dbname

# Create config file from template
envtpl < /pdns.conf.tpl > /etc/pdns/pdns.conf

# Initialize DB if needed
MYSQL_COMMAND="mysql -h ${PDNS_gmysql_host} -P ${PDNS_gmysql_port} -u ${PDNS_gmysql_user} -p${PDNS_gmysql_password}"

until $MYSQL_COMMAND -e ';' ; do
    >&2 echo 'MySQL is unavailable - sleeping'
    sleep 1
done

$MYSQL_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${PDNS_gmysql_dbname}"

MYSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${PDNS_gmysql_dbname}';"
MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_HAS_TABLE")
if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
    $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" < /usr/share/doc/pdns/schema.mysql.sql
fi

# Configure supermasters if needed
if [ "${SUPERMASTER_IPS:-}" ]; then
    $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" -e "TRUNCATE supermasters;"
    MYSQL_INSERT_SUPERMASTERS=''
    for i in $SUPERMASTER_IPS; do
        MYSQL_INSERT_SUPERMASTERS="${MYSQL_INSERT_SUPERMASTERS} INSERT INTO supermasters VALUES('${i}', '$(hostname -f)', 'admin');"
    done
    $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" -e "$MYSQL_INSERT_SUPERMASTERS"
fi

exec "$@"
