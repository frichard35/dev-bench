#!/usr/bin/env bash
set -e

#load benchmarks
benchmarks=()
for bench in "benchmarks/"*".sh"; do
    source "$bench"
done

#load available contexts
available_contexts=()
db_context="internet"
for context in "contexts/"*".sh"; do
    context="${context##*/}"
    available_contexts+=( "${context%.sh}" )
done

#################
# Global Config #
#################
GITHUB_URL="${GITHUB_URL:-"https://github.com"}"
WRK_PATH="${WRK_PATH:-"$PWD/wrk"}"
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
    
    elif [[ " ${benchmarks[*]} " =~ " $1 " ]]; then
        main_benchmark "$@"

    else
        echo "Unknown parameter passed: $1"
        usage
        exit 1
    fi

    
}

main_benchmark() {

    prerequisites

    local benchmark="$1"
    echo "[DEV BENCH] $benchmark benchmark selected."
    shift
    
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

    for ((i=1;i<=iterations;i++)); do
        bench "$benchmark" "$prepare"
        if (( i < iterations )) && (( wait > 0 )); then
            echo "[DEV BENCH] wait for $wait seconds. [$i/$iterations] done."
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
    
    local results_file="results.log"

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c|--context) db_context="$2"; shift ;;
            -f|--file) results_file="$2" ;;
            -h|--help) usage; exit 1 ;;
            *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
        esac
        shift
    done

    [ -z "$db_context" ] && echo "[DEV BENCH ERROR] You need to specify a context with a publish function." && exit 1
    load_context "$db_context"

    if [[ $(type -t publish) == function ]]; then
        publish "$results_file"
    else
        echo "[DEV BENCH ERROR] You need to specify a context with a publish function."
        exit 1
    fi
}

load_context() {
    local db_context="$1"
    [ ! -f "contexts/$db_context.sh" ] && echo "[DEV BENCH ERROR] Context '$db_context' does not exist." && exit 1
    echo "[DEV BENCH] Load context '$db_context'"
    source "contexts/$db_context.sh"
}

usage() {
    echo -e "DEV BENCH: Developer environment benchmark."
    echo -e "\n[Usage benchmark] run a benchmark"
    echo -e "  $0 [benchmark]"
    echo -e "    -p, --prepare                 force benchmark preparation"
    echo -e "    -i, --iterations <number>     number of iterations"
    echo -e "    -w, --wait <seconds>          wait between iterations"
    echo -e "    -c, --context <context>       load a dev context\n"
    echo -e "   Available benchmarks: ${benchmarks[*]}"
    echo -e "   Available contexts: ${available_contexts[*]}\n\n"


    echo -e "[Usage publish results] publish benchmark in results.log"
    echo -e "  $0 publish"
    echo -e "    -c, --context <context>       load a dev context"
    echo -e "    --file <file>                 publish <file>\n"
    echo -e "   Available contexts: ${available_contexts[*]}\n"
}

bench() {
    local benchmark="$1"
    local option_prepare="$2"

    local version_var="${benchmark}_version"
    local benchmark_id="$benchmark-${!version_var}"

    local run_function="run_${benchmark}"
    local pre_run_function="pre_run_${benchmark}"

    local prepare_func_var="${benchmark}_prepare"
    local prepare_function="${!prepare_func_var}"

    local dir_var="${benchmark}_dir"
    local dir="${!dir_var}"

    local wrk_build_with_context="$(cat "$WRK_PATH/$dir/.db.ok" 2>/dev/null)"
    if [ ! -f "$WRK_PATH/$dir/.db.ok" ] || [ "$wrk_build_with_context" != "$db_context" ] || [ "$option_prepare" = "1" ]; then
        mkdir -p "$WRK_PATH"
        echo -e "\n[DEV BENCH] $benchmark_id benchmark preparation in $dir"
        "${prepare_function}"
        echo "[DEV BENCH] $benchmark_id benchmark preparation done"
    fi

    pushd "$WRK_PATH/$dir" >/dev/null
    if [[ $(type -t $pre_run_function) == function ]]; then
        echo -e "\n[DEV BENCH] $benchmark_id benchmark pre-run"
        $pre_run_function
        echo "[DEV BENCH] $benchmark_id benchmark pre-run done"
    fi

    echo -e "\n[DEV BENCH] $benchmark_id benchmark starting..."
    { time $run_function; } 2>&1 | tee bench.log
    local exit_code="${PIPESTATUS[0]}"
    popd >/dev/null
    if [ "$exit_code" != "0" ]; then
        echo -e "\n[DEV BENCH ERROR]: $benchmark_id exit with code $exit_code.\n"
        exit $exit_code
    fi

    local result="$(tail -3 "$WRK_PATH/$dir/bench.log" | head -1 | sed 's/,/./' | awk '{print $NF}')"
    local result_seconds="$(echo "$result" | LC_NUMERIC=en_US.UTF-8 awk --use-lc-numeric -F'[ms]' '{print 60*$1+$2}' 2>/dev/null)"
    echo -e "\n[DEV BENCH] $benchmark_id benchmark terminated in $result_seconds seconds."
    

    echo -e "\n[DEV BENCH] collect metrics about this run"
    metrics_logging "${benchmark}" "$benchmark_id" "$result_seconds"
}

metrics_logging() {
    local benchmark="$1"
    local benchmark_id="$2"
    local result_seconds="$3"

    #default metrics
    metrics_line=''
    local fake_ms="$(($RANDOM%(1000)+1000))"; fake_ms="${fake_ms: -3}"
    add_metric datetime "$(date -u +"%Y-%m-%dT%H:%M:%S.${fake_ms}Z")"
    add_metric benchmark "$benchmark_id"
    add_metric result "$result_seconds"

    #os metrics
    os_metrics

    #specific benchmark metrics
    local metrics_func_var="${benchmark}_metrics"
    local metrics_func="${!metrics_func_var}"
    if [ -n "$metrics_func" ] && [[ $(type -t "$metrics_func") == function ]]; then
        "$metrics_func"
    fi

    #context metrics
    metrics_func="${db_context}_metrics"
    if [ -n "$metrics_func" ] && [[ $(type -t "$metrics_func") == function ]]; then
        "$metrics_func"
    fi

    echo -e "\n[DEV BENCH] result line in results.log"
    echo "{$metrics_line}" | tee -a results.log
}

add_metric() {
    [ -n "$metrics_line" ] && metrics_line+=','
    metrics_line+="\"$1\":\"$2\""
}

os_metrics(){

    local battery=false
    if [[ $(cat /proc/1/sched 2>/dev/null | head -n 1 | grep init) ]]; then
        local container="true"
        local memory="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes | numfmt --to=iec-i)"
        local cpu="$(cat /proc/cpuinfo | grep "model name" | head -1 | awk '{print $NF}' | tr -d '()')"
        cpu+="($(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $NF}')MHz)"
        local cpu_quota=$(cat /sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us)
        local cpu_period=$(cat /sys/fs/cgroup/cpu,cpuacct/cpu.cfs_period_us)
        local cpu_count="$(($cpu_quota / $cpu_period))"
    else
        local container="false"
        if [[ "$(uname -a)" == CYGWIN* ]] || [[ "$(uname -a)"  == MINGW64* ]]; then
            local mem_kb="$(cat /proc/meminfo | grep 'MemTotal:' | awk '{print $2}')"
            local memory="$(echo $((mem_kb * 1024)) | numfmt --to=iec-i)"
            local cpu="$(cat /proc/cpuinfo | grep "model name" | head -1 | awk '{print $NF}')"
            local cpu_count="$(cat /proc/cpuinfo | grep "model name" | wc -l )"
            local battery_status="$(WMIC Path Win32_Battery Get BatteryStatus | tail -2 | head -1 | tr -d "[:space:]")"
            [ "$battery_status" = "1" ] && battery=true

        elif [[ "$OSTYPE" == "darwin"* ]]; then
            local memory="$(sysctl -n hw.memsize | numfmt --to=iec-i)"
            local cpu="$(sysctl -n machdep.cpu.brand_string | tr -d "[:space:]")"
            local cpu_count="$(sysctl -n hw.perflevel0.physicalcpu)+$(sysctl -n hw.perflevel1.physicalcpu)"
            if [[ ! $(pmset -g ps | head -1) =~ "AC Power" ]]; then
                battery=true
            fi
        
        elif [[ "$OSTYPE" == "linux"* ]]; then
            local mem_kb="$(cat /proc/meminfo | grep 'MemTotal:' | awk '{print $2}')"
            local memory="$(echo $((mem_kb * 1024)) | numfmt --to=iec-i)"
            local cpu="$(cat /proc/cpuinfo | grep "model name" | head -1 | awk -F':' '{print $2}' | tr -d "[:space:]")"
            local cpu_count="$(cat /proc/cpuinfo | grep "model name" | wc -l )"
        else
            local memory="unknown$OSTYPE"
            local cpu="unknown$OSTYPE"
        fi
    fi

    add_metric os "$OSTYPE"
    add_metric arch "$(arch)"
    add_metric container "$container"
    add_metric cpu "$cpu"
    [ -n "$cpu_count" ] && add_metric cpu_count "$cpu_count"
    add_metric memory "$memory"
    add_metric battery "$battery"
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