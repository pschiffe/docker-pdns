FROM fedora:27
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN dnf -y --setopt=install_weak_deps=False install \
    pdns-recursor \
  && dnf clean all

RUN pip3 install envtpl \
  && rm -rf ~/.cache/*

RUN mkdir -p /etc/pdns/api.d \
  && chown -R pdns-recursor:pdns-recursor /etc/pdns/api.d

ENV VERSION=4.0 \
  PDNS_setuid=recursor \
  PDNS_setgid=recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.tpl /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]
