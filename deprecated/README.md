# Deprecated PowerDNS-Admin Docker Images

The **pdns-admin** docker image for the [PowerDNS Admin](https://github.com/PowerDNS-Admin/PowerDNS-Admin) web app was previously created as two images: **pdns-admin-static** and **pdns-admin-uwsgi** for fronted (nginx) and backend (uWSGI). These two images won't by updated anymore.

https://hub.docker.com/r/pschiffe/pdns-admin-uwsgi/

https://hub.docker.com/r/pschiffe/pdns-admin-static/

## pdns-admin-uwsgi

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-admin-uwsgi/latest?label=latest) ![Docker Pulls](https://img.shields.io/docker/pulls/pschiffe/pdns-admin-uwsgi)

https://hub.docker.com/r/pschiffe/pdns-admin-uwsgi/

Docker image with backend of [PowerDNS Admin](https://github.com/PowerDNS-Admin/PowerDNS-Admin) web app, written in Flask, for managing PowerDNS servers. This image contains the python part of the app running under uWSGI. It needs external mysql server. Env vars for mysql configuration:
```
(name=default value)

PDNS_ADMIN_SQLA_DB_HOST="mysql"
PDNS_ADMIN_SQLA_DB_PORT="3306"
PDNS_ADMIN_SQLA_DB_USER="root"
PDNS_ADMIN_SQLA_DB_PASSWORD="powerdnsadmin"
PDNS_ADMIN_SQLA_DB_NAME="powerdnsadmin"
```
If linked with official [mariadb](https://hub.docker.com/_/mariadb/) image with alias `mysql`, the connection can be automatically configured, so you don't need to specify any of the above. Also, DB is automatically initialized if tables are missing.

Similar to the pdns-mysql, pdns-admin is also completely configurable via env vars. Prefix in this case is `PDNS_ADMIN_`, configuration will be written to the `/opt/powerdns-admin/config.py` file.

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

### Persistent data

There is a directory with user uploads which should be persistent: `/opt/powerdns-admin/upload`

### Example

When linked with pdns-mysql from this repo and with LDAP auth:
```
docker run -d --name pdns-admin-uwsgi \
  --link mariadb:mysql --link pdns-master:pdns \
  -v pdns-admin-upload:/opt/powerdns-admin/upload \
  pschiffe/pdns-admin-uwsgi
```

## pdns-admin-static

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/pschiffe/pdns-admin-static/latest?label=latest) ![Docker Pulls](https://img.shields.io/docker/pulls/pschiffe/pdns-admin-static)

https://hub.docker.com/r/pschiffe/pdns-admin-static/

Fronted image with nginx and static files for [PowerDNS Admin](https://github.com/PowerDNS-Admin/PowerDNS-Admin). Exposes port 80 for connections, expects uWSGI backend image under `pdns-admin-uwsgi` alias.

### Example

```
docker run -d -p 8080:80 --name pdns-admin-static \
  --link pdns-admin-uwsgi:pdns-admin-uwsgi \
  pschiffe/pdns-admin-static
```
