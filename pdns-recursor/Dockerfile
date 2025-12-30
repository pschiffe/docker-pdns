FROM fedora:43

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'amd64') \
  && echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf \
  && echo 'assumeyes=True' >> /etc/dnf/dnf.conf \
  && sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/fedora-cisco-openh264.repo \
  && dnf --refresh upgrade \
  && dnf install \
    pdns-recursor \
    https://github.com/TektonOps/subvars/releases/download/v0.1.5/subvars_${arch}.rpm \
  && dnf clean all

RUN mkdir -p /etc/pdns-recursor/api.d /run/pdns-recursor \
  && chown -R pdns-recursor: /etc/pdns-recursor /run/pdns-recursor

COPY recursor.conf.tpl docker-entrypoint.sh /

ENV VERSION=5.2 \
  PDNS_setuid=pdns-recursor \
  PDNS_setgid=pdns-recursor \
  PDNS_daemon=no \
  PDNS_loglevel=5

EXPOSE 53 53/udp

HEALTHCHECK --interval=10s --timeout=10s --retries=3 --start-period=2s CMD ["rec_control", "ping"]

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_recursor", "--enable-old-settings" ]
