#!/bin/sh

set -eu

# Configure gpgsql env vars
: "${PDNS_gpgsql_host:=pgsql}"
: "${PDNS_gpgsql_port:=5432}"
: "${PDNS_gpgsql_user:=${PGSQL_ENV_POSTGRES_USER:-postgres}}"
: "${PDNS_gpgsql_password:=${PGSQL_ENV_POSTGRES_PASSWORD:-powerdns}}"
: "${PDNS_gpgsql_dbname:=${PGSQL_ENV_POSTGRES_DB:-powerdns}}"

# Use first part of node name as database name suffix
if [ "${NODE_NAME:-}" ]; then
    NODE_NAME=$(echo "${NODE_NAME}" | sed -e 's/\..*//' -e 's/-//')
    PDNS_gpgsql_dbname="${PDNS_gpgsql_dbname}${NODE_NAME}"
fi

export PDNS_gpgsql_host PDNS_gpgsql_port PDNS_gpgsql_user PDNS_gpgsql_password PDNS_gpgsql_dbname


PGPASSWORD="${PDNS_gpgsql_password}"
export PGPASSWORD
PGSQL_COMMAND="psql -h ${PDNS_gpgsql_host} -p ${PDNS_gpgsql_port} -U ${PDNS_gpgsql_user}"

# Wait for pgsql to respond
until $PGSQL_COMMAND -c ';' ; do
    >&2 echo 'Pgsql is unavailable - sleeping'
    sleep 3
done

# Initialize DB if needed
if [ "${SKIP_DB_CREATE:-false}" != 'true' ]; then
    echo "SELECT 'CREATE DATABASE ${PDNS_gpgsql_dbname}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PDNS_gpgsql_dbname}')\gexec" | $PGSQL_COMMAND
fi

PGSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_catalog = '${PDNS_gpgsql_dbname}' AND table_schema = 'public';"
PGSQL_NUM_TABLE=$($PGSQL_COMMAND -At -d "$PDNS_gpgsql_dbname" -c "$PGSQL_CHECK_IF_HAS_TABLE")
if [ "$PGSQL_NUM_TABLE" -eq 0 ]; then
    $PGSQL_COMMAND -d "$PDNS_gpgsql_dbname" < /usr/share/doc/pdns/schema.pgsql.sql
fi

if [ "${PDNS_superslave:-no}" = 'yes' ]; then
    # Configure supermasters if needed
    if [ "${SUPERMASTER_IPS:-}" ]; then
        $PGSQL_COMMAND -d "$PDNS_gpgsql_dbname" -c 'TRUNCATE supermasters;'
        PGSQL_INSERT_SUPERMASTERS=''
        if [ "${SUPERMASTER_COUNT:-0}" -eq 0 ]; then
            SUPERMASTER_COUNT=10
        fi
        i=1; while [ $i -le "${SUPERMASTER_COUNT}" ]; do
            SUPERMASTER_HOST=$(echo "${SUPERMASTER_HOSTS:-}" | awk -v col="$i" '{ print $col }')
            SUPERMASTER_IP=$(echo "${SUPERMASTER_IPS}" | awk -v col="$i" '{ print $col }')
            if [ -z "${SUPERMASTER_HOST:-}" ]; then
                SUPERMASTER_HOST=$(hostname -f)
            fi
            if [ "${SUPERMASTER_IP:-}" ]; then
                PGSQL_INSERT_SUPERMASTERS="${PGSQL_INSERT_SUPERMASTERS} INSERT INTO supermasters VALUES('${SUPERMASTER_IP}', '${SUPERMASTER_HOST}', 'admin');"
            fi
            i=$(( i + 1 ))
        done
        $PGSQL_COMMAND -d "$PDNS_gpgsql_dbname" -c "$PGSQL_INSERT_SUPERMASTERS"
    fi
fi

unset PGPASSWORD

# Create config file from template
subvars --prefix 'PDNS_' < '/pdns.conf.tpl' > '/etc/pdns/pdns.conf'

exec "$@"
