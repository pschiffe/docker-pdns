FROM fedora:38

RUN echo 'install_weak_deps=False' >> /etc/dnf/dnf.conf \
  && echo 'assumeyes=True' >> /etc/dnf/dnf.conf \
  && curl -fsSL -o /etc/yum.repos.d/yarn.repo https://dl.yarnpkg.com/rpm/yarn.repo \
  && dnf --refresh upgrade \
  && dnf install \
    nodejs-npm \
    python3-cffi \
    python3-ldap \
    python3-lxml \
    python3-mysql \
    python3-pip \
    python3-pyyaml \
    python3-saml \
    python3-setuptools \
    python3-wheel \
    python3-xmlsec \
    uwsgi \
    yarn \
  && dnf clean all

RUN arch=$([ "$(arch)" = 'aarch64' ] && echo -n 'arm64' || echo -n 'x86_64') \
  && curl -fsSL https://github.com/kha7iq/subvars/releases/download/v0.1.4/subvars_Linux_${arch}.tar.gz \
    | tar -xzf - -C /usr/local/bin subvars \
  && chmod +x /usr/local/bin/subvars

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

RUN pip3 install --no-cache-dir python-dotenv \
  && pip3 install -r requirements.txt --no-cache-dir

ENV FLASK_APP=/opt/powerdns-admin/powerdnsadmin/__init__.py

COPY config.py.tpl /
COPY run.py .

RUN subvars --prefix 'PDNS_ADMIN_' < /config.py.tpl > /opt/powerdns-admin/config.py \
  && sed -i '/SQLALCHEMY_DATABASE_URI/d' /opt/powerdns-admin/config.py

RUN yarn install --pure-lockfile --production \
  && yarn cache clean \
  && flask assets build \
  && chown -R uwsgi: /opt/powerdns-admin/powerdnsadmin/static/.webassets-cache
