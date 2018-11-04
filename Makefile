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