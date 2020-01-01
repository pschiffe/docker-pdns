FROM pschiffe/pdns-admin-base:ngoduykhanh

RUN dnf -y --setopt=install_weak_deps=False install \
    mariadb \
    uwsgi-plugin-python3 \
  && dnf clean all

EXPOSE 9494

VOLUME [ "/opt/powerdns-admin/upload" ]

COPY docker-entrypoint.sh /
COPY pdns-admin.ini /etc/uwsgi.d/
RUN chown uwsgi: /etc/uwsgi.d/pdns-admin.ini

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/uwsgi", "--ini", "/etc/uwsgi.ini" ]
