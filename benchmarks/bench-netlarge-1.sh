#!/usr/bin/env bash
# BENCHMARK: Download a large docker layer
#
# IMPORTANT: To edit this file bump the version and save as a new file benchmark/bench-network-<version>.sh
#
readonly benchmark_version='1'
readonly benchmark_id="netlarge-$benchmark_version"
readonly benchmark_dir='netlarge-benchmark'
#readonly docker_image='gitlab/gitlab-ce'
#readonly docker_layer='6b675dfa88f267870120d0c55697abed93fd71ddcfc9e6357f69d3042fd41d3b'
readonly docker_image='library/sonarqube'
readonly docker_tag='lts-developer'
readonly docker_layer='9d907b8c2ec8f9704f24a2b1d0d75615eb1ae24e23d73876c0999336a2e94bea'
readonly docker_user_agent='docker/25.0.3 go/go1.21.6 git-commit/f417435 kernel/6.6.16-linuxkit os/linux arch/arm64 UpstreamClient(Docker-Client/25.0.3 \(darwin\))'

prepare_benchmark() {
    echo "prepare_benchmark netlarge"
    rm -rf "${WRK_PATH:?}/$benchmark_dir"
    mkdir -p "${WRK_PATH:?}/$benchmark_dir"
    echo "$db_context" > "$WRK_PATH/$benchmark_dir/.db.ok"
}

pre_run_benchmark() {
    
    # Enable or not the proxy
    if [ -n "$DB_PROXY_HOST" ] && [ -n "$DB_PROXY_PORT" ]; then
        proxy_config=( '--proxy' "http://$DB_PROXY_HOST:$DB_PROXY_PORT" '--noproxy' 'localhost' )
    else
        proxy_config=( '--noproxy' '*' )
    fi

    # Test current token if any
    local login_response; login_response="$(_docker_curl -o /dev/null -LI -w "%{http_code}@%header{www-authenticate}" \
                                             "$DOCKER_REGISTRY/v2/$docker_image/manifests/$docker_tag" || true)"
    local login_status; login_status=$(echo "$login_response" | cut -d@ -f1)
    local login_www_authenticate; login_www_authenticate=$(echo "$login_response" | cut -d@ -f2)
    if [ "$login_status" -eq 401 ] || [ "$login_status" -eq 403 ]; then
        _docker_login "$login_www_authenticate"
    elif [ "$login_status" -ne 200 ]; then
        echo "Error: Docker registry is not available status: $login_status"
        exit 1
    else
        echo "pre_run_benchmark netlarge - docker token already valid"
    fi

    #test if layer available
    local test_layer; test_layer="$(_docker_curl -m 5 -LI -o /dev/null  -w "%{http_code}" "$DOCKER_REGISTRY/v2/$docker_image/blobs/sha256:$docker_layer" || true)"
    if [ "$test_layer" -ne 200 ]; then
        echo "Error: Docker registry layer is not available, maybe a cache issue, retry later..."
        exit 1
    fi
    echo "pre_run_benchmark netlarge - layer available on registry"
}

run_benchmark(){
    _docker_curl -L -o layer1GB.gz "$DOCKER_REGISTRY/v2/$docker_image/blobs/sha256:$docker_layer"
}

post_run_benchmark(){
    local sum="$(sha256sum layer1GB.gz | cut -d' ' -f1)"
    if [ "$sum" != "$docker_layer" ]; then
        echo "Error: sha256sum mismatch"
        exit 1
    fi
    rm -f layer1GB.gz
}

collect_metrics_benchmark(){
    if [ -n "$DB_PROXY_HOST" ] && [ -n "$DB_PROXY_PORT" ]; then
        add_metric proxy "$DB_PROXY_HOST:$DB_PROXY_PORT"
    else
        add_metric proxy "no"
    fi
}

_docker_login(){   
    local login_info="$1"
    echo "pre_run_benchmark netlarge - login to docker registry"
    local method; method="$(echo "$login_info" | awk '{print toupper($1)}')"
    local realm; realm="$(echo "$login_info" | sed -nr 's/.*realm="([^"]*)".*/\1/p')"
    local service; service="$(echo "$login_info" | sed -nr 's/.*service="([^"]*)".*/\1/p')"
    local scope="repository:$docker_image:pull"
    echo "pre_run_benchmark netlarge - method: $method"
    echo "pre_run_benchmark netlarge - realm: $realm"
    echo "pre_run_benchmark netlarge - service: $service"
    echo "pre_run_benchmark netlarge - scope: $scope"

    if [ "$DOCKER_REGISTRY_AUTH" = "basic" ] || [ "$method" = "BASIC" ]; then
        echo "pre_run_benchmark netlarge - basic authentication selected"
        echo 'basic' > .docker-token
        return
    fi

    if [ -n "$DOCKER_REGISTRY_LOGIN" ] && [ -n "$DOCKER_REGISTRY_PASSWORD" ]; then
        local docker_creds=("-u" "$DOCKER_REGISTRY_LOGIN:$DOCKER_REGISTRY_PASSWORD")
    fi

    _docker_curl_no_auth "${docker_creds[@]}" \
    --get --data-urlencode "service=$service" --data-urlencode "scope=$scope" "$realm" \
    | jq -r '.token' > .docker-token
}

#curl wrapper without auth
_docker_curl_no_auth() {
    curl -sS "${proxy_config[@]}" \
        -H "User-Agent: $docker_user_agent" -H 'Accept-Encoding: gzip' -H 'Accept:' "$@"
}

#curl wrapper
_docker_curl() {
    if [ -f .docker-token ]; then
        local token; token="$(cat .docker-token)"
        if [ "$token" = "basic" ]; then
            _docker_curl_no_auth -u "$DOCKER_REGISTRY_LOGIN:$DOCKER_REGISTRY_PASSWORD" "$@"
            return
        elif [ -n "$token" ]; then
            _docker_curl_no_auth -H "Authorization: Bearer $token" "$@"
            return
        fi
    fi
    _docker_curl_no_auth "$@"
}