# PowerDNS Docker Images

This repository contains the following Docker images - pdns-mysql, pdns-pgsql, pdns-recursor and pdns-admin. Image **pdns-mysql** contains completely configurable [PowerDNS 4.x server](https://doc.powerdns.com/authoritative/) with mysql backend (without mysql server). Image **pdns-pgsql** contains completely configurable [PowerDNS 4.x server](https://doc.powerdns.com/authoritative/) with postgres backend (without postgres server). Image **pdns-recursor** contains completely configurable [PowerDNS 5.x recursor](https://doc.powerdns.com/recursor/). Image **pdns-admin** contains fronted (Caddy) and backend (uWSGI) for the [PowerDNS Admin](https://github.com/PowerDNS-Admin/PowerDNS-Admin) web app, which is written in Flask and used for managing PowerDNS servers.

The pdns-mysql, pdns-pgsql and pdns-recursor images have also the `alpine` tag, thanks to @PoppyPop.

All images are available on Docker Hub:

https://hub.docker.com/r/pschiffe/pdns-mysql/

https://hub.docker.com/r/pschiffe/pdns-pgsql/

https://hub.docker.com/r/pschiffe/pdns-recursor/

https://hub.docker.com/r/pschiffe/pdns-admin/

Source GitHub repository: https://github.com/pschiffe/docker-pdns

---
[![Static Badge](https://img.shields.io/badge/GitHub_Sponsors-grey?logo=github)](https://github.com/sponsors/pschiffe) [![Static Badge](https://img.shields.io/badge/paypal.me-grey?logo=paypal)](https://www.paypal.com/paypalme/pschiffe)

If this project is useful to you, please consider sponsoring me to support maintenance and further development. Thank you!

## pdns-mysql

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-mysql/latest?label=latest) ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-mysql/alpine?label=alpine) ![Docker Pulls](https://img.shields.io/docker/pulls/pschiffe/pdns-mysql)

https://hub.docker.com/r/pschiffe/pdns-mysql/

Docker image with [PowerDNS 4.x server](https://doc.powerdns.com/authoritative/) and mysql backend. Requires external mysql server. Env vars for mysql configuration:
```
(name=default value)

PDNS_gmysql_host=mysql
PDNS_gmysql_port=3306
PDNS_gmysql_user=root
PDNS_gmysql_password=powerdns
PDNS_gmysql_dbname=powerdns
```

If linked with the official [mariadb](https://hub.docker.com/_/mariadb/) image using the alias `mysql`, the connection can be automatically configured, eliminating the need to specify any of the above. The DB is automatically initialized if tables are missing.

The PowerDNS server is configurable via env vars. Every variable starting with `PDNS_` will be inserted into `/etc/pdns/pdns.conf` conf file in the following way: prefix `PDNS_` will be stripped away and every `_` will be replaced with `-`. For example, from the above mysql config, `PDNS_gmysql_host=mysql` will became `gmysql-host=mysql` in `/etc/pdns/pdns.conf` file. This way, you can configure PowerDNS server in any way you need within a `docker run` command.

The `SUPERMASTER_IPS` env var is also supported, which can be used to configure supermasters for a slave DNS server. [Docs](https://doc.powerdns.com/authoritative/modes-of-operation.html#autoprimary-automatic-provisioning-of-secondaries). Multiple IP addresses separated by spaces should work.

You can find all the available settings [here](https://doc.powerdns.com/authoritative/settings.html).

### Examples

Example of a master server with the API enabled and one slave server configured:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-master \
  --hostname ns1.example.com --link mariadb:mysql \
  -e PDNS_primary=yes \
  -e PDNS_api=yes \
  -e PDNS_api_key=secret \
  -e PDNS_webserver=yes \
  -e PDNS_webserver_address=0.0.0.0 \
  -e PDNS_webserver_password=secret2 \
  -e PDNS_version_string=anonymous \
  -e PDNS_default_ttl=1500 \
  -e PDNS_allow_axfr_ips=172.5.0.21 \
  -e PDNS_only_notify=172.5.0.21 \
  pschiffe/pdns-mysql
```

Example of a slave server with a supermaster:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-slave \
  --hostname ns2.example.com --link mariadb:mysql \
  -e PDNS_gmysql_dbname=powerdnsslave \
  -e PDNS_secondary=yes \
  -e PDNS_autosecondary=yes \
  -e PDNS_version_string=anonymous \
  -e PDNS_disable_axfr=yes \
  -e PDNS_allow_notify_from=172.5.0.20 \
  -e SUPERMASTER_IPS=172.5.0.20 \
  pschiffe/pdns-mysql
```

## pdns-pgsql

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-pgsql/latest?label=latest) ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-pgsql/alpine?label=alpine) ![Docker Pulls](https://img.shields.io/docker/pulls/pschiffe/pdns-pgsql)

https://hub.docker.com/r/pschiffe/pdns-pgsql/

Docker image with [PowerDNS 4.x server](https://doc.powerdns.com/authoritative/) and postgres backend. Requires external postgres server. Env vars for pgsql configuration:
```
(name=default value)

PDNS_gpgsql_host=pgsql
PDNS_gpgsql_port=5432
PDNS_gpgsql_user=postgres
PDNS_gpgsql_password=powerdns
PDNS_gpgsql_dbname=powerdns
```

If linked with the official [postgres](https://hub.docker.com/_/postgres) image using the alias `pgsql`, the connection can be automatically configured, eliminating the need to specify any of the above. The DB is automatically initialized if tables are missing.

The PowerDNS server is configurable via env vars. Every variable starting with `PDNS_` will be inserted into `/etc/pdns/pdns.conf` conf file in the following way: prefix `PDNS_` will be stripped away and every `_` will be replaced with `-`. For example, from the above pgsql config, `PDNS_gpgsql_host=pgsql` will became `gpgsql-host=pgsql` in `/etc/pdns/pdns.conf` file. This way, you can configure PowerDNS server in any way you need within a `docker run` command.

The `SUPERMASTER_IPS` env var is also supported, which can be used to configure supermasters for a slave DNS server. [Docs](https://doc.powerdns.com/authoritative/modes-of-operation.html#autoprimary-automatic-provisioning-of-secondaries). Multiple IP addresses separated by spaces should work.

You can find all the available settings [here](https://doc.powerdns.com/authoritative/settings.html).

### Examples

Example of a master server with the API enabled and one slave server configured:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-master \
  --hostname ns1.example.com --link postgres:pgsql \
  -e PDNS_primary=yes \
  -e PDNS_api=yes \
  -e PDNS_api_key=secret \
  -e PDNS_webserver=yes \
  -e PDNS_webserver_address=0.0.0.0 \
  -e PDNS_webserver_password=secret2 \
  -e PDNS_version_string=anonymous \
  -e PDNS_default_ttl=1500 \
  -e PDNS_allow_axfr_ips=172.5.0.21 \
  -e PDNS_only_notify=172.5.0.21 \
  pschiffe/pdns-pgsql
```

Example of a slave server with a supermaster:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-slave \
  --hostname ns2.example.com --link postgres:pgsql \
  -e PDNS_gpgsql_dbname=powerdnsslave \
  -e PDNS_secondary=yes \
  -e PDNS_autosecondary=yes \
  -e PDNS_version_string=anonymous \
  -e PDNS_disable_axfr=yes \
  -e PDNS_allow_notify_from=172.5.0.20 \
  -e SUPERMASTER_IPS=172.5.0.20 \
  pschiffe/pdns-pgsql
```

## pdns-recursor

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-recursor/latest?label=latest) ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-recursor/alpine?label=alpine) ![Docker Pulls](https://img.shields.io/docker/pulls/pschiffe/pdns-recursor)

https://hub.docker.com/r/pschiffe/pdns-recursor/

Docker image with [PowerDNS 5.x recursor](https://doc.powerdns.com/recursor/).

PowerDNS recursor is configurable via env vars. Every variable starting with `PDNS_` will be inserted into `/etc/pdns/recursor.conf` conf file in the following way: prefix `PDNS_` will be stripped away and every `_` will be replaced with `-`. For example, from the above mysql config, `PDNS_gmysql_host=mysql` will became `gmysql-host=mysql` in `/etc/pdns/recursor.conf` file. This way, you can configure PowerDNS recursor any way you need within a `docker run` command.

You can find all available settings [here](https://doc.powerdns.com/recursor/settings.html).

### Example

Recursor server with API enabled:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-recursor \
  -e PDNS_api_key=secret \
  -e PDNS_webserver=yes \
  -e PDNS_webserver_address=0.0.0.0 \
  -e PDNS_webserver_password=secret2 \
  pschiffe/pdns-recursor
```

## pdns-admin

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-admin/latest?label=latest) ![Docker Pulls](https://img.shields.io/docker/pulls/pschiffe/pdns-admin)

https://hub.docker.com/r/pschiffe/pdns-admin/

Docker image with [PowerDNS Admin](https://github.com/PowerDNS-Admin/PowerDNS-Admin) web app, written in Flask, for managing PowerDNS servers. It needs external mysql or postgres server.

There is also an official image for the pdns-admin on [Docker Hub](https://hub.docker.com/r/powerdnsadmin/pda-legacy). That image contains only gunicorn process that handles both - static files and the python app. Image in this repo contains uWSGI server handling requests for python app and Caddy web server handling static files and optionally HTTPS with Let's Encrypt.

Env vars for mysql configuration:
```
(name=default value)

PDNS_ADMIN_SQLA_DB_HOST=mysql
PDNS_ADMIN_SQLA_DB_PORT=3306
PDNS_ADMIN_SQLA_DB_USER=root
PDNS_ADMIN_SQLA_DB_PASSWORD=powerdnsadmin
PDNS_ADMIN_SQLA_DB_NAME=powerdnsadmin
```
If linked with official [mariadb](https://hub.docker.com/_/mariadb/) image with alias `mysql`, the connection can be automatically configured, so you don't need to specify any of the above.

Env vars for pgsql configuration:
```
PDNS_ADMIN_SQLA_DB_TYPE=postgres
PDNS_ADMIN_SQLA_DB_HOST=pgsql
PDNS_ADMIN_SQLA_DB_PORT=5432
PDNS_ADMIN_SQLA_DB_USER=postgres
PDNS_ADMIN_SQLA_DB_PASSWORD=powerdnsadmin
PDNS_ADMIN_SQLA_DB_NAME=powerdnsadmin
```

The DB is automatically initialized if tables are missing.

Similar to the pdns-mysql, pdns-admin is also completely configurable via env vars. Prefix in this case is `PDNS_ADMIN_`, configuration will be written to the `/opt/powerdns-admin/powerdnsadmin/default_config.py` file.

### Connecting to the PowerDNS server

For the pdns-admin to make sense, it needs a PowerDNS server to manage. The PowerDNS server needs to have exposed API (example configuration for PowerDNS 4.x):
```
api=yes
api-key=secret
webserver=yes
webserver-address=0.0.0.0
webserver-allow-from=172.5.0.0/16
```

And again, PowerDNS connection is configured via env vars (it needs url of the PowerDNS server, api key and a version of PowerDNS server, for example 4.0):
```
(name=default value)

PDNS_API_URL="http://pdns:8081/"
PDNS_API_KEY=""
PDNS_VERSION=""
```

If this container is linked with pdns-mysql from this repo with alias `pdns`, it will be configured automatically and none of the env vars from above are needed to be specified.

### PowerDNS Admin API keys and SALT

In order to be able to generate an API Key, you will need to specify the SALT via `PDNS_ADMIN_SALT` env var. This is a secret value, which can be generated via command:
```
python3 -c 'import bcrypt; print(bcrypt.gensalt().decode("utf-8"));'
```
Example value looks like `$2b$12$xxxxxxxxxxxxxxxxxxxxxx` - remember that when using docker-compose, literal `$` must be specified as `$$`.

### SSL with Let's Encrypt

Included Caddy server can optionally handle HTTPS with certificates from Let's Encrypt. To make this work, add `SSL_MAIN_DOMAIN` env var with your primary domain for HTTPS. The `SSL_EXTRA_DOMAINS` env var can contain list of comma-separated domains that will be redirected to the `SSL_MAIN_DOMAIN`. Public DNS must be properly configured and pdns-admin ports `8080`, `8443` and `8443/udp` must be exposed as `80`, `443` and `443/udp` (`443/udp` is for HTTP/3 traffic).

Finally, make the `/var/lib/caddy` dir inside of the pdns-admin container persistent - that's where the generated certificates will be stored.

### Persistent data

There is also a directory with user uploads which should be persistent: `/opt/powerdns-admin/upload`

### Examples

When linked with pdns-mysql from this repo:
```
docker run -d -p 8080:8080 --name pdns-admin \
  --link mariadb:mysql --link pdns-master:pdns \
  -v pdns-admin-upload:/opt/powerdns-admin/upload \
  pschiffe/pdns-admin
```

The same with HTTPS:
```
docker run -d -p 80:8080 -p 443:8443 -p 443:8443/udp --name pdns-admin \
  --link mariadb:mysql --link pdns-master:pdns \
  -v pdns-admin-caddy:/var/lib/caddy \
  -v pdns-admin-upload:/opt/powerdns-admin/upload \
  -e SSL_MAIN_DOMAIN=www.pdns-admin.com \
  -e SSL_EXTRA_DOMAINS=pdns-admin.com,pdns-admin.eu \
  pschiffe/pdns-admin
```

## Docker Compose

Included docker compose files contain example configuration of how to use these containers:
```
docker-compose -f docker-compose-mysql.yml up -d
```

## Ansible playbook

Included ansible playbooks can be used to build and run the containers from this repo. Run it with:
```
ansible-playbook ansible-playbook-mysql.yml
```
