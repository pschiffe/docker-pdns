#!/bin/sh

set -u

usage() {
    echo "Usage: $0 [all|recursor-fedora|recursor-alpine|mysql-fedora|mysql-alpine|pgsql-fedora|pgsql-alpine|admin]" >&2
}

if [ "$#" -gt 1 ]; then
    usage
    exit 2
fi

requested_target=${1:-all}
case "$requested_target" in
    all)
        targets="recursor-fedora recursor-alpine mysql-fedora mysql-alpine pgsql-fedora pgsql-alpine admin"
        ;;
    recursor-fedora|recursor-alpine|mysql-fedora|mysql-alpine|pgsql-fedora|pgsql-alpine|admin)
        targets=$requested_target
        ;;
    *)
        usage
        exit 2
        ;;
esac

for source_dir in pdns-recursor pdns-mysql pdns-pgsql pdns-admin; do
    if [ ! -d "$source_dir" ]; then
        echo "Missing source directory: $source_dir (run this script from the repository root)" >&2
        exit 1
    fi
done

for dockerfile in \
    pdns-recursor/Dockerfile \
    pdns-recursor/Dockerfile.alpine \
    pdns-mysql/Dockerfile \
    pdns-mysql/Dockerfile.alpine \
    pdns-pgsql/Dockerfile \
    pdns-pgsql/Dockerfile.alpine \
    pdns-admin/Dockerfile
do
    if [ ! -f "$dockerfile" ]; then
        echo "Missing Dockerfile: $dockerfile" >&2
        exit 1
    fi
done

run_key="docker-pdns-e2e-$$"
network=$run_key
mysql_container="$run_key-mysql"
pgsql_container="$run_key-pgsql"
probe_container="$run_key-probe"
containers=""
mysql_started=false
pgsql_started=false
current_target=$requested_target

docker_version=$(docker --version 2>/dev/null || true)

build_image() {
    image=$1
    dockerfile=$2
    context=$3

    case "$docker_version" in
        *podman*)
            BUILDAH_FORMAT=docker docker build \
                --no-cache \
                --tag "$image" \
                --file "$dockerfile" \
                "$context"
            ;;
        *)
            docker build \
                --progress=plain \
                --no-cache \
                --tag "$image" \
                --file "$dockerfile" \
                "$context"
            ;;
    esac
}

register_container() {
    containers="$1 $containers"
}

cleanup() {
    status=$?
    trap - 0 HUP INT TERM
    for container in $containers; do
        docker rm -fv "$container" >/dev/null 2>&1 || true
    done
    docker network rm "$network" >/dev/null 2>&1 || true
    exit "$status"
}

trap cleanup 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
    failed_target=$1
    reason=$2
    echo "FAIL $failed_target: $reason" >&2
    docker logs "$run_key-$failed_target" >&2 2>/dev/null || true
    if [ "$mysql_started" = true ]; then
        docker logs "$mysql_container" >&2 2>/dev/null || true
    fi
    if [ "$pgsql_started" = true ]; then
        docker logs "$pgsql_container" >&2 2>/dev/null || true
    fi
    exit 1
}

if ! docker network create "$network" >/dev/null; then
    fail "$current_target" "could not create Docker network $network"
fi

needs_mysql=false
needs_pgsql=false
for target in $targets; do
    case "$target" in
        mysql-fedora|mysql-alpine|admin) needs_mysql=true ;;
        pgsql-fedora|pgsql-alpine) needs_pgsql=true ;;
    esac
done

if [ "$needs_mysql" = true ]; then
    register_container "$mysql_container"
    if ! docker run -d \
        --name "$mysql_container" \
        --network "$network" \
        --network-alias mysql \
        -e MYSQL_ROOT_PASSWORD=powerdns \
        docker.io/library/mariadb:lts-ubi >/dev/null; then
        fail "$current_target" "could not start MariaDB"
    fi
    mysql_started=true
fi

if [ "$needs_pgsql" = true ]; then
    register_container "$pgsql_container"
    if ! docker run -d \
        --name "$pgsql_container" \
        --network "$network" \
        --network-alias pgsql \
        -e POSTGRES_PASSWORD=powerdns \
        docker.io/library/postgres:18-alpine >/dev/null; then
        fail "$current_target" "could not start PostgreSQL"
    fi
    pgsql_started=true
fi

register_container "$probe_container"
if ! docker run -d \
    --name "$probe_container" \
    --network "$network" \
    docker.io/library/alpine:latest tail -f /dev/null >/dev/null; then
    fail "$current_target" "could not start probe container"
fi
if ! docker exec "$probe_container" apk add --no-cache bind-tools; then
    fail "$current_target" "could not install probe tools"
fi

wait_for_health() {
    target=$1
    container=$2
    attempt=1
    while [ "$attempt" -le 180 ]; do
        running=$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null || true)
        if [ "$running" != true ]; then
            fail "$target" "target container exited before becoming healthy"
        fi
        health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || true)
        if [ "$health" = healthy ]; then
            return 0
        fi
        if [ "$attempt" -eq 180 ]; then
            fail "$target" "target container did not become healthy within 180 seconds (last status: $health)"
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
}

assert_dns() {
    target=$1
    container=$2
    if ! docker exec "$probe_container" sh -c \
        "dig +short +time=2 +tries=1 @$container version.bind TXT CH | grep -Fx '\"docker-pdns-e2e\"'"; then
        fail "$target" "DNS version.bind assertion failed"
    fi
}

run_target() {
    target=$1
    current_target=$target
    container="$run_key-$target"
    image="docker-pdns-e2e:$target"

    case "$target" in
        recursor-fedora)
            dockerfile=pdns-recursor/Dockerfile
            context=pdns-recursor
            ;;
        recursor-alpine)
            dockerfile=pdns-recursor/Dockerfile.alpine
            context=pdns-recursor
            ;;
        mysql-fedora)
            dockerfile=pdns-mysql/Dockerfile
            context=pdns-mysql
            ;;
        mysql-alpine)
            dockerfile=pdns-mysql/Dockerfile.alpine
            context=pdns-mysql
            ;;
        pgsql-fedora)
            dockerfile=pdns-pgsql/Dockerfile
            context=pdns-pgsql
            ;;
        pgsql-alpine)
            dockerfile=pdns-pgsql/Dockerfile.alpine
            context=pdns-pgsql
            ;;
        admin)
            dockerfile=pdns-admin/Dockerfile
            context=pdns-admin
            ;;
    esac

    if ! build_image "$image" "$dockerfile" "$context"; then
        fail "$target" "image build failed"
    fi

    register_container "$container"
    case "$target" in
        recursor-fedora|recursor-alpine)
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                -e PDNS_version_string=docker-pdns-e2e \
                "$image" >/dev/null; then
                fail "$target" "could not start target container"
            fi
            ;;
        mysql-fedora|mysql-alpine)
            database=$(printf '%s' "$target" | tr '-' '_')
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                -e PDNS_gmysql_password=powerdns \
                -e "PDNS_gmysql_dbname=powerdns_e2e_$database" \
                -e PDNS_version_string=docker-pdns-e2e \
                "$image" >/dev/null; then
                fail "$target" "could not start target container"
            fi
            ;;
        pgsql-fedora|pgsql-alpine)
            database=$(printf '%s' "$target" | tr '-' '_')
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                -e PDNS_gpgsql_password=powerdns \
                -e "PDNS_gpgsql_dbname=powerdns_e2e_$database" \
                -e PDNS_version_string=docker-pdns-e2e \
                "$image" >/dev/null; then
                fail "$target" "could not start target container"
            fi
            ;;
        admin)
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                -e PDNS_ADMIN_SQLA_DB_PASSWORD=powerdns \
                "$image" >/dev/null; then
                fail "$target" "could not start target container"
            fi
            ;;
    esac

    wait_for_health "$target" "$container"

    case "$target" in
        admin)
            if ! docker exec "$probe_container" wget -q -O /dev/null "http://$container:8080/"; then
                fail "$target" "HTTP assertion failed"
            fi
            ;;
        *)
            assert_dns "$target" "$container"
            ;;
    esac

    echo "PASS $target"
}

for target in $targets; do
    run_target "$target"
done
