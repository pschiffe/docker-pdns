# PowerDNS Docker Images

This repository contains four Docker images - pdns-mysql, pdns-admin-static, pdns-admin-uwsgi and deprecated pdns-admin. Image **pdns-mysql** contains completely configurable [PowerDNS 4.x server](https://www.powerdns.com/) with mysql backend (without mysql server). Images **pdns-admin-static** and **pdns-admin-uwsgi** contains fronted (nginx) and backend (uWSGI) for [PowerDNS Admin](https://git.0x97.io/0x97/powerdns-admin) web app, written in Flask, for managing PowerDNS servers. Pdns-admin is also completely configurable. Deprecated **pdns-admin** contains PowerDNS Admin in a single image where both nginx and uWSGI processes are managed by systemd. This image won't be updated anymore.

All images are available on Docker Hub:

https://hub.docker.com/r/pschiffe/pdns-mysql/

https://hub.docker.com/r/pschiffe/pdns-admin-uwsgi/

https://hub.docker.com/r/pschiffe/pdns-admin-static/

https://hub.docker.com/r/pschiffe/pdns-admin/

## pdns-mysql

[![](https://images.microbadger.com/badges/image/pschiffe/pdns-mysql.svg)](http://microbadger.com/images/pschiffe/pdns-mysql "Get your own image badge on microbadger.com")

https://hub.docker.com/r/pschiffe/pdns-mysql/

Docker image with [PowerDNS 4.x server](https://www.powerdns.com/) and mysql backend (without mysql server). For running, it needs external mysql server. Env vars for mysql configuration:
```
(name=default value)

PDNS_gmysql_host=mysql
PDNS_gmysql_port=3306
PDNS_gmysql_user=root
PDNS_gmysql_password=powerdns
PDNS_gmysql_dbname=powerdns
```
If linked with official [mariadb](https://hub.docker.com/_/mariadb/) image with alias `mysql`, the connection can be automatically configured, so you don't need to specify any of the above. Also, DB is automatically initialized if tables are missing.

PowerDNS server is configurable via env vars. Every variable starting with `PDNS_` will be inserted into `/etc/pdns/pdns.conf` conf file in the following way: prefix `PDNS_` will be stripped and every `_` will be replaced with `-`. For example, from above mysql config, `PDNS_gmysql_host=mysql` will became `gmysql-host=mysql` in `/etc/pdns/pdns.conf` file. This way, you can configure PowerDNS server any way you need within a `docker run` command.

There is also a `SUPERMASTER_IPS` env var supported, which can be used to configure supermasters for slave dns server. [Docs](https://doc.powerdns.com/md/authoritative/modes-of-operation/#supermaster-automatic-provisioning-of-slaves). Multiple ip addresses separated by space should work.

### Examples

Master server with API enabled and with one slave server configured:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-master \
  --hostname ns1.example.com --link mariadb:mysql \
  -e PDNS_master=yes \
  -e PDNS_api=yes \
  -e PDNS_api_key=secret \
  -e PDNS_webserver=yes \
  -e PDNS_webserver_address=0.0.0.0 \
  -e PDNS_webserver_password=secret2 \
  -e PDNS_version_string=anonymous \
  -e PDNS_default_ttl=1500 \
  -e PDNS_soa_minimum_ttl=1200 \
  -e PDNS_default_soa_name=ns1.example.com \
  -e PDNS_default_soa_mail=hostmaster.example.com \
  -e PDNS_allow_axfr_ips=172.5.0.21 \
  -e PDNS_only_notify=172.5.0.21 \
  pschiffe/pdns-mysql
```

Slave server with supermaster:
```
docker run -d -p 53:53 -p 53:53/udp --name pdns-slave \
  --hostname ns2.example.com --link mariadb:mysql \
  -e PDNS_gmysql_dbname=powerdnsslave \
  -e PDNS_slave=yes \
  -e PDNS_version_string=anonymous \
  -e PDNS_disable_axfr=yes \
  -e PDNS_allow_notify_from=172.5.0.20 \
  -e SUPERMASTER_IPS=172.5.0.20 \
  pschiffe/pdns-mysql
```

## pdns-admin-uwsgi

[![](https://images.microbadger.com/badges/image/pschiffe/pdns-admin-uwsgi.svg)](https://microbadger.com/images/pschiffe/pdns-admin-uwsgi "Get your own image badge on microbadger.com")

https://hub.docker.com/r/pschiffe/pdns-admin-uwsgi/

Docker image with backend of [PowerDNS Admin](https://git.0x97.io/0x97/powerdns-admin) web app, written in Flask, for managing PowerDNS servers. This image contains the python part of the app running under uWSGI. It needs external mysql server. Env vars for mysql configuration:
```
(name=default value)

PDNS_ADMIN_SQLA_DB_HOST="'mysql'"
PDNS_ADMIN_SQLA_DB_PORT="'3306'"
PDNS_ADMIN_SQLA_DB_USER="'root'"
PDNS_ADMIN_SQLA_DB_PASSWORD="'powerdnsadmin'"
PDNS_ADMIN_SQLA_DB_NAME="'powerdnsadmin'"
```
If linked with official [mariadb](https://hub.docker.com/_/mariadb/) image with alias `mysql`, the connection can be automatically configured, so you don't need to specify any of the above. Also, DB is automatically initialized if tables are missing.

Similar to the pdns-mysql, pdns-admin is also completely configurable via env vars. Prefix in this case is `PDNS_ADMIN_`, but there is one caveat: as the config file is a python source file, every string value must be quoted, as shown above. Double quotes are consumed by Bash, so the single quotes stay for Python. (Port number in this case is treated as string, because later on it's concatenated with hostname, user, etc in the db uri). Configuration from these env vars will be written to the `/opt/powerdns-admin/config.py` file.

### Connecting to the PowerDNS server

For the pdns-admin to make sense, it needs a PowerDNS server to manage. The PowerDNS server needs to have exposed API (example configuration for PowerDNS 4.x):
```
api=yes
api-key=secret
webserver=yes
```

And again, PowerDNS connection is configured via env vars (it needs url of the PowerDNS server, api key and a version of PowerDNS server, for example 4.0.1):
```
(name=default value)

PDNS_ADMIN_PDNS_STATS_URL="'http://pdns:8081/'"
PDNS_ADMIN_PDNS_API_KEY="''"
PDNS_ADMIN_PDNS_VERSION="''"
```

If this container is linked with pdns-mysql from this repo with alias `pdns`, it will be configured automatically and none of the env vars from above are needed to be specified.

### Persistent data

There is a directory with user uploads which should be persistent: `/opt/powerdns-admin/upload`

### Example

When linked with pdns-mysql from this repo and with LDAP auth:
```
docker run -d --name pdns-admin-uwsgi \
  --link mariadb:mysql --link pdns-master:pdns \
  -v pdns-admin-upload:/opt/powerdns-admin/upload \
  -e PDNS_ADMIN_LDAP_TYPE="'ldap'" \
  -e PDNS_ADMIN_LDAP_URI="'ldaps://your-ldap-server:636'" \
  -e PDNS_ADMIN_LDAP_USERNAME="'cn=dnsuser,ou=users,ou=services,dc=example,dc=com'" \
  -e PDNS_ADMIN_LDAP_PASSWORD="'dnsuser'" \
  -e PDNS_ADMIN_LDAP_SEARCH_BASE="'ou=System Admins,ou=People,dc=example,dc=com'" \
  -e PDNS_ADMIN_LDAP_USERNAMEFIELD="'uid'" \
  -e PDNS_ADMIN_LDAP_FILTER="'(objectClass=inetorgperson)'" \
  pschiffe/pdns-admin-uwsgi
```

## pdns-admin-static

[![](https://images.microbadger.com/badges/image/pschiffe/pdns-admin-static.svg)](https://microbadger.com/images/pschiffe/pdns-admin-static "Get your own image badge on microbadger.com")

https://hub.docker.com/r/pschiffe/pdns-admin-static/

Fronted image with nginx and static files for [PowerDNS Admin](https://git.0x97.io/0x97/powerdns-admin). Exposes port 80 for connections, expects uWSGI backend image under `pdns-admin-uwsgi` alias.

### Example

```
docker run -d -p 8080:80 --name pdns-admin-static \
  --link pdns-admin-uwsgi:pdns-admin-uwsgi \
  pschiffe/pdns-admin-static
```

## pdns-admin - DEPRECATED

[![](https://images.microbadger.com/badges/image/pschiffe/pdns-admin.svg)](http://microbadger.com/images/pschiffe/pdns-admin "Get your own image badge on microbadger.com")

https://hub.docker.com/r/pschiffe/pdns-admin/

Docker image with [PowerDNS Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) web app, written in Flask, for managing PowerDNS servers. The app is running under uWSGI with nginx. Processes in the container are managed by systemd. For running, it needs external mysql server. Env vars for mysql configuration:
```
(name=default value)

PDNS_ADMIN_SQLA_DB_HOST="'mysql'"
PDNS_ADMIN_SQLA_DB_PORT="'3306'"
PDNS_ADMIN_SQLA_DB_USER="'root'"
PDNS_ADMIN_SQLA_DB_PASSWORD="'powerdnsadmin'"
PDNS_ADMIN_SQLA_DB_NAME="'powerdnsadmin'"
```
If linked with official [mariadb](https://hub.docker.com/_/mariadb/) image with alias `mysql`, the connection can be automatically configured, so you don't need to specify any of the above. Also, DB is automatically initialized if tables are missing.

Similar to the pdns-mysql, pdns-admin is also completely configurable via env vars. Prefix in this case is `PDNS_ADMIN_`, but there is one caveat: as the config file is a python source file, every string value must be quoted, as shown above. Double quotes are consumed by Bash, so the single quotes stay for Python. (Port number in this case is treated as string, because later on it's concatenated with hostname, user, etc in the db uri). Configuration from these env vars will be written to the `/opt/powerdns-admin/config.py` file.

### Connecting to the PowerDNS server

For the pdns-admin to make sense, it needs a PowerDNS server to manage. The PowerDNS server needs to have exposed API (example configuration for PowerDNS 4.x):
```
api=yes
api-key=secret
webserver=yes
```

And again, PowerDNS connection is configured via env vars (it needs url of the PowerDNS server, api key and a version of PowerDNS server, for example 4.0.1):
```
(name=default value)

PDNS_ADMIN_PDNS_STATS_URL="'http://pdns:8081/'"
PDNS_ADMIN_PDNS_API_KEY="''"
PDNS_ADMIN_PDNS_VERSION="''"
```

If this container is linked with pdns-mysql from this repo with alias `pdns`, it will be configured automatically and none of the env vars from above are needed to be specified.

### Persistent data

There is a directory with user uploads which should be persistent: `/opt/powerdns-admin/upload`

### Systemd

Because of the systemd is managing processes inside of this container, there are some special requirements when running this container: `/run` and `/tmp` must be mounted on tmpfs, and cgroup filesystem must be bind-mounted from the host. Example Docker run bit when running on Red Hat based distro: `--tmpfs /run --tmpfs /tmp -v /sys/fs/cgroup:/sys/fs/cgroup:ro` (If you are on a recent Fedora, you can install `oci-systemd-hook` rpm package, and you don't need to specify any of this, it will be done automatically for you.)

And if you want to see logs with `docker logs` command, allocate tty for the container with `-t, --tty` option.

### Example

When linked with pdns-mysql from this repo and with LDAP auth:
```
docker run -dt -p 8080:80 --name pdns-admin \
  --link mariadb:mysql --link pdns-master:pdns \
  -v pdns-admin-upload:/opt/powerdns-admin/upload \
  --tmpfs /run --tmpfs /tmp -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -e PDNS_ADMIN_LDAP_TYPE="'ldap'" \
  -e PDNS_ADMIN_LDAP_URI="'ldaps://your-ldap-server:636'" \
  -e PDNS_ADMIN_LDAP_USERNAME="'cn=dnsuser,ou=users,ou=services,dc=example,dc=com'" \
  -e PDNS_ADMIN_LDAP_PASSWORD="'dnsuser'" \
  -e PDNS_ADMIN_LDAP_SEARCH_BASE="'ou=System Admins,ou=People,dc=example,dc=com'" \
  -e PDNS_ADMIN_LDAP_USERNAMEFIELD="'uid'" \
  -e PDNS_ADMIN_LDAP_FILTER="'(objectClass=inetorgperson)'" \
  pschiffe/pdns-admin
```

## ansible-playbook.yml

Included ansible playbook can be used to build and run the containers from this repo. Run it simply with:
```
ansible-playbook ansible-playbook.yml
```
