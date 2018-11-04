generate-dockerfiles:
    # pdns-admin-static
	env DK_FROM_IMAGE='nginx:1.14-alpine' gomplate -f pdns-admin-static/Dockerfile.tpl -o pdns-admin-static/Dockerfile_amd64
	env DK_FROM_IMAGE='arm32v6/nginx:1.14-alpine' gomplate -f pdns-admin-static/Dockerfile.tpl -o pdns-admin-static/Dockerfile_arm32v6
	env DK_FROM_IMAGE='arm64v8/nginx:1.14-alpine' gomplate -f pdns-admin-static/Dockerfile.tpl -o pdns-admin-static/Dockerfile_arm64v8

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

build-pdns-admin-static:
	docker build -t eugenmayer/pdns-admin-static:amd64 pdns-admin-static -f pdns-admin-static/Dockerfile_amd64
	docker build -t eugenmayer/pdns-admin-static:arm32v6 pdns-admin-static -f pdns-admin-static/Dockerfile_arm32v6
	docker build -t eugenmayer/pdns-admin-static:arm64v8 pdns-admin-static -f pdns-admin-static/Dockerfile_arm64v8

build-pdns-admin-uwsgi:
	docker build -t eugenmayer/pdns-admin-uwsgi:amd64 pdns-admin-uwsgi -f pdns-admin-uwsgi/Dockerfile_amd64
	docker build -t eugenmayer/pdns-admin-uwsgi:arm32v6 pdns-admin-uwsgi -f pdns-admin-uwsgi/Dockerfile_arm32v6
	docker build -t eugenmayer/pdns-admin-uwsgi:arm64v8 pdns-admin-uwsgi -f pdns-admin-uwsgi/Dockerfile_arm64v8

build-pdns:
	docker build -t eugenmayer/pdns:amd64 pdns -f pdns/Dockerfile_amd64
	docker build -t eugenmayer/pdns:arm32v6 pdns -f pdns/Dockerfile_arm32v6
	docker build -t eugenmayer/pdns:arm64v8 pdns -f pdns/Dockerfile_arm64v8

build-pdns-recursor:
	docker build -t eugenmayer/pdns-recursor:amd64 pdns-recursor -f pdns-recursor/Dockerfile_amd64
	docker build -t eugenmayer/pdns-recursor:arm32v6 pdns-recursor -f pdns-recursor/Dockerfile_arm32v6
	docker build -t eugenmayer/pdns-recursor:arm64v8 pdns-recursor -f pdns-recursor/Dockerfile_arm64v8

build: generate-dockerfiles build-pdns-admin-static build-pdns-admin-uwsgi build-pdns build-pdns-recursor

init:
	# we could use alternative ways of installing it https://gomplate.hairyhenderson.ca/installing/
	go get github.com/hairyhenderson/gomplate/cmd/gomplate