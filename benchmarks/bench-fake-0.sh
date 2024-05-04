#!/usr/bin/env bash

#fake benchmark
readonly benchmark_version='0'
readonly benchmark_id="fake-$benchmark_version"
readonly benchmark_dir='fake-benchmark'

prepare_benchmark() {
    mkdir -p "$WRK_PATH/$benchmark_dir"
    echo "prepare_benchmark fake"
    echo "$db_context" > "$WRK_PATH/$benchmark_dir/.db.ok"
}

pre_run_benchmark() {
    echo "pre_run_benchmark fake"
}

run_benchmark(){
    echo "run_benchmark fake"
    sleep 1
}

collect_metrics_benchmark(){
    maven_metrics
    node_metrics
}