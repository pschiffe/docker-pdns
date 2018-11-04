build-pdns-admin-static:
    FROM nginx:1.12-alpine
	docker build -t eugenmayer/poweradmin:latest poweradmin -f poweradmin/Dockerfile
	docker build -t eugenmayer/poweradmin:arm32v6 poweradmin -f poweradmin/Dockerfile_arm32v6

build-gui-pdnsmanager:
	docker build -t eugenmayer/pdnsmanager:latest pdnsmanager -f pdnsmanager/Dockerfile
	docker build -t eugenmayer/pdnsmanager:arm32v6 pdnsmanager -f pdnsmanager/Dockerfile_arm32v6

build-gui-djangopowerdns:
	docker build -t eugenmayer/djangopowerdns:latest djangopowerdns -f djangopowerdns/Dockerfile
	docker build -t eugenmayer/djangopowerdns:arm32v6 djangopowerdns -f djangopowerdns/Dockerfile_arm32v6

build-server:
	docker build -t eugenmayer/powerdns:latest powerdns-server -f powerdns-server/Dockerfile
	docker build -t eugenmayer/powerdns:arm32v6 powerdns-server -f powerdns-server/Dockerfile_arm32v6

build: build-gui build-server

push:
	docker push eugenmayer/powerdns:latest
	docker push eugenmayer/powerdns:arm32v6
	docker tag eugenmayer/powerdns:arm32v6 eugenmayer/powerdns:arm32v7
	docker push eugenmayer/powerdns:arm32v7

	docker push eugenmayer/poweradmin:latest
	docker push eugenmayer/poweradmin:arm32v6
	docker tag eugenmayer/poweradmin:arm32v6 eugenmayer/poweradmin:arm32v7

prepare-dockerfiles:
    # pdns-admin-static
	env DK_FROM_IMAGE='nginx:1.12-alpine' gomplate -f pdns-admin-static/Dockerfile.tpl -o pdns-admin-static/Dockerfile_amd64
	env DK_FROM_IMAGE='arm32v6/nginx:1.12-alpine' gomplate -f pdns-admin-static/Dockerfile.tpl -o pdns-admin-static/Dockerfile_arm32v6
	env DK_FROM_IMAGE='arm64v8/nginx:1.12-alpine' gomplate -f pdns-admin-static/Dockerfile.tpl -o pdns-admin-static/Dockerfile_arm64v8

	# pdns-admin-uwsgi
	env DK_FROM_IMAGE='python:3-alpine3.8' gomplate -f pdns-admin-uwsgi/Dockerfile.tpl -o pdns-admin-uwsgi/Dockerfile_amd64
	env DK_FROM_IMAGE='arm32v6/python:3-alpine3.8' gomplate -f pdns-admin-uwsgi/Dockerfile.tpl -o pdns-admin-uwsgi/Dockerfile_arm32v6
	env DK_FROM_IMAGE='arm64v8/python:3-alpine3.8' gomplate -f pdns-admin-uwsgi/Dockerfile.tpl -o pdns-admin-uwsgi/Dockerfile_arm64v8

	# pdns-recursor
   	env DK_FROM_IMAGE='python:3-alpine3.8' gomplate -f pdns-recursor/Dockerfile.tpl -o pdns-recursor/Dockerfile_amd64
    env DK_FROM_IMAGE='arm32v6/python:3-alpine3.8' gomplate -f pdns-recursor/Dockerfile.tpl -o pdns-recursor/Dockerfile_arm32v6
    env DK_FROM_IMAGE='arm64v8/python:3-alpine3.8' gomplate -f pdns-recursor/Dockerfile.tpl -o pdns-recursor/Dockerfile_arm64v8

    # pdns
	env DK_FROM_IMAGE='python:3-alpine3.8' gomplate -f pdns/Dockerfile.tpl -o pdns/Dockerfile_amd64
	env DK_FROM_IMAGE='arm32v6/python:3-alpine3.8' gomplate -f pdns/Dockerfile.tpl -o pdns/Dockerfile_arm32v6
	env DK_FROM_IMAGE='arm64v8/python:3-alpine3.8' gomplate -f pdns/Dockerfile.tpl -o pdns/Dockerfile_arm64v8
init:
	# we could use alternative ways of installing it https://gomplate.hairyhenderson.ca/installing/
	go get github.com/hairyhenderson/gomplate/cmd/gomplate