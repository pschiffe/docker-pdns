FROM {{.Env.DK_FROM_IMAGE}}
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN apk add --no-cache curl yarn

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/v0.1.tar.gz \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && mv /opt/powerdns-admin/package.json /opt/powerdns-admin/yarn.lock /opt/powerdns-admin/app/static \
  && find /opt/powerdns-admin -path /opt/powerdns-admin/app/static -prune -o -type f -exec rm -f {} + \
  && chown -R root: /opt/powerdns-admin

WORKDIR /opt/powerdns-admin/app/static
RUN yarn install

COPY pdns-nginx.conf /etc/nginx/conf.d/default.conf
