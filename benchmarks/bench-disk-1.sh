#!/usr/bin/env bash
# BENCHMARK: Read and write files to a tar archive (without compression)
#
# IMPORTANT: To edit this file bump the version and save as a new file benchmark/bench-disk-<version>.sh
#
readonly benchmark_version='1'
readonly benchmark_id="disk-$benchmark_version"
readonly benchmark_dir='disk-benchmark'

prepare_benchmark() {
    echo "prepare_benchmark disk"
    rm -rf "$WRK_PATH/$benchmark_dir"
    mkdir -p "$WRK_PATH/$benchmark_dir/from/bigfiles"
    mkdir -p "$WRK_PATH/$benchmark_dir/from/smallfiles"
    pushd "$WRK_PATH/$benchmark_dir" >/dev/null
    echo "prepare_benchmark disk - create 1G.bin ..."
    head -c 1073741824 </dev/urandom > "from/bigfiles/1G.bin"
    echo "prepare_benchmark disk - create 512M.bin 256M.bin and 128M.bin ..."
    head -c 536870912 </dev/urandom > "from/bigfiles/512M.bin"
    head -c 268435456 </dev/urandom > "from/bigfiles/256M.bin"
    head -c 134217728 </dev/urandom > "from/bigfiles/128M.bin"
    echo "prepare_benchmark disk - create 4K files ..."
    local i
    for i in {1..10}; do
        _create_small_files '4k' 4096 $(( (i-1)*1000+1 )) $(( i*1000 )) &
    done
    wait

    echo "prepare_benchmark disk - create 1K files ..."
    for i in {1..10}; do
        _create_small_files '1k' 1024 $(( (i-1)*1000+1 )) $(( i*1000 )) &
    done
    wait
    popd >/dev/null
    echo "$db_context" > "$WRK_PATH/$benchmark_dir/.db.ok"
}

_create_small_files() {
    local name=$1
    local size=$2
    local first=$3
    local last=$4
    local i
    for ((i=first;i<=last;i++)); do
        head -c $size </dev/urandom > "from/smallfiles/$name-$i.bin"
    done
}

pre_run_benchmark() {
    echo "pre_run_benchmark disk"
    rm -rf to/ temp.tar
}

run_benchmark(){
    echo "run_benchmark disk"
    # read files
    sh -c 'tar -C from/ -cf temp.tar bigfiles smallfiles'
    mkdir to
    # write files
    sh -c 'tar -C to/ -xf temp.tar'
}

post_run_benchmark(){
    echo "post_run_benchmark disk - compare files, must be identical"
    diff -rq "$WRK_PATH/$benchmark_dir/from" "$WRK_PATH/$benchmark_dir/to"
    echo "post_run_benchmark disk - cleanup"
    rm -rf "$WRK_PATH/$benchmark_dir/to" "$WRK_PATH/$benchmark_dir/temp.tar"
}

collect_metrics_benchmark(){
    add_metric tar_version "$(tar --version | head -n 1)"
}