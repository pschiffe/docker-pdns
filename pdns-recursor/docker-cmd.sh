#!/bin/sh

set -euo pipefail

# Configure base vars
: "${PDNS_local_port:=53}"
: "${PDNS_local_address:=0.0.0.0}"

export PDNS_local_port PDNS_local_address

# Create config file from template
envtpl < /recursor.conf.tpl > /etc/pdns/recursor.conf

exec /usr/sbin/pdns_recursor
