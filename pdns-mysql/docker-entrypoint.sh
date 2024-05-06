#!/bin/sh

set -eu

##### Function definitions ####


function deriveMySQLSettingsFromExistingConfigFile {
  if [ ! -f /etc/pdns/pdns.conf ]; then
    echo "Use of existing file /etc/pdns/pdns.conf requested but file does not exist!"
    exit 1
  fi
  PDNS_gmysql_host=`sed -n 's/^gmysql-host=\(.*\)/\1/p' < /etc/pdns/pdns.conf`
  PDNS_gmysql_port=`sed -n 's/^gmysql-port=\(.*\)/\1/p' < /etc/pdns/pdns.conf`
  PDNS_gmysql_user=`sed -n 's/^gmysql-user=\(.*\)/\1/p' < /etc/pdns/pdns.conf`
  PDNS_gmysql_password=`sed -n 's/^gmysql-password=\(.*\)/\1/p' < /etc/pdns/pdns.conf`
  PDNS_gmysql_dbname=`sed -n 's/^gmysql-dbname=\(.*\)/\1/p' < /etc/pdns/pdns.conf`
}

function deriveMySQLSettingsFromEnvironment {
  # Configure mysql env vars
  : "${PDNS_gmysql_host:=${MYSQL_ENV_MYSQL_HOST:-mysql}}"
  : "${PDNS_gmysql_port:=${MYSQL_ENV_MYSQL_PORT:-3306}}"
  : "${PDNS_gmysql_user:=${MYSQL_ENV_MYSQL_USER:-root}}"
  if [ "${PDNS_gmysql_user}" = 'root' ]; then
      : "${PDNS_gmysql_password:=${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}}"
  fi
  : "${PDNS_gmysql_password:=${MYSQL_ENV_MYSQL_PASSWORD:-powerdns}}"
  : "${PDNS_gmysql_dbname:=${MYSQL_ENV_MYSQL_DATABASE:-powerdns}}"
  
  # Use first part of node name as database name suffix
  if [ "${NODE_NAME:-}" ]; then
      NODE_NAME=$(echo "${NODE_NAME}" | sed -e 's/\..*//' -e 's/-//')
      PDNS_gmysql_dbname="${PDNS_gmysql_dbname}${NODE_NAME}"
  fi
  
  export PDNS_gmysql_host PDNS_gmysql_port PDNS_gmysql_user PDNS_gmysql_password PDNS_gmysql_dbname
}

function generateMySQLCommand {
  EXTRA=''
  
  # Password Auth
  if [ "${PDNS_gmysql_password}" ]; then
      EXTRA="${EXTRA} -p${PDNS_gmysql_password}"
  fi
  
  # Allow socket connections
  if [ "${PDNS_gmysql_socket:-}" ]; then
      export PDNS_gmysql_host='localhost'
      EXTRA="${EXTRA} --socket=${PDNS_gmysql_socket}"
  fi
  
  MYSQL_COMMAND="mysql -h ${PDNS_gmysql_host} -P ${PDNS_gmysql_port} -u ${PDNS_gmysql_user}${EXTRA}"
}


function createDatabaseIfRequested {
  # Initialize DB if needed
  if [ "${SKIP_DB_CREATE:-false}" != 'true' ]; then
      $MYSQL_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${PDNS_gmysql_dbname}"
  fi
}

function initDatabase {
  if [ "${SKIP_DB_INIT:-false}" != 'true'  ]; then
    MYSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${PDNS_gmysql_dbname}';"
    MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_HAS_TABLE")
    if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
      echo "Database exists and has no tables yet, doing init";
      $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" < /usr/share/doc/pdns/schema.mysql.sql
    else
      echo "Database exists but already has tables, will not try to init";
    fi
  fi
}

function migrateDatabaseTo47 {
  # SQL migration to version 4.7
  MYSQL_CHECK_IF_47="SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = '${PDNS_gmysql_dbname}' AND table_name = 'domains' AND column_name = 'options';"
  MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_47")
  if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
    echo 'Migrating MySQL schema to version 4.7...'
    $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" < /usr/share/doc/pdns/4.3.0_to_4.7.0_schema.mysql.sql
  fi
}

function initSuperslave {
if [ "${PDNS_superslave:-no}" = 'yes' ]; then
    # Configure supermasters if needed
    if [ "${SUPERMASTER_IPS:-}" ]; then
        $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" -e 'TRUNCATE supermasters;'
        MYSQL_INSERT_SUPERMASTERS=''
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
                MYSQL_INSERT_SUPERMASTERS="${MYSQL_INSERT_SUPERMASTERS} INSERT INTO supermasters VALUES('${SUPERMASTER_IP}', '${SUPERMASTER_HOST}', 'admin');"
            fi
            i=$(( i + 1 ))
        done
        $MYSQL_COMMAND -D "$PDNS_gmysql_dbname" -e "$MYSQL_INSERT_SUPERMASTERS"
    fi
fi
}

function generateAndInstallConfigFileFromEnvironment {
  # Create config file from template
  subvars --prefix 'PDNS_' < '/pdns.conf.tpl' > '/etc/pdns/pdns.conf'
}


#### End of function definitions, let's get to work ... 

if [ ${USE_EXISTING_CONFIG_FILE:-false} = 'true' ]; then 
  deriveMySQLSettingsFromExistingConfigFile
else
  deriveMySQLSettingsFromEnvironment
fi    

generateMySQLCommand

# Wait for MySQL to respond
until $MYSQL_COMMAND -e ';' ; do
    >&2 echo 'MySQL is unavailable - sleeping'
    sleep 3
done


createDatabaseIfRequested
initDatabase
migrateDatabaseTo47
initSuperslave

if [ ${USE_EXISTING_CONFIG_FILE:-false} = 'false' ]; then 
  echo "(re-)generating config file from environment variables"
  generateAndInstallConfigFileFromEnvironment
fi

exec "$@"


