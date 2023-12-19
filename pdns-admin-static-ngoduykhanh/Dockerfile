FROM pschiffe/pdns-admin-base

RUN dnf install nginx \
  && dnf clean all

COPY pdns-nginx.conf.tpl docker-entrypoint.sh /

EXPOSE 80

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD [ "/usr/sbin/nginx", "-g", "daemon off;" ]
