FROM fedora:29
MAINTAINER "Peter Schiffer" <peter@rfv.sk>

RUN dnf -y --setopt=install_weak_deps=False install \
    pdns-recursor \
  && dnf clean all

RUN pip3 install --no-cache-dir envtpl

RUN mkdir -p /etc/pdns-recursor/api.d \
  && chown -R pdns-recursor: /etc/pdns-recursor/api.d

ENV VERSION=4.1 \
  PDNS_setuid=pdns-recursor \
  PDNS_setgid=pdns-recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.tpl /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]
