NAME = poppypop/pdns-recursor
VERSION = latest

.PHONY: all build run shell

all: build

build:	
	docker build -t $(NAME):$(VERSION) --rm .

run:
	docker run -ti --rm -p 15053:53 -p 15053:53/udp -p 15082:8082 -e PDNS_webserver=yes -e PDNS_webserver_address=0.0.0.0 -e PDNS_api_key=abcd $(NAME):$(VERSION) 
	
shell:
	docker run -ti --rm -p 15053:53 -p 15053:53/udp -p 15082:8082 -e PDNS_webserver=yes -e PDNS_webserver_address=0.0.0.0 -e PDNS_api_key=abcd $(NAME):$(VERSION) /bin/sh
