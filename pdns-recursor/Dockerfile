FROM fedora:35

RUN dnf -y --setopt=install_weak_deps=False install \
    pdns-recursor \
    python3-pip \
    python3-setuptools \
  && dnf clean all

RUN pip3 install --no-cache-dir 'Jinja2<3.1' envtpl

RUN mkdir -p /etc/pdns-recursor/api.d \
  && chown -R pdns-recursor: /etc/pdns-recursor/api.d \
  && mkdir -p /run/pdns-recursor \
  && chown -R pdns-recursor: /run/pdns-recursor

ENV VERSION=4.5 \
  PDNS_setuid=pdns-recursor \
  PDNS_setgid=pdns-recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.tpl /
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_recursor" ]
