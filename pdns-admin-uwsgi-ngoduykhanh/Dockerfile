FROM pschiffe/pdns-admin-base:ngoduykhanh
MAINTAINER "Peter Schiffer" <peter@rfv.sk>

RUN dnf -y --setopt=install_weak_deps=False install \
    mariadb \
    uwsgi-plugin-python3 \
  && dnf clean all

COPY docker-cmd.sh /

EXPOSE 9494

VOLUME [ "/opt/powerdns-admin/upload" ]

COPY pdns-admin.ini /etc/uwsgi.d/
RUN chown uwsgi: /etc/uwsgi.d/pdns-admin.ini

CMD [ "/docker-cmd.sh" ]
