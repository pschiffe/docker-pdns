FROM rockylinux/rockylinux:9-ubi

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'amd64') \
  && echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf \
  && echo 'tsflags=nodocs' >> /etc/dnf/dnf.conf \
  && echo 'assumeyes=True' >> /etc/dnf/dnf.conf \
  && curl -fsSL -o /etc/yum.repos.d/yarn.repo https://dl.yarnpkg.com/rpm/yarn.repo \
  && dnf module enable nodejs:20 postgresql:15 \
  && dnf install dnf-plugins-core epel-release \
  && dnf config-manager --set-disabled epel-cisco-openh264 \
  && dnf config-manager --set-enabled crb \
  && dnf --refresh upgrade \
  && dnf install \
    caddy \
    mariadb \
    npm \
    postgresql \
    python3-cffi \
    python3-ldap \
    python3-lxml \
    python3-mysqlclient \
    python3-pip \
    python3-psycopg2 \
    python3-pyyaml \
    python3-saml \
    python3-xmlsec \
    supervisor \
    uwsgi \
    uwsgi-plugin-python3 \
    yarn \
    https://github.com/kha7iq/subvars/releases/download/v0.1.5/subvars_${arch}.rpm \
  && dnf clean all

RUN mkdir -p /opt/powerdns-admin \
  && curl -fsSL https://github.com/PowerDNS-Admin/PowerDNS-Admin/archive/refs/tags/v0.4.1.tar.gz \
    | tar -xzf - -C /opt/powerdns-admin --strip 1 \
  && sed -i \
    -e '/cffi/d' \
    -e '/lxml/d' \
    -e '/mysqlclient/d' \
    -e '/psycopg2/d' \
    -e '/python-ldap/d' \
    -e '/python3-saml/d' \
    -e '/PyYAML/d' \
    /opt/powerdns-admin/requirements.txt \
  && chown -R root: /opt/powerdns-admin

WORKDIR /opt/powerdns-admin

RUN pip3 install -r requirements.txt --no-cache-dir

ENV FLASK_APP=/opt/powerdns-admin/powerdnsadmin/__init__.py
ENV SSL_MAIN_DOMAIN=""
ENV SSL_EXTRA_DOMAINS=""

COPY config.py.tpl Caddyfile.tpl docker-entrypoint.sh /
COPY run.py .
COPY --chown=uwsgi:uwsgi pdns-admin.ini /etc/uwsgi.ini
COPY supervisor.ini /etc/supervisord.d/supervisor.ini

RUN subvars --prefix 'PDNS_ADMIN_' < /config.py.tpl > /opt/powerdns-admin/config.py \
  && sed -i '/SQLALCHEMY_DATABASE_URI/d' /opt/powerdns-admin/config.py

RUN yarn install --pure-lockfile --production \
  && yarn cache clean \
  && flask assets build \
  && chown -R uwsgi: /opt/powerdns-admin/powerdnsadmin/static/.webassets-cache

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=10s --retries=3 --start-period=6s \
  CMD ["curl", "-fsSLo", "/dev/null", "http://127.0.0.1:9494"]

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
