FROM fedora:39

RUN dnf -y --setopt=install_weak_deps=False install \
    pdns-recursor \
  && dnf clean all

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'x86_64') \
  && curl -fsSL https://github.com/kha7iq/subvars/releases/download/v0.1.4/subvars_Linux_${arch}.tar.gz \
    | tar -xzf - -C /usr/local/bin subvars \
  && chmod +x /usr/local/bin/subvars

RUN mkdir -p /etc/pdns-recursor/api.d \
  && chown -R pdns-recursor: /etc/pdns-recursor/api.d \
  && mkdir -p /run/pdns-recursor \
  && chown -R pdns-recursor: /run/pdns-recursor

ENV VERSION=4.9 \
  PDNS_setuid=pdns-recursor \
  PDNS_setgid=pdns-recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.tpl /
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_recursor" ]
