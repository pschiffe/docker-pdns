FROM nginx:1.14-alpine
MAINTAINER "Peter Schiffer" <peter@rfv.sk>

RUN apk add --no-cache curl

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSL https://git.0x97.io/0x97/powerdns-admin/repository/master/archive.tar.gz \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && find /opt/powerdns-admin -path /opt/powerdns-admin/app/static -prune -o -type f -exec rm -f {} + \
  && chown -R root: /opt/powerdns-admin

COPY pdns-nginx.conf /etc/nginx/conf.d/default.conf
