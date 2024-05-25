#!/usr/bin/env bash
# BENCHMARK: Build a spring boot application (petclinic-rest) using maven
#
# IMPORTANT: To edit this file bump the version and save as a new file benchmark/bench-spring-<version>.sh
#
source "$BASE_DIR/benchmarks/common-1.sh"

readonly benchmark_version='1'
readonly benchmark_id="spring-$benchmark_version"
readonly benchmark_dir='petclinic-rest'

prepare_benchmark() {
    _checkout_petclinic_rest '4085009ee2c70ad54b8c94b96b0a01c146b8d11e' "$benchmark_dir"
}

pre_run_benchmark(){
    rm -rf target
}
run_benchmark(){
    mvn -o package
}

collect_metrics_benchmark(){
    maven_metrics
}