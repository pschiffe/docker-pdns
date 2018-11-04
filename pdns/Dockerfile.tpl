FROM {{.Env.DK_FROM_IMAGE}}
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN apk add --no-cache \
    pdns \
    pdns-backend-mysql \
    pdns-doc \
    mariadb-client

RUN pip3 install envtpl \
  && rm -rf ~/.cache/*

ENV VERSION=4.1 \
  PDNS_guardian=yes \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_launch=gmysql

EXPOSE 53 53/udp

COPY pdns.conf.tpl /
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/usr/sbin/pdns_server" ]
