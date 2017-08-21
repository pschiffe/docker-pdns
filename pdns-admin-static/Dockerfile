FROM nginx:1.12-alpine
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN apk add --no-cache curl

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSLk https://git.omicroninteractive.com/0x97/powerdns-admin/repository/archive.tar.gz?ref=master \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && find /opt/powerdns-admin -path /opt/powerdns-admin/app/static -prune -o -type f -exec rm -f {} + \
  && chown -R root: /opt/powerdns-admin

COPY pdns-nginx.conf /etc/nginx/conf.d/default.conf
