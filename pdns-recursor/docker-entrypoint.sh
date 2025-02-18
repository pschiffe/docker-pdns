#!/bin/sh

set -eu

: "${DEBUG:=0}"

if [ "${DEBUG}" -eq 1 ]; then
    set -x
fi

#### Function definitions

deriveConfigValuesFromEnvironment() {
  # Configure base vars
  : "${PDNS_local_port:=53}"
  : "${PDNS_local_address:=0.0.0.0}"
  : "${PDNS_allow_from:=0.0.0.0/0}"

  export PDNS_local_port PDNS_local_address PDNS_allow_from
}

### End of function definitions

if [ -f /etc/fedora-release ]; then
  config_file=/etc/pdns-recursor/recursor.conf
  pdns_user=pdns-recursor
elif [ -f /etc/alpine-release ]; then
  config_file=/etc/pdns/recursor.conf
  pdns_user=recursor
fi

if [ "${USE_EXISTING_CONFIG_FILE:-false}" = 'false' ]; then
    deriveConfigValuesFromEnvironment
    echo "Generating config file from environment"
    subvars --prefix 'PDNS_' < '/recursor.conf.tpl' > "${config_file}"
    chown "${pdns_user}:" "${config_file}"
  else
    echo "Using existing config file ${config_file}"
fi

exec "$@"
