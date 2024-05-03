#!/usr/bin/env bash

#declaration benchmarks
benchmarks+=("angular")

#angular benchmark
readonly angular_version='1.0'
readonly angular_commit='43e4756f28244220724c57f325e1ce3f47f7c7bc'
readonly angular_dir='petclinic-angular'
readonly angular_prepare='prepare_petclinic_angular'
readonly angular_metrics='node_metrics'


prepare_petclinic_angular() {
    pushd "$WRK_PATH"  >/dev/null
    rm -rf "$angular_dir"
    rm -rf "spring-petclinic-angular-$angular_commit"
    echo "[DEV BENCH] download petclinic-angular project"
    curl -sSL $GITHUB_CURL_AUTHENT $GITHUB_CURL_PROXY \
         "$GITHUB_URL/spring-petclinic/spring-petclinic-angular/archive/${angular_commit}.tar.gz" | \
        tar xvzf -
    sleep 2
    mv "spring-petclinic-angular-$angular_commit" "$angular_dir"
    pushd "$angular_dir" >/dev/null
    [[ $(type -t npm_settings) == function ]] && npm_settings

    echo "[DEV BENCH] petclinic-angular installation"
    npm ci

    echo "[DEV BENCH] petclinic-angular pre-build"
    export NG_CLI_ANALYTICS="false"
    npm run build

    echo "$db_context" > .db.ok
    popd >/dev/null;popd >/dev/null
}

pre_run_angular(){
    export NG_CLI_ANALYTICS="false"
    rm -rf dist/
}

run_angular(){
    npm run build
}