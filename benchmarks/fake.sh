#!/usr/bin/env bash

#declaration benchmarks
benchmarks+=("fake")

#fake benchmark
readonly fake_version='0'
readonly fake_dir='fake-benchmark'
readonly fake_prepare='prepare_fake'
readonly fake_metrics='fake_full_metrics'

prepare_fake() {
    mkdir -p "$WRK_PATH/fake-benchmark"
    echo "$db_context" > "$WRK_PATH/fake-benchmark/.db.ok"
}

pre_run_fake() {
    echo "pre_run_fake"
}

run_fake(){
    echo "run_fake"
    sleep 1
}


fake_full_metrics(){
    maven_metrics
    node_metrics
}