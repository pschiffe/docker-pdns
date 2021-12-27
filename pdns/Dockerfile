FROM fedora:35

RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf \
  && dnf -y --setopt=install_weak_deps=False install \
    hostname \
    mariadb \
    pdns \
    pdns-backend-mysql \
    python3-pip \
    python3-setuptools \
  && dnf clean all

RUN pip3 install --no-cache-dir envtpl

ENV VERSION=4.5 \
  PDNS_guardian=yes \
  PDNS_setuid=pdns \
  PDNS_setgid=pdns \
  PDNS_launch=gmysql

EXPOSE 53 53/udp

COPY pdns.conf.tpl /
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/pdns_server" ]
