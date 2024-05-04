#!/usr/bin/env bash

_checkout_petclinic_rest() {
    local commit="$1"
    local chk_dir="$2"

    pushd "$WRK_PATH"  >/dev/null
    rm -rf "$chk_dir"
    rm -rf "spring-petclinic-rest-$commit"

    echo "[DEV BENCH] download petclinic-rest project"
    curl -sSL $GITHUB_CURL_AUTHENT $GITHUB_CURL_PROXY \
        "$GITHUB_URL/spring-petclinic/spring-petclinic-rest/archive/${commit}.tar.gz" | \
        tar xvzf -
    sleep 2
    mv "spring-petclinic-rest-$commit" "$chk_dir"
    pushd "$chk_dir" >/dev/null
    [[ $(type -t maven_settings) == function ]] && maven_settings
    mvn package
    echo "$db_context" > .db.ok
    popd >/dev/null;popd >/dev/null
}

_checkout_petclinic_angular() {
    local commit="$1"
    local chk_dir="$2"

    pushd "$WRK_PATH"  >/dev/null
    rm -rf "$chk_dir"
    rm -rf "spring-petclinic-angular-$commit"
    echo "[DEV BENCH] download petclinic-angular project"
    curl -sSL $GITHUB_CURL_AUTHENT $GITHUB_CURL_PROXY \
         "$GITHUB_URL/spring-petclinic/spring-petclinic-angular/archive/${commit}.tar.gz" | \
        tar xvzf -
    sleep 2
    mv "spring-petclinic-angular-$commit" "$chk_dir"
    pushd "$chk_dir" >/dev/null
    [[ $(type -t npm_settings) == function ]] && npm_settings

    echo "[DEV BENCH] petclinic-angular installation"
    npm ci

    echo "[DEV BENCH] petclinic-angular pre-build"
    export NG_CLI_ANALYTICS="false"
    npm run build

    echo "$db_context" > .db.ok
    popd >/dev/null;popd >/dev/null
}