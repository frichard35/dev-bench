#!/usr/bin/env bash


#declaration benchmarks
benchmarks+=("spring" "network")

#spring benchmark
readonly spring_version='1.0'
readonly spring_commit='4085009ee2c70ad54b8c94b96b0a01c146b8d11e'
readonly spring_dir='petclinic-rest'
readonly spring_prepare='prepare_petclinic_rest'
readonly spring_metrics='maven_metrics'

#network benchmark
readonly network_version='1.0'
readonly network_dir="$spring_dir"
readonly network_prepare="$spring_prepare"
readonly network_metrics='maven_metrics'

prepare_petclinic_rest() {
    pushd "$WRK_PATH"  >/dev/null
    rm -rf "$spring_dir"
    rm -rf "spring-petclinic-rest-$spring_commit"

    echo "[DEV BENCH] download petclinic-rest project"
    curl -sSL $GITHUB_CURL_AUTHENT $GITHUB_CURL_PROXY \
        "$GITHUB_URL/spring-petclinic/spring-petclinic-rest/archive/${spring_commit}.tar.gz" | \
        tar xvzf -
    sleep 2
    mv "spring-petclinic-rest-$spring_commit" "$spring_dir"
    pushd "$spring_dir" >/dev/null
    [[ $(type -t maven_settings) == function ]] && maven_settings
    mvn package
    echo "$db_context" > .db.ok
    popd >/dev/null;popd >/dev/null
}

pre_run_spring(){
    rm -rf target
}
run_spring(){
    mvn -o package
}

pre_run_network() {
    rm -rf target repo
}
run_network(){
    mvn -Dmaven.repo.local="$WRK_PATH/$network_dir/repo" validate
}