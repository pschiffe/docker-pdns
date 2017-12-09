FROM alpine:3.7
MAINTAINER "Peter Schiffer" <pschiffe@redhat.com>
  
RUN set -xe \
	&& apk update --no-cache && apk upgrade --no-cache \
	&& apk add --update --no-cache pdns-recursor python3 \
	&& rm -rf /var/cache/apk/*

RUN pip3 install envtpl \
  && rm -rf ~/.cache/*

ENV VERSION=4.0.4 \
  PDNS_setuid=recursor \
  PDNS_setgid=recursor \
  PDNS_daemon=no

EXPOSE 53 53/udp

COPY recursor.conf.tpl /
COPY docker-cmd.sh /

CMD [ "/docker-cmd.sh" ]
