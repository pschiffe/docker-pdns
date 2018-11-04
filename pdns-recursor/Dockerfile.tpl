FROM {{.Env.DK_FROM_IMAGE}}
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN apk add --no-cache \
    pdns-recursor

RUN pip3 install envtpl \
  && rm -rf ~/.cache/*

RUN mkdir -p /etc/pdns/api.d \
  && chown -R recursor:recursor /etc/pdns/api.d

ENV VERSION=4.1 \
  PDNS_setuid=recursor \
  PDNS_setgid=recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.tpl /
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/usr/sbin/pdns_recursor" ]
