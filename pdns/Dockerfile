FROM fedora:39

RUN echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf \
  && echo 'assumeyes=True' >> /etc/dnf/dnf.conf \
  && dnf --refresh upgrade \
  && dnf install \
    hostname \
    mariadb \
    pdns \
  && dnf --setopt 'tsflags=' install pdns-backend-mysql \
  && dnf clean all

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'x86_64') \
  && curl -fsSL https://github.com/kha7iq/subvars/releases/download/v0.1.4/subvars_Linux_${arch}.tar.gz \
    | tar -xzf - -C /usr/local/bin subvars \
  && chmod +x /usr/local/bin/subvars

COPY pdns.conf.tpl docker-entrypoint.sh /

ENV VERSION=4.8 \
  PDNS_guardian=yes \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_launch=gmysql

EXPOSE 53 53/udp

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_server" ]
