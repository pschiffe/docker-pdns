FROM fedora:42

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'amd64') \
  && echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf \
  && echo 'assumeyes=True' >> /etc/dnf/dnf.conf \
  && sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/fedora-cisco-openh264.repo \
  && dnf --refresh upgrade \
  && dnf install \
    gawk \
    hostname \
    mariadb \
    pdns \
    https://github.com/TektonOps/subvars/releases/download/v0.1.5/subvars_${arch}.rpm \
  && dnf --setopt 'tsflags=' install pdns-backend-mysql \
  && dnf clean all

RUN mkdir -p /run/pdns \
  && chown -R pdns: /etc/pdns /run/pdns

COPY pdns.conf.tpl docker-entrypoint.sh /

ENV VERSION=4.9 \
  PDNS_guardian=yes \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_launch=gmysql

EXPOSE 53 53/udp

HEALTHCHECK --interval=10s --timeout=10s --retries=3 --start-period=2s CMD ["pdns_control", "ping"]

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_server" ]
