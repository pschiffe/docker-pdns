FROM fedora:30
MAINTAINER "Peter Schiffer" <peter@rfv.sk>

RUN curl -sSL -o /etc/yum.repos.d/yarn.repo https://dl.yarnpkg.com/rpm/yarn.repo

RUN dnf -y --setopt=install_weak_deps=False install \
    python3-ldap \
    python3-mysql \
    python3-xmlsec \
    uwsgi \
    yarn \
  && dnf clean all

RUN mkdir -p /opt/powerdns-admin \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz \
    | tar -xzC /opt/powerdns-admin --strip 1 \
  && sed -i '/python-ldap/d' /opt/powerdns-admin/requirements.txt \
  && sed -i '/mysqlclient/d' /opt/powerdns-admin/requirements.txt \
  && chown -R root: /opt/powerdns-admin \
  && chown -R uwsgi: /opt/powerdns-admin/upload

WORKDIR /opt/powerdns-admin

RUN pip3 install --no-cache-dir envtpl python-dotenv \
  && pip3 install -r requirements.txt --no-cache-dir

ENV PDNS_ADMIN_LOG_LEVEL="'INFO'" \
  PDNS_ADMIN_SAML_ENABLED=False

COPY config.py.tpl /

RUN envtpl < /config.py.tpl > /opt/powerdns-admin/config.py \
  && sed -i '/SQLALCHEMY_DATABASE_URI/d' /opt/powerdns-admin/config.py

RUN yarn install --pure-lockfile \
  && flask assets build \
  && chown -R uwsgi: /opt/powerdns-admin/app/static/.webassets-cache
