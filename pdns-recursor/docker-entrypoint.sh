#!/bin/sh

set -eu

# Configure base vars
: "${PDNS_local_port:=53}"
: "${PDNS_local_address:=0.0.0.0}"
: "${PDNS_allow_from:=0.0.0.0/0}"

export PDNS_local_port PDNS_local_address PDNS_allow_from

if [ -f /etc/fedora-release ]; then
  config_file=/etc/pdns-recursor/recursor.conf
  pdns_user=pdns-recursor
elif [ -f /etc/alpine-release ]; then
  config_file=/etc/pdns/recursor.conf
  pdns_user=recursor
fi

# Create config file from template
subvars --prefix 'PDNS_' < '/recursor.conf.tpl' > "${config_file}"

# Fix config file ownership
chown "${pdns_user}:" "${config_file}"

exec "$@"
