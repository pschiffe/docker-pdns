FROM {{.Env.DK_FROM_IMAGE}}
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>

RUN apk add --no-cache \
    curl \
    py-pip \
    uwsgi-python \
    py-mysqldb \
    py-pyldap \
    py-cffi \
    py-bcrypt \
    mariadb-client

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSL https://git.0x97.io/0x97/powerdns-admin/repository/master/archive.tar.gz \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && sed -i '/MySQL-python/d' /opt/powerdns-admin/requirements.txt \
  && sed -i '/python-ldap/d' /opt/powerdns-admin/requirements.txt \
  && sed -i '/bcrypt/d' /opt/powerdns-admin/requirements.txt \
  && chown -R root: /opt/powerdns-admin \
  && chown -R uwsgi: /opt/powerdns-admin/upload

WORKDIR /opt/powerdns-admin

RUN pip install envtpl \
  && pip install -r requirements.txt \
  && rm -rf ~/.cache/*

ENV PDNS_ADMIN_LOGIN_TITLE="'PDNS'" \
  PDNS_ADMIN_TIMEOUT=10 \
  PDNS_ADMIN_LOG_LEVEL="'INFO'" \
  PDNS_ADMIN_BASIC_ENABLED=True \
  PDNS_ADMIN_SIGNUP_ENABLED=True \
  PDNS_ADMIN_RECORDS_ALLOW_EDIT="['SOA', 'NS', 'A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV']"

EXPOSE 9494

VOLUME [ "/opt/powerdns-admin/upload" ]

COPY pdns-admin.ini /etc/uwsgi/conf.d/
RUN chown uwsgi: /etc/uwsgi/conf.d/pdns-admin.ini \
  && ln -s /etc/uwsgi/uwsgi.ini /etc/uwsgi.ini

COPY config.py.tpl /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]
