#!/usr/bin/env bash
set -e

BASE_DIR="$(dirname "$(readlink -f "$0")")"

#load benchmarks
benchmarks=()
for bench in "$BASE_DIR/benchmarks/bench-"*".sh"; do
    bench="${bench##*/}"
    bench="${bench#bench-}"
    benchmarks+=( "${bench%.sh}" )
done

#load available contexts
available_contexts=()
db_context="internet"
for context in "$BASE_DIR/contexts/"*".sh"; do
    context="${context##*/}"
    available_contexts+=( "${context%.sh}" )
done

#################
# Global Config #
#################
GITHUB_URL="${GITHUB_URL:-"https://github.com"}"
WRK_PATH="${WRK_PATH:-"$BASE_DIR/wrk"}"
if [[ "$(uname -a)" == CYGWIN* ]] || [[ "$(uname -a)"  == MINGW64* ]]; then
    WRK_PATH="$(cygpath -m "$WRK_PATH")"
fi

main() {

    if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit
    
    elif [ "$1" = "publish" ]; then
        shift
        main_publish "$@"
    
    else
        select_benchmark "$1"
        shift
        main_benchmark "$@"
    fi
}

select_benchmark() {
    local query="$1"
    local result="$(ls "$BASE_DIR/benchmarks/bench-$query"*".sh" 2>/dev/null || true)"
    if [ -z "$result" ]; then
        echo "No benchmark found for '$query'."
        exit 1
    fi
    if [ "$(echo "$result" | wc -l)" -gt 1 ]; then
        echo "Multiple benchmarks found for '$query':"
        echo "$result"
        exit 1
    fi
    source "$result"
}

main_benchmark() {
    
    prerequisites

    echo "[DEV BENCH] $benchmark_id benchmark selected."

    local iterations=1
    local wait=0
    local prepare=0

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -i|--iterations) iterations="$2"; shift ;;
            -w|--wait) wait="$2"; shift ;;
            -p|--prepare) prepare=1 ;;
            -c|--context) db_context="$2"; shift ;;
            -h|--help) usage; exit 1 ;;
            *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
        esac
        shift
    done

    [ -z "$db_context" ] && echo "[DEV BENCH ERROR] You need to specify a context." && exit 1

    load_context "$db_context"
    if [[ $(type -t init_context) == function ]]; then
        echo -e "\n[DEV BENCH] Context '$db_context' initialisation..."
        init_context
        echo "[DEV BENCH] Context '$db_context' initialisation done"
    fi

    local i
    for ((i=1;i<=iterations;i++)); do
        bench "$prepare"
        if (( i < iterations )) && (( wait > 0 )); then
            echo -e "\n[DEV BENCH] wait for $wait seconds. [$i/$iterations] done."
            sleep $wait
        fi
    done
}

prerequisites() {
    if ! type numfmt >/dev/null 2>&1; then
        echo "[DEV BENCH ERROR] dev-bench requires numfmt"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "[DEV BENCH ERROR] can be install with 'brew install coreutils'"
        fi
        exit 1
    fi
}

main_publish(){
    
    local results_file='results.log'
    local extra_params=()

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c|--context) db_context="$2"; shift ;;
            -f|--file) results_file="$2"; shift ;;
            --contributor) contributor="$2"; shift ;;
            --run-env) contributor_run_env="$2"; shift ;;
            -h|--help) usage; exit 1 ;;
            *) extra_params+=("$1") ;;
        esac
        shift
    done

    [ -z "$db_context" ] && echo "[DEV BENCH ERROR] You need to specify a context with a publish function." && exit 1
    load_context "$db_context"

    if [[ $(type -t publish) == function ]]; then
        publish "$results_file" "$contributor" "$contributor_run_env" "${extra_params[@]}"
    else
        echo "[DEV BENCH ERROR] You need to specify a context with a publish function."
        exit 1
    fi
}

load_context() {
    local db_context="$1"
    [ ! -f "contexts/$db_context.sh" ] && echo "[DEV BENCH ERROR] Context '$db_context' does not exist." && exit 1
    echo "[DEV BENCH] Load context '$db_context'"
    source "$BASE_DIR/contexts/$db_context.sh"
}

usage() {
    echo -e "DEV BENCH: Developer environment benchmark."
    echo -e "\n[Usage benchmark] run a benchmark"
    echo -e "  $0 [benchmark_prefix] [options]"
    echo -e "    -p, --prepare                 force benchmark preparation"
    echo -e "    -i, --iterations <number>     number of iterations"
    echo -e "    -w, --wait <seconds>          wait between iterations"
    echo -e "    -c, --context <context>       load a dev context\n"
    echo -e "   Available benchmarks: ${benchmarks[*]}"
    echo -e "   Available contexts: ${available_contexts[*]}\n\n"


    echo -e "[Usage publish results] publish benchmark from results.log"
    echo -e "  $0 publish [options]"
    echo -e "    -c, --context <context>       load a dev context"
    echo -e "    --file <file>                 publish <file> default results.log"
    echo -e "    --contributor <info>          (optional) Any information about the contributor"
    echo -e "    --run-env <info>              (optional) Any information about the run environment\n"
    # iterate over available contexts to display their specific help
    local contexts_with_publish=""
    for context in "${available_contexts[@]}"; do
        if grep -q "publish()" "$BASE_DIR/contexts/$context.sh"; then
            contexts_with_publish+=" $context"
        fi
    done
    if [ -n "$contexts_with_publish" ]; then 
        echo -e "   Available contexts to publish:$contexts_with_publish\n"
    else
        echo -e "   Available contexts to publish: none\n"
    fi
}

bench() {
    local option_prepare="$1"

    local wrk_build_with_context="$(cat "$WRK_PATH/$benchmark_dir/.db.ok" 2>/dev/null)"
    if [ ! -f "$WRK_PATH/$benchmark_dir/.db.ok" ] || [ "$wrk_build_with_context" != "$db_context" ] || [ "$option_prepare" = "1" ]; then
        mkdir -p "$WRK_PATH"
        echo -e "\n[DEV BENCH] $benchmark_id benchmark preparation in $benchmark_dir"
        prepare_benchmark
        echo "[DEV BENCH] $benchmark_id benchmark preparation done"
    fi

    pushd "$WRK_PATH/$benchmark_dir" >/dev/null
    if [[ $(type -t pre_run_benchmark) == function ]]; then
        echo -e "\n[DEV BENCH] $benchmark_id benchmark pre-run"
        pre_run_benchmark
        echo "[DEV BENCH] $benchmark_id benchmark pre-run done"
    fi

    echo -e "\n[DEV BENCH] $benchmark_id benchmark starting..."
    { time run_benchmark; } 2>&1 | tee bench.log
    local exit_code="${PIPESTATUS[0]}"
    if [ "$exit_code" != "0" ]; then
        echo -e "\n[DEV BENCH ERROR]: $benchmark_id exit with code $exit_code.\n"
        exit $exit_code
    fi

    local result="$(tail -3 "$WRK_PATH/$benchmark_dir/bench.log" | head -1 | sed 's/,/./' | awk '{print $NF}')"
    local result_seconds="$(echo "$result" | LC_NUMERIC=en_US.UTF-8 awk --use-lc-numeric -F'[ms]' '{print 60*$1+$2}' 2>/dev/null)"
    echo -e "\n[DEV BENCH] $benchmark_id benchmark terminated in $result_seconds seconds."

    if [[ $(type -t post_run_benchmark) == function ]]; then
        echo -e "\n[DEV BENCH] $benchmark_id benchmark post-run"
        post_run_benchmark
        echo "[DEV BENCH] $benchmark_id benchmark post-run done"
    fi
    popd >/dev/null

    echo -e "\n[DEV BENCH] collect metrics about this run"
    metrics_logging "$result_seconds"
}

metrics_logging() {
    local result_seconds="$1"

    #default metrics
    metrics_line=''
    local fake_ms="$(($RANDOM%(1000)+1000))"; fake_ms="${fake_ms: -3}"
    add_metric datetime "$(date -u +"%Y-%m-%dT%H:%M:%S.${fake_ms}Z")"
    add_metric benchmark "$benchmark_id"
    add_metric result "$result_seconds"

    #os metrics
    os_metrics

    #specific benchmark metrics
    collect_metrics_benchmark

    #context metrics
    context_metrics

    echo -e "\n[DEV BENCH] result line in results.log"
    echo "{$metrics_line}" | tee -a results.log
}

add_metric() {
    [ -n "$metrics_line" ] && metrics_line+=','
    metrics_line+="\"$1\":\"$2\""
}

os_metrics(){

    add_metric os "$OSTYPE"
    add_metric arch "$(arch)"

    local battery='false'
    local container='false'
    local virtual_machine='false'

    #trying to detect if running in container
    if [[ "$(uname -a)" == CYGWIN* ]] || [[ "$(uname -a)"  == MINGW64* ]]; then
        local mem_kb="$(cat /proc/meminfo | grep 'MemTotal:' | awk '{print $2}')"
        add_metric memory "$(echo $((mem_kb * 1024)) | numfmt --to=iec-i)"
        add_metric cpu "$(cat /proc/cpuinfo | grep "model name" | head -1 | awk '{print $NF}')"
        add_metric cpu_count "$(cat /proc/cpuinfo | grep "model name" | wc -l )"
        local battery_status="$(wmic Path Win32_Battery Get BatteryStatus | tail -2 | head -1 | tr -d "[:space:]")"
        [ "$battery_status" = "1" ] && battery=true

        local computer_model="$(wmic csproduct get name | tail -2 | head -1 | xargs)"
        add_metric 'computer_model' "$computer_model"
        if [[ "${computer_model,,}" = *vmware* ]] || [[ "${computer_model,,}" = *virt* ]] || [[ "${computer_model,,}" = *hyper* ]] || [[ "${computer_model,,}" = *hvm* ]]; then
            virtual_machine='true'
        fi

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        add_metric memory "$(sysctl -n hw.memsize | numfmt --to=iec-i)"
        add_metric cpu "$(sysctl -n machdep.cpu.brand_string | tr -d "[:space:]")"
        add_metric cpu_count "$(sysctl -n hw.perflevel0.physicalcpu)+$(sysctl -n hw.perflevel1.physicalcpu)"
        add_metric 'computer_model' "$(system_profiler -detailLevel mini SPHardwareDataType | grep "Model Identifier:" | awk '{print $NF}')"
        if [[ ! $(pmset -g ps | head -1) =~ "AC Power" ]]; then
            battery='true'
        fi
    
    elif [[ "$OSTYPE" == "linux"* ]]; then
        local mem_kb="$(cat /proc/meminfo | grep 'MemTotal:' | awk '{print $2}')"
        add_metric memory "$(echo $((mem_kb * 1024)) | numfmt --to=iec-i)"
        local cpu="$(cat /proc/cpuinfo | grep "model name" | head -1 | awk -F':' '{print $2}' | tr -d "[:space:]")"
        if [ -n "$cpu" ]; then
            add_metric cpu "$cpu"
            add_metric cpu_count "$(cat /proc/cpuinfo | grep "model name" | wc -l )"
        else
            add_metric cpu "$(lscpu | grep -i "model name"  | awk -F':' '{print $NF}' | xargs)"
            add_metric cpu_count "$(lscpu | grep "^CPU"  | awk -F':' '{print $NF}' | xargs)"
        fi

        dmesg 2>/dev/null| grep -iq 'hypervisor' && virtual_machine="true"

        local computer_model="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
        [ -n "$computer_model" ] && add_metric 'computer_model' "$computer_model"

        local p1_cgroup_content="$(cat /proc/1/cgroup | grep '^1:')"
        if [ -z "$p1_cgroup_content" ] || [[ "$p1_cgroup_content" == *"/cri-containerd-"* ]] || [[ "$p1_cgroup_content" == *"/docker"* ]] || 
            [[ "$p1_cgroup_content" == *"/crio-"* ]] || [[ "$p1_cgroup_content" == *"/lxc"* ]]; then
            container="true"
            virtual_machine='false'
	    
            if [ -f /sys/fs/cgroup/memory.max ]; then
                add_metric memory_limit "$(cat /sys/fs/cgroup/memory.max | numfmt --to=iec-i)"
            elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
                add_metric memory_limit "$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes | numfmt --to=iec-i)"
            else
                add_metric memory_limit 'unknown'
            fi

            if [ -f /sys/fs/cgroup/cpu.max ]; then
                add_metric cpu_limit "$(cat /sys/fs/cgroup/cpu.max | awk '{print $1 / $2}')"
            elif [ -f /sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us ] && [ -f /sys/fs/cgroup/cpu,cpuacct/cpu.cfs_period_us ]; then
                local cpu_quota=$(cat /sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us)
                local cpu_period=$(cat /sys/fs/cgroup/cpu,cpuacct/cpu.cfs_period_us)
                add_metric cpu_limit "$(($cpu_quota / $cpu_period))"
            else
                add_metric cpu_limit 'unknown'
            fi
        fi
    fi

    add_metric battery "$battery"
    add_metric container "$container"
    add_metric virtual_machine "$virtual_machine"
}

node_metrics(){
    add_metric node_version "$(node -v | tr -dc '[[:print:]]')"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        add_metric node_arch "$(file "$(which node)" | awk '{print $NF}')"
    fi
    add_metric npm_version "$(npm -v | tr -dc '[[:print:]]')"
}

maven_metrics() {
    local java_version="$(java -XshowSettings:all -version 2>&1 | grep "java.runtime.version" | tr -dc '[[:print:]]' | awk '{print $NF}')"
    local java_vendor="$(java -XshowSettings:all -version 2>&1 | grep "java.vendor " | tr -dc '[[:print:]]' | awk -F'=' '{print $NF}' | xargs)"
    #below sed to remove bold in old maven version
    local maven_version="$(mvn -v -B 2>/dev/null | head -1 | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" |  awk '{print $3}')"
    add_metric java_version "$java_version"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        add_metric java_arch "$(file "$(which java)" | awk '{print $NF}')"
    fi
    add_metric java_vendor "$java_vendor"
    add_metric maven_version "$maven_version"
}

main "$@"
