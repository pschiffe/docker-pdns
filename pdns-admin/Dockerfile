FROM fedora:26
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN dnf -y --setopt=tsflags=nodocs install \
    python-pip \
    python2-mysql \
    python-ldap \
    mariadb \
    nginx \
    uwsgi \
    uwsgi-plugin-python \
  && dnf clean all \
  && systemctl enable nginx \
  && systemctl enable uwsgi

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSLk https://git.omicroninteractive.com/0x97/powerdns-admin/repository/archive.tar.gz?ref=master \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && sed -i '/MySQL-python/d' /opt/powerdns-admin/requirements.txt \
  && sed -i '/python-ldap/d' /opt/powerdns-admin/requirements.txt \
  && chown -R root: /opt/powerdns-admin \
  && chown -R uwsgi: /opt/powerdns-admin/upload

WORKDIR /opt/powerdns-admin

RUN pip3 install envtpl \
  && pip install -r requirements.txt \
  && rm -rf ~/.cache/*

STOPSIGNAL SIGRTMIN+3
RUN echo 'ForwardToConsole=yes' >> /etc/systemd/journald.conf

ENV container=docker \
  PDNS_ADMIN_LOGIN_TITLE="'PDNS'" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="'INFO'" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['SOA', 'NS', 'A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV']"

EXPOSE 80

VOLUME [ "/opt/powerdns-admin/upload" ]

COPY pdns-admin.ini /etc/uwsgi.d/
RUN chown uwsgi: /etc/uwsgi.d/pdns-admin.ini

COPY pdns-nginx.conf /etc/nginx/nginx.conf
COPY config.py.tpl /
COPY docker-cmd.sh /init

CMD [ "/init" ]
