FROM pschiffe/pdns-admin-base:ngoduykhanh

RUN dnf -y --setopt=install_weak_deps=False install \
    mariadb \
    uwsgi-plugin-python3 \
  && dnf clean all

EXPOSE 9494

COPY docker-entrypoint.sh /
COPY pdns-admin.ini /etc/uwsgi.ini
RUN chown uwsgi: /etc/uwsgi.ini

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/uwsgi", "--ini", "/etc/uwsgi.ini" ]
