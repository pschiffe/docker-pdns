FROM pschiffe/pdns-admin-base

RUN dnf -y --setopt=install_weak_deps=False install \
    nginx \
  && dnf clean all

EXPOSE 80

COPY pdns-nginx.conf /etc/nginx/nginx.conf

CMD [ "/usr/sbin/nginx", "-g", "daemon off;" ]
