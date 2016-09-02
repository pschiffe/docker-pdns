# PowerDNS Docker Images

This repository contains two Docker images - pdns-mysql and pdns-admin. Image **pdns-mysql** contains completely configurable [PowerDNS 4.x server](https://www.powerdns.com/) with mysql backend (without mysql server). Image **pdns-admin** contains [PowerDNS Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) web app, written in Flask, for managing PowerDNS servers. Pdns-admin is also completely configurable, running under uWSGI with nginx.

## pdns-mysql

Docker image with [PowerDNS 4.x server](https://www.powerdns.com/) and mysql backend (without mysql server). For running, it needs external mysql server. Env vars for mysql configuration:
```
(name = default value)

PDNS_gmysql_host = mysql
PDNS_gmysql_port = 3306
PDNS_gmysql_user = root
PDNS_gmysql_password = powerdns
PDNS_gmysql_dbname = powerdns
```
If linked with official [mariadb](https://hub.docker.com/_/mariadb/) image with alias `mysql`, the connection can be automatically configured, so you don't need to specify any of the above. Also, DB is automatically initialized if tables are missing.

PowerDNS server is configurable via env vars. Every variable starting with `PDNS_` will be inserted into `/etc/pdns/pdns.conf` conf file in the following way: prefix `PDNS_` will be stripped and every `_` will be replaced with `-`. For example, from above mysql config, `PDNS_gmysql_host = mysql` will became `gmysql-host=mysql` in `/etc/pdns/pdns.conf` file. This way, you can configure PowerDNS server any way you need within a `docker run` command.

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
