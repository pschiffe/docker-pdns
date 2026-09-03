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
legacy_mysql_container="$run_key-mysql-legacy"
pgsql_container="$run_key-pgsql"
probe_container="$run_key-probe"
containers=""
mysql_started=false
legacy_mysql_started=false
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
    if [ "$legacy_mysql_started" = true ]; then
        docker logs "$legacy_mysql_container" >&2 2>/dev/null || true
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
needs_legacy_mysql=false
needs_pgsql=false
for target in $targets; do
    case "$target" in
        mysql-fedora|mysql-alpine) needs_mysql=true ;;
        pgsql-fedora|pgsql-alpine) needs_pgsql=true ;;
        admin)
            needs_mysql=true
            needs_pgsql=true
            needs_legacy_mysql=true
            ;;
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

if [ "$needs_legacy_mysql" = true ]; then
    register_container "$legacy_mysql_container"
    if ! docker run -d \
        --name "$legacy_mysql_container" \
        --network "$network" \
        --network-alias mysql-legacy \
        -e MARIADB_ROOT_PASSWORD=powerdns \
        docker.io/library/mariadb:11.2.4 >/dev/null; then
        fail "$current_target" "could not start legacy MariaDB"
    fi
    legacy_mysql_started=true
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
    docker.io/library/alpine:3.24 tail -f /dev/null >/dev/null; then
    fail "$current_target" "could not start probe container"
fi
if ! docker exec "$probe_container" apk add --no-cache bind-tools curl jq; then
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

assert_recursion() {
    target=$1
    container=$2
    if ! docker exec "$probe_container" sh -c \
        "dig +short +time=5 +tries=2 @$container example.com A | grep -Eq '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$'"; then
        fail "$target" "real-world recursive DNS assertion failed"
    fi
}

assert_authoritative_zone() {
    target=$1
    container=$2
    zone="e2e-$target.test."
    record="www.$zone"
    address=192.0.2.1
    api="http://$container:8081/api/v1/servers/localhost/zones"

    if ! docker exec "$probe_container" curl -fsS \
        -H 'X-API-Key: powerdns' \
        -H 'Content-Type: application/json' \
        --data "{\"name\":\"$zone\",\"kind\":\"Native\",\"nameservers\":[]}" \
        "$api" >/dev/null; then
        fail "$target" "authoritative zone creation failed"
    fi

    if ! docker exec "$probe_container" curl -fsS \
        -X PATCH \
        -H 'X-API-Key: powerdns' \
        -H 'Content-Type: application/json' \
        --data "{\"rrsets\":[{\"name\":\"$record\",\"type\":\"A\",\"ttl\":60,\"changetype\":\"REPLACE\",\"records\":[{\"content\":\"$address\",\"disabled\":false}]}]}" \
        "$api/$zone" >/dev/null; then
        fail "$target" "authoritative record creation failed"
    fi

    if ! docker exec "$probe_container" sh -c \
        "dig +short +time=2 +tries=1 @$container $record A | grep -Fx '$address'"; then
        fail "$target" "authoritative record resolution failed"
    fi
}

start_admin_pdns() {
    admin_pdns_container="$run_key-admin-pdns"
    admin_pdns_image='docker-pdns-e2e:admin-pdns'

    if ! build_image "$admin_pdns_image" pdns-mysql/Dockerfile pdns-mysql; then
        fail admin "Admin PowerDNS image build failed"
    fi

    register_container "$admin_pdns_container"
    if ! docker run -d \
        --name "$admin_pdns_container" \
        --network "$network" \
        -e PDNS_gmysql_password=powerdns \
        -e PDNS_gmysql_dbname=powerdns_e2e_admin_pdns \
        -e PDNS_api=yes \
        -e PDNS_api_key=powerdns \
        -e PDNS_webserver=yes \
        -e PDNS_webserver_address=0.0.0.0 \
        -e PDNS_webserver_allow_from=0.0.0.0/0 \
        "$admin_pdns_image" >/dev/null; then
        fail admin-pdns "could not start Admin PowerDNS container"
    fi

    wait_for_health admin-pdns "$admin_pdns_container"
}

assert_admin_flow() {
    backend=$1
    admin_container=$2
    pdns_container=$3

    if ! docker exec -i "$probe_container" sh -s -- \
        "$backend" "$admin_container" "$pdns_container" <<'ADMIN_PROBE'
set -eu

backend=$1
admin_container=$2
pdns_container=$3
base_url="http://$admin_container:8080"
cookie_jar="/tmp/admin-$backend.cookies"
username="e2e-$backend"
password='PowerdnsE2e1!'
zone="admin-$backend.e2e.test."
record="www.$zone"
address=192.0.2.2

csrf_token() {
    sed -n 's/.*name="_csrf_token" value="\([^"]*\)".*/\1/p' "$1"
}

csrf_page="/tmp/admin-$backend-csrf.html"
curl -fsS -c "$cookie_jar" "$base_url/register" -o "$csrf_page"
csrf=$(csrf_token "$csrf_page")
test -n "$csrf"
curl -fsS \
    -b "$cookie_jar" \
    -c "$cookie_jar" \
    -H "Referer: $base_url/register" \
    --data-urlencode "_csrf_token=$csrf" \
    --data-urlencode "username=$username" \
    --data-urlencode "password=$password" \
    --data-urlencode "rpassword=$password" \
    --data-urlencode 'firstname=E2E' \
    --data-urlencode "lastname=$backend" \
    --data-urlencode "email=$username@example.test" \
    "$base_url/register" \
    -o /dev/null

curl -fsS -b "$cookie_jar" -c "$cookie_jar" "$base_url/login" -o "$csrf_page"
csrf=$(csrf_token "$csrf_page")
test -n "$csrf"
effective_url=$(curl -fsS \
    -L \
    -b "$cookie_jar" \
    -c "$cookie_jar" \
    -H "Referer: $base_url/login" \
    --data-urlencode "_csrf_token=$csrf" \
    --data-urlencode "username=$username" \
    --data-urlencode "password=$password" \
    --data-urlencode 'auth_method=LOCAL' \
    -o /dev/null \
    -w '%{url_effective}' \
    "$base_url/login")
case "$effective_url" in
    "$base_url/dashboard"*) ;;
    *) exit 1 ;;
esac

curl -fsS -b "$cookie_jar" "$base_url/admin/history" -o /dev/null

api_key=$(curl -fsS \
    -u "$username:$password" \
    -H 'Content-Type: application/json' \
    --data '{"role":"Administrator","description":"docker-pdns-e2e"}' \
    "$base_url/api/v1/pdnsadmin/apikeys" \
    | jq -er '.plain_key')

zones_api="$base_url/api/v1/servers/localhost/zones"
curl -fsS \
    -H "X-API-Key: $api_key" \
    -H 'Content-Type: application/json' \
    --data "{\"name\":\"$zone\",\"kind\":\"Native\",\"nameservers\":[]}" \
    "$zones_api" \
    -o /dev/null
curl -fsS \
    -X PATCH \
    -H "X-API-Key: $api_key" \
    -H 'Content-Type: application/json' \
    --data "{\"rrsets\":[{\"name\":\"$record\",\"type\":\"A\",\"ttl\":60,\"changetype\":\"REPLACE\",\"records\":[{\"content\":\"$address\",\"disabled\":false}]}]}" \
    "$zones_api/$zone" \
    -o /dev/null

dig +short +time=2 +tries=1 "@$pdns_container" "$record" A | grep -Fx "$address"
ADMIN_PROBE
    then
        fail "admin-$backend" "Admin $backend functional flow failed"
    fi
}

run_admin_instance() {
    backend=$1
    image=$2
    container="$run_key-admin-$backend"
    admin_host="admin-$backend.test"

    register_container "$container"
    case "$backend" in
        mysql)
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                --network-alias "$admin_host" \
                -e PDNS_ADMIN_SQLA_DB_TYPE=mysql \
                -e PDNS_ADMIN_SQLA_DB_HOST=mysql \
                -e PDNS_ADMIN_SQLA_DB_USER=root \
                -e PDNS_ADMIN_SQLA_DB_PASSWORD=powerdns \
                -e PDNS_ADMIN_SQLA_DB_NAME=powerdns_admin_e2e_mysql \
                -e PDNS_ADMIN_CAPTCHA_ENABLE=False \
                -e 'PDNS_ADMIN_SALT=$2b$12$abcdefghijklmnopqrstuu' \
                -e "PDNS_API_URL=http://$admin_pdns_container:8081/" \
                -e PDNS_API_KEY=powerdns \
                -e PDNS_VERSION=5.0.6 \
                "$image" >/dev/null; then
                fail admin-mysql "could not start Admin MySQL container"
            fi
            ;;
        mysql-legacy)
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                --network-alias "$admin_host" \
                -e PDNS_ADMIN_SQLA_DB_TYPE=mysql \
                -e PDNS_ADMIN_SQLA_DB_HOST=mysql-legacy \
                -e PDNS_ADMIN_SQLA_DB_USER=root \
                -e PDNS_ADMIN_SQLA_DB_PASSWORD=powerdns \
                -e PDNS_ADMIN_SQLA_DB_NAME=powerdns_admin_e2e_mysql_legacy \
                -e MYSQL_CLIENT_EXTRA_PARAMS=--skip-ssl \
                -e PDNS_ADMIN_CAPTCHA_ENABLE=False \
                -e 'PDNS_ADMIN_SALT=$2b$12$abcdefghijklmnopqrstuu' \
                -e "PDNS_API_URL=http://$admin_pdns_container:8081/" \
                -e PDNS_API_KEY=powerdns \
                -e PDNS_VERSION=5.0.6 \
                "$image" >/dev/null; then
                fail admin-mysql-legacy "could not start Admin legacy MySQL container"
            fi
            ;;
        postgresql)
            if ! docker run -d \
                --name "$container" \
                --network "$network" \
                --network-alias "$admin_host" \
                -e PDNS_ADMIN_SQLA_DB_TYPE=postgresql \
                -e PDNS_ADMIN_SQLA_DB_HOST=pgsql \
                -e PDNS_ADMIN_SQLA_DB_PORT=5432 \
                -e PDNS_ADMIN_SQLA_DB_USER=postgres \
                -e PDNS_ADMIN_SQLA_DB_PASSWORD=powerdns \
                -e PDNS_ADMIN_SQLA_DB_NAME=powerdns_admin_e2e_postgresql \
                -e PDNS_ADMIN_CAPTCHA_ENABLE=False \
                -e 'PDNS_ADMIN_SALT=$2b$12$abcdefghijklmnopqrstuu' \
                -e "PDNS_API_URL=http://$admin_pdns_container:8081/" \
                -e PDNS_API_KEY=powerdns \
                -e PDNS_VERSION=5.0.6 \
                "$image" >/dev/null; then
                fail admin-postgresql "could not start Admin PostgreSQL container"
            fi
            ;;
    esac

    wait_for_health "admin-$backend" "$container"
    attempt=1
    while ! docker exec "$probe_container" curl -fsS \
        "http://$admin_host:8080/login" -o /dev/null 2>/dev/null; do
        if [ "$attempt" -ge 180 ]; then
            fail "admin-$backend" "Admin HTTP endpoint did not become ready within 180 seconds"
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    assert_admin_flow "$backend" "$admin_host" "$admin_pdns_container"
}

run_admin_tests() {
    admin_image=$1
    start_admin_pdns
    run_admin_instance mysql "$admin_image"
    run_admin_instance mysql-legacy "$admin_image"
    run_admin_instance postgresql "$admin_image"
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

    if [ "$target" = admin ]; then
        run_admin_tests "$image"
        echo "PASS admin"
        return
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
                -e PDNS_api=yes \
                -e PDNS_api_key=powerdns \
                -e PDNS_webserver=yes \
                -e PDNS_webserver_address=0.0.0.0 \
                -e PDNS_webserver_allow_from=0.0.0.0/0 \
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
                -e PDNS_api=yes \
                -e PDNS_api_key=powerdns \
                -e PDNS_webserver=yes \
                -e PDNS_webserver_address=0.0.0.0 \
                -e PDNS_webserver_allow_from=0.0.0.0/0 \
                "$image" >/dev/null; then
                fail "$target" "could not start target container"
            fi
            ;;
    esac

    wait_for_health "$target" "$container"

    case "$target" in
        recursor-fedora|recursor-alpine)
            assert_dns "$target" "$container"
            assert_recursion "$target" "$container"
            ;;
        mysql-fedora|mysql-alpine|pgsql-fedora|pgsql-alpine)
            assert_dns "$target" "$container"
            assert_authoritative_zone "$target" "$container"
            ;;
    esac

    echo "PASS $target"
}

for target in $targets; do
    run_target "$target"
done
