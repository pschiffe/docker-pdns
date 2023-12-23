FROM fedora:39

RUN echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf \
  && echo 'assumeyes=True' >> /etc/dnf/dnf.conf \
  && sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/fedora-cisco-openh264.repo \
  && dnf --refresh upgrade \
  && dnf install pdns-recursor \
  && dnf clean all

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'x86_64') \
  && curl -fsSL https://github.com/kha7iq/subvars/releases/download/v0.1.4/subvars_Linux_${arch}.tar.gz \
    | tar -xzf - -C /usr/local/bin subvars \
  && chmod +x /usr/local/bin/subvars

RUN mkdir -p /etc/pdns-recursor/api.d /run/pdns-recursor \
  && chown -R pdns-recursor: /etc/pdns-recursor/api.d /run/pdns-recursor

COPY recursor.conf.tpl docker-entrypoint.sh /

ENV VERSION=4.9 \
  PDNS_setuid=pdns-recursor \
  PDNS_setgid=pdns-recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_recursor" ]
