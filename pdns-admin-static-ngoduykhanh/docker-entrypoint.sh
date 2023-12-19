#!/bin/bash

set -euo pipefail

subvars --prefix 'PDNS_ADMIN_STATIC_' < /pdns-nginx.conf.tpl > /etc/nginx/nginx.conf

exec "$@"
