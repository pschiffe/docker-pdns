FROM pschiffe/pdns-admin-base

RUN dnf install \
    mariadb \
    uwsgi-plugin-python3 \
  && dnf clean all

COPY docker-entrypoint.sh /
COPY --chown=uwsgi:uwsgi pdns-admin.ini /etc/uwsgi.ini

EXPOSE 9494

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/uwsgi", "--ini", "/etc/uwsgi.ini" ]
