FROM fedora:24
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN dnf -y --setopt=tsflags=nodocs install \
        pdns \
        pdns-backend-mysql \
        mariadb \
    && dnf clean all

RUN pip3 install envtpl \
    && rm -rf ~/.cache/*

ENV VERSION=4.0.1 \
    PDNS_guardian=yes \
    PDNS_setuid=pdns \
    PDNS_setgid=pdns \
    PDNS_launch=gmysql

EXPOSE 53 53/udp

COPY pdns.conf.tpl /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]
