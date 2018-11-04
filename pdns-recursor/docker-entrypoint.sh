#!/bin/sh

set -euo pipefail

# Configure base vars
: "${PDNS_local_port:=53}"
: "${PDNS_local_address:=0.0.0.0}"

export PDNS_local_port PDNS_local_address

# Create config file from template
envtpl < /recursor.conf.tpl > /etc/pdns/recursor.conf

# fix config right
if getent passwd | grep -q '^pdns-recursor:'; then
    # Fedora user
    chown pdns-recursor:pdns-recursor /etc/pdns/recursor.conf
else
    # Alpine user
    chown recursor:recursor /etc/pdns/recursor.conf
fi

exec "$@"
