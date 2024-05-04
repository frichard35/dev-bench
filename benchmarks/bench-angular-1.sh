#!/usr/bin/env bash
source "$BASE_DIR/benchmarks/common-1.sh"

#angular benchmark
readonly benchmark_version='1'
readonly benchmark_id="angular-$benchmark_version"
readonly benchmark_dir='petclinic-angular'

prepare_benchmark() {
    _checkout_petclinic_angular '43e4756f28244220724c57f325e1ce3f47f7c7bc' "$benchmark_dir"
}

pre_run_benchmark(){
    export NG_CLI_ANALYTICS="false"
    rm -rf dist/
}

run_benchmark(){
    npm run build
}

collect_metrics_benchmark(){
    node_metrics
}