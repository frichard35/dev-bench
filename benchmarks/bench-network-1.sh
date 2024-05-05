#!/usr/bin/env bash
source "$BASE_DIR/benchmarks/common-1.sh"

#network benchmark
readonly benchmark_version='1'
readonly benchmark_id="network-$benchmark_version"
readonly benchmark_dir='petclinic-rest'

prepare_benchmark() {
    _checkout_petclinic_rest '4085009ee2c70ad54b8c94b96b0a01c146b8d11e' "$benchmark_dir"
}

pre_run_benchmark() {
    rm -rf target repo
}

run_benchmark(){
    mvn -Dmaven.repo.local="$WRK_PATH/$benchmark_dir/repo" validate
}

collect_metrics_benchmark(){
    maven_metrics
}