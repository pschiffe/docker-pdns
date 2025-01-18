#!/bin/sh

set -eu

: "${DEBUG:=0}"

if [ "${DEBUG}" -eq 1 ]; then
    set -x
fi

##### Function definitions ####

derivePostgreSQLSettingsFromExistingConfigFile() {
  if [ ! -f /etc/pdns/pdns.conf ]; then
    echo "Use of existing file /etc/pdns/pdns.conf requested but file does not exist!"
    exit 1
  fi

  PDNS_gpgsql_host=$(sed -n 's/^gpgsql-host=\(.*\)/\1/p' < /etc/pdns/pdns.conf)
  PDNS_gpgsql_port=$(sed -n 's/^gpgsql-port=\(.*\)/\1/p' < /etc/pdns/pdns.conf)
  PDNS_gpgsql_user=$(sed -n 's/^gpgsql-user=\(.*\)/\1/p' < /etc/pdns/pdns.conf)
  PDNS_gpgsql_password=$(sed -n 's/^gpgsql-password=\(.*\)/\1/p' < /etc/pdns/pdns.conf)
  PDNS_gpgsql_dbname=$(sed -n 's/^gpgsql-dbname=\(.*\)/\1/p' < /etc/pdns/pdns.conf)
}

derivePostgreSQLSettingsFromEnvironment() {
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
}

generatePostgreSQLCommand() {
  PGSQL_COMMAND="psql -h ${PDNS_gpgsql_host} -p ${PDNS_gpgsql_port} -U ${PDNS_gpgsql_user}"
}

createDatabaseIfRequested() {
  # Initialize DB if needed
  if [ "${SKIP_DB_CREATE:-false}" != 'true' ]; then
      echo "SELECT 'CREATE DATABASE ${PDNS_gpgsql_dbname}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PDNS_gpgsql_dbname}')\gexec" | $PGSQL_COMMAND
  fi
}

initDatabase() {
  if [ "${SKIP_DB_INIT:-false}" != 'true'  ]; then
    PGSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_catalog = '${PDNS_gpgsql_dbname}' AND table_schema = 'public';"
    PGSQL_NUM_TABLE=$($PGSQL_COMMAND -At -d "$PDNS_gpgsql_dbname" -c "$PGSQL_CHECK_IF_HAS_TABLE")
    if [ "$PGSQL_NUM_TABLE" -eq 0 ]; then
      echo "Database exists and has no tables yet, doing init";
      $PGSQL_COMMAND -d "$PDNS_gpgsql_dbname" < /usr/share/doc/pdns/schema.pgsql.sql
    else
      echo "Database exists but already has tables, will not try to init";
    fi
  fi
}

initSuperslave() {
  if [ "${PDNS_autosecondary:-no}" = 'yes' ] || [ "${PDNS_superslave:-no}" = 'yes' ]; then
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
}

generateAndInstallConfigFileFromEnvironment() {
  # Create config file from template
  subvars --prefix 'PDNS_' < '/pdns.conf.tpl' > '/etc/pdns/pdns.conf'
}

#### End of function definitions, let's get to work ...

if [ "${USE_EXISTING_CONFIG_FILE:-false}" = 'true' ]; then
  derivePostgreSQLSettingsFromExistingConfigFile
else
  derivePostgreSQLSettingsFromEnvironment
fi

generatePostgreSQLCommand

PGPASSWORD="${PDNS_gpgsql_password}"
export PGPASSWORD

# Wait for pgsql to respond
until $PGSQL_COMMAND -c ';' ; do
    >&2 echo 'Pgsql is unavailable - sleeping'
    sleep 3
done

createDatabaseIfRequested
initDatabase
initSuperslave

if [ "${USE_EXISTING_CONFIG_FILE:-false}" = 'false' ]; then
  echo "(re-)generating config file from environment variables"
  generateAndInstallConfigFileFromEnvironment
fi

unset PGPASSWORD

exec "$@"
