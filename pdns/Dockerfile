FROM fedora:39

RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf \
  && dnf -y --setopt=install_weak_deps=False install \
    hostname \
    mariadb \
    pdns \
    pdns-backend-mysql \
  && dnf clean all

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'x86_64') \
  && curl -fsSL https://github.com/kha7iq/subvars/releases/download/v0.1.4/subvars_Linux_${arch}.tar.gz \
    | tar -xzf - -C /usr/local/bin subvars \
  && chmod +x /usr/local/bin/subvars

ENV VERSION=4.8 \
  PDNS_guardian=yes \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_launch=gmysql

EXPOSE 53 53/udp

COPY pdns.conf.tpl /
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_server" ]
