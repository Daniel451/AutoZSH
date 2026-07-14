#!/usr/bin/env zsh

emulate -LR zsh
setopt errexit nounset pipefail

SCRIPT_DIR=${0:A:h}
SCRIPT_NAME=${0:t}
REPOSITORY_DIR=${SCRIPT_DIR:h}
CONFIGURATION=${REPOSITORY_DIR}/zshrc
DEFAULT_DIRECTORY_LIST=${SCRIPT_DIR}/fixtures/default.txt
OUTPUT_DIRECTORY=${SCRIPT_DIR}/output
SAMPLES=300
WARMUPS=10
SEED=${RANDOM}${RANDOM}
MODE=all
DIRECTORY_LIST=''
PLUGIN_OVERRIDE=''
PLUGIN_OVERRIDE_SET=false
OUTPUT=''
SANDBOX=''
BASELINE_RESULTS=''
STARTUP_RESULTS=''
NAVIGATION_RESULTS=''

# Keep usage output independent from the currently selected benchmark mode.
usage() {
    print -r -- "Usage: ${SCRIPT_NAME} [baseline|startup|navigation] [options]"
    print -r -- ''
    print -r -- 'Without a mode, runs baseline, startup, and navigation benchmarks.'
    print -r -- ''
    print -r -- 'Options:'
    print -r -- '  --samples COUNT       Measured samples (default: 300)'
    print -r -- '  --warmups COUNT       Warm-up samples (default: 10)'
    print -r -- '  --seed NUMBER         Seed for directory selection'
    print -r -- '  --directories FILE    File containing benchmark directories'
    print -r -- '  --plugins LIST        Comma-separated Oh My Zsh plugin override'
    print -r -- '  --output FILE         Write TSV results to FILE (default: tests/output/MODE.tsv)'
}

fail() {
    print -u2 -r -- "error: $*"
    exit 1
}

status() {
    print -r -- "$*"
}

test_category() {
    print -r -- '---------------------------------------------------'
    print -r -- " Test category: $1"
    print -r -- '---------------------------------------------------'
}

cleanup() {
    [[ -n ${SANDBOX} && -d ${SANDBOX} ]] && rm -rf -- "${SANDBOX}"
}
trap cleanup EXIT INT TERM

# A mode is optional; arguments otherwise tune the complete benchmark suite.
while (( $# )); do
    case $1 in
        baseline|startup|navigation)
            [[ ${MODE} == all ]] || fail 'select at most one benchmark mode'
            MODE=$1
            ;;
        --samples)
            (( $# >= 2 )) || fail '--samples requires a value'
            SAMPLES=$2
            shift
            ;;
        --warmups)
            (( $# >= 2 )) || fail '--warmups requires a value'
            WARMUPS=$2
            shift
            ;;
        --seed)
            (( $# >= 2 )) || fail '--seed requires a value'
            SEED=$2
            shift
            ;;
        --directories)
            (( $# >= 2 )) || fail '--directories requires a value'
            DIRECTORY_LIST=$2
            shift
            ;;
        --plugins)
            (( $# >= 2 )) || fail '--plugins requires a value'
            PLUGIN_OVERRIDE=${2//,/ }
            PLUGIN_OVERRIDE_SET=true
            shift
            ;;
        --output)
            (( $# >= 2 )) || fail '--output requires a value'
            OUTPUT=$2
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
    shift
done

[[ ${SAMPLES} == <-> && ${SAMPLES} -gt 0 ]] || fail '--samples must be a positive integer'
[[ ${WARMUPS} == <-> ]] || fail '--warmups must be a non-negative integer'
[[ ${SEED} == <-> ]] || fail '--seed must be a non-negative integer'
[[ -r ${CONFIGURATION} ]] || fail "missing configuration: ${CONFIGURATION}"
(( $+commands[zsh] )) || fail 'zsh is required'
(( $+commands[zoxide] )) || fail 'zoxide is required'
if [[ ${MODE} == all || ${MODE} == baseline ]]; then
    (( $+commands[bash] )) || fail 'bash is required for baseline benchmarks'
fi
[[ -d ${HOME}/.oh-my-zsh ]] || fail "missing Oh My Zsh installation: ${HOME}/.oh-my-zsh"
PLUGIN_DESCRIPTION=${PLUGIN_OVERRIDE_SET:+${PLUGIN_OVERRIDE:-none}}
[[ ${PLUGIN_OVERRIDE_SET} == true ]] || PLUGIN_DESCRIPTION=default

# The copied configuration derives ZSH from HOME, so expose the installed
# dependencies through the disposable benchmark home rather than the real one.
status 'Starting benchmark...'
status "Configuration: ${SAMPLES} samples, ${WARMUPS} warm-ups, plugins=${PLUGIN_DESCRIPTION:-default}"
status 'Test category definitions:'
status '  bash no-config: bare Bash without profiles or rc files'
status '  zsh no-config: bare Zsh without configuration files'
status '  zsh config: supplied rc file (default: repository zshrc)'
status 'Preparing isolated benchmark environment...'
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/autozsh-benchmark.XXXXXX")
mkdir -p "${SANDBOX}/data"
ln -s "${HOME}/.oh-my-zsh" "${SANDBOX}/.oh-my-zsh"
cp "${CONFIGURATION}" "${SANDBOX}/.zshrc"

typeset -a SANDBOX_ENV
SANDBOX_ENV=(
    "HOME=${SANDBOX}"
    "ZDOTDIR=${SANDBOX}"
    "XDG_DATA_HOME=${SANDBOX}/data"
    "_ZO_DATA_DIR=${SANDBOX}/data/zoxide"
    "_ZO_DOCTOR=0"
)
[[ ${PLUGIN_OVERRIDE_SET} == true ]] && SANDBOX_ENV+=("AUTOZSH_PLUGINS=${PLUGIN_OVERRIDE}")

# Every timed command starts a fresh shell with the same isolated environment.
run_shell() {
    env "${SANDBOX_ENV[@]}" zsh -dfc "$1"
}

run_bash() {
    env "HOME=${SANDBOX}" BASH_ENV='' bash --noprofile --norc -c "$1"
}

run_bare_zsh() {
    env "HOME=${SANDBOX}" zsh -dfc "$1"
}

run_bash_cd() {
    env "HOME=${SANDBOX}" BASH_ENV='' "TARGET_DIRECTORY=$1" bash --noprofile --norc -c 'builtin cd -- "$TARGET_DIRECTORY"'
}

run_bare_zsh_cd() {
    env "HOME=${SANDBOX}" "TARGET_DIRECTORY=$1" zsh -dfc 'builtin cd -- "$TARGET_DIRECTORY"'
}

elapsed_seconds() {
    local command=$1 start end
    zmodload zsh/datetime
    start=${EPOCHREALTIME}
    eval "${command}"
    end=${EPOCHREALTIME}
    awk -v start="${start}" -v end="${end}" 'BEGIN { printf "%.6f", end - start }'
}

elapsed_command() {
    local start end
    zmodload zsh/datetime
    start=${EPOCHREALTIME}
    "$@"
    end=${EPOCHREALTIME}
    awk -v start="${start}" -v end="${end}" 'BEGIN { printf "%.6f", end - start }'
}

metric_median() {
    local results=$1 metric=$2 count
    count=$(awk -F '\t' -v metric="${metric}" 'NR > 1 { print $metric }' "${results}" | wc -l | tr -d ' ')
    awk -F '\t' -v metric="${metric}" 'NR > 1 { print $metric }' "${results}" | sort -n | awk -v count="${count}" '{ values[NR] = $1 } END { if (count % 2) print values[(count + 1) / 2]; else printf "%.6f\n", (values[count / 2] + values[count / 2 + 1]) / 2 }'
}

# Results remain TSV so raw samples can be inspected alongside these summaries.
summarize() {
    local results=$1 metric=$2 label=$3 count mean median minimum maximum
    count=$(awk -F '\t' -v metric="${metric}" 'NR > 1 { print $metric }' "${results}" | wc -l | tr -d ' ')
    minimum=$(awk -F '\t' -v metric="${metric}" 'NR > 1 && (!seen++ || $metric < min) { min = $metric } END { print min }' "${results}")
    maximum=$(awk -F '\t' -v metric="${metric}" 'NR > 1 && (!seen++ || $metric > max) { max = $metric } END { print max }' "${results}")
    mean=$(awk -F '\t' -v metric="${metric}" 'NR > 1 { sum += $metric; count++ } END { if (count) printf "%.6f", sum / count }' "${results}")
    median=$(awk -F '\t' -v metric="${metric}" 'NR > 1 { print $metric }' "${results}" | sort -n | awk -v count="${count}" '{ values[NR] = $1 } END { if (count % 2) print values[(count + 1) / 2]; else printf "%.6f\n", (values[count / 2] + values[count / 2 + 1]) / 2 }')

    print
    print -r -- '---------------------------------------------------'
    print -r -- " ${label} (measured in s; ${count} samples)"
    print -r -- '---------------------------------------------------'
    printf '%-8s %12.6fs\n' 'min:' "${minimum}"
    printf '%-8s %12.6fs\n' 'max:' "${maximum}"
    printf '%-8s %12.6fs\n' 'median:' "${median}"
    printf '%-8s %12.6fs\n' 'mean:' "${mean}"
}

# Progress is deliberately outside timed child shells and suppressed for CI and
# redirected output, where terminal control characters would be unhelpful.
progress() {
    [[ -t 2 ]] || return 0

    local label=$1 current=$2 total=$3 width=30 filled index percent bar=''
    (( total > 0 )) || return 0

    filled=$(( current * width / total ))
    percent=$(( current * 100 / total ))
    for (( index = 1; index <= width; index++ )); do
        if (( index <= filled )); then
            bar+='#'
        else
            bar+='-'
        fi
    done

    print -u2 -nr -- $'\r'"${label} [${bar}] ${percent}% ${current}/${total}"
    if (( current == total )); then
        print -u2
    fi
}

[[ -n ${DIRECTORY_LIST} ]] || DIRECTORY_LIST=${DEFAULT_DIRECTORY_LIST}
if [[ ${MODE} == all && -n ${OUTPUT} ]]; then
    fail '--output requires baseline, startup, or navigation mode'
fi
[[ -n ${OUTPUT} ]] || {
    mkdir -p "${OUTPUT_DIRECTORY}"
}

baseline_benchmark() {
    local results=${OUTPUT:-${OUTPUT_DIRECTORY}/baseline.tsv} target
    typeset -a baseline_directories
    baseline_directories=("${SANDBOX}/baseline/empty-a" "${SANDBOX}/baseline/empty-b")

    print
    test_category 'bash no-config and zsh no-config controls'
    status 'Starting baseline benchmark...'
    status 'Creating controlled empty directories outside a Git repository...'
    print -r -- 'Baseline controls run in this order for every sample:'
    print -r -- '  1. bash no-config startup: bash --noprofile --norc -c ":"'
    print -r -- '  2. zsh no-config startup: zsh -dfc ":"'
    print -r -- '  3. bash no-config process + cd: fresh Bash changes to an empty directory'
    print -r -- '  4. zsh no-config process + cd: fresh Zsh changes to an empty directory'
    mkdir -p "${baseline_directories[@]}"
    print -r -- $'sample\ttarget\tbash_startup_seconds\tbare_zsh_startup_seconds\tbash_process_cd_seconds\tbare_zsh_process_cd_seconds' > "${results}"

    RANDOM=${SEED}
    if (( WARMUPS > 0 )); then
        status "Running ${WARMUPS} baseline warm-up samples..."
        print
    fi
    for (( warmup = 1; warmup <= WARMUPS; warmup++ )); do
        target=${baseline_directories[$(( RANDOM % ${#baseline_directories} + 1 ))]}
        run_bash ':' >/dev/null
        run_bare_zsh ':' >/dev/null
        run_bash_cd "${target}" >/dev/null
        run_bare_zsh_cd "${target}" >/dev/null
        progress 'baseline warm-up' "${warmup}" "${WARMUPS}"
    done

    status "Running ${SAMPLES} baseline samples..."
    print
    for sample in {1..${SAMPLES}}; do
        target=${baseline_directories[$(( RANDOM % ${#baseline_directories} + 1 ))]}
        bash_startup=$(elapsed_command run_bash ':')
        bare_zsh_startup=$(elapsed_command run_bare_zsh ':')
        bash_cd=$(elapsed_command run_bash_cd "${target}")
        bare_zsh_cd=$(elapsed_command run_bare_zsh_cd "${target}")
        print -r -- "${sample}"$'\t'"${target}"$'\t'"${bash_startup}"$'\t'"${bare_zsh_startup}"$'\t'"${bash_cd}"$'\t'"${bare_zsh_cd}" >> "${results}"
        progress baseline "${sample}" "${SAMPLES}"
    done
    print -r -- "mode=baseline samples=${SAMPLES} warmups=${WARMUPS} seed=${SEED}"
    summarize "${results}" 3 'bash no-config startup'
    summarize "${results}" 4 'zsh no-config startup'
    summarize "${results}" 5 'bash no-config process + cd'
    summarize "${results}" 6 'zsh no-config process + cd'
    BASELINE_RESULTS=${results}
    print
    print -r -- "raw results: ${results}"
}

# Configuration load time includes launching a new shell and sourcing zshrc.
startup_benchmark() {
    local results=${OUTPUT:-${OUTPUT_DIRECTORY}/startup.tsv}
    print
    test_category 'zsh config'
    status 'Starting startup benchmark...'
    print -r -- $'sample\tstartup_seconds' > "${results}"
    if (( WARMUPS > 0 )); then
        status "Running ${WARMUPS} startup warm-up samples..."
        print
    fi
    for (( warmup = 1; warmup <= WARMUPS; warmup++ )); do
        run_shell 'source "$ZDOTDIR/.zshrc"' >/dev/null 2>&1
        progress 'startup warm-up' "${warmup}" "${WARMUPS}"
    done
    status "Running ${SAMPLES} startup samples..."
    print
    for sample in {1..${SAMPLES}}; do
        seconds=$(elapsed_seconds 'run_shell '\''source "$ZDOTDIR/.zshrc"'\'' >/dev/null 2>&1')
        print -r -- "${sample}"$'\t'"${seconds}" >> "${results}"
        progress startup "${sample}" "${SAMPLES}"
    done
    print -r -- "mode=startup samples=${SAMPLES} warmups=${WARMUPS} plugins=${PLUGIN_DESCRIPTION}"
    summarize "${results}" 2 'zsh config startup'
    STARTUP_RESULTS=${results}
    print
    print -r -- "raw results: ${results}"
}

# Navigation uses one initialized sandbox Zsh process, matching an existing
# terminal session while keeping startup cost isolated to startup_benchmark.
navigation_benchmark() {
    local results=${OUTPUT:-${OUTPUT_DIRECTORY}/navigation.tsv} targets_file=${SANDBOX}/navigation-targets.tsv
    print
    test_category 'zsh config'
    status 'Starting navigation benchmark...'
    status 'Loading directories and seeding the isolated zoxide database...'
    [[ -r ${DIRECTORY_LIST} ]] || fail "cannot read directory list: ${DIRECTORY_LIST}"

    typeset -a directories
    local_directory=''
    while IFS= read -r local_directory || [[ -n ${local_directory} ]]; do
        [[ -z ${local_directory} || ${local_directory} == \#* ]] && continue
        [[ ${local_directory} != *$'\t'* && ${local_directory} != *$'\n'* ]] || fail "directory contains an unsupported character: ${local_directory}"
        [[ -d ${local_directory} ]] || fail "directory does not exist: ${local_directory}"
        directories+=("${local_directory:A}")
    done < "${DIRECTORY_LIST}"
    (( ${#directories} )) || fail 'directory list contains no usable directories'

    # Keep zoxide's ranking database inside the sandbox while making all listed
    # targets available to every fresh child shell.
    for directory in "${directories[@]}"; do
        env "${SANDBOX_ENV[@]}" zoxide add -- "${directory}"
    done

    # Generate the entire sequence before starting the child so the parent owns
    # the seed and can retain reproducible target selection.
    RANDOM=${SEED}
    for sample in {1..$(( WARMUPS + SAMPLES ))}; do
        target=${directories[$(( RANDOM % ${#directories} + 1 ))]}
        print -r -- "${sample}"$'\t'"${target}" >> "${targets_file}"
    done

    print -r -- $'sample\ttarget\tcd_seconds\tcd_prompt_git_seconds\tz_seconds\tz_prompt_git_seconds' > "${results}"
    # The child streams metrics as it processes targets, allowing the parent to
    # update progress while still propagating failures through pipefail.
    if (( WARMUPS > 0 )); then
        status "Running ${WARMUPS} navigation warm-up samples..."
        print
    else
        status "Running ${SAMPLES} navigation samples..."
        print
    fi
    env "${SANDBOX_ENV[@]}" "TARGETS_FILE=${targets_file}" zsh -dfc '
            source "$ZDOTDIR/.zshrc" >/dev/null
            zmodload zsh/datetime
            while IFS=$'\''\t'\'' read -r sample target; do
                builtin cd -- /
                cd_start=${EPOCHREALTIME}
                builtin cd -- "$target"
                cd_end=${EPOCHREALTIME}
                CURRENT_BG=NONE
                cd_prompt_start=${EPOCHREALTIME}
                prompt_git >/dev/null
                cd_prompt_end=${EPOCHREALTIME}
                builtin cd -- /
                z_start=${EPOCHREALTIME}
                z -- "$target"
                z_end=${EPOCHREALTIME}
                CURRENT_BG=NONE
                z_prompt_start=${EPOCHREALTIME}
                prompt_git >/dev/null
                z_prompt_end=${EPOCHREALTIME}
                metrics=$(awk -v cd_start="$cd_start" -v cd_end="$cd_end" -v cd_prompt_start="$cd_prompt_start" -v cd_prompt_end="$cd_prompt_end" -v z_start="$z_start" -v z_end="$z_end" -v z_prompt_start="$z_prompt_start" -v z_prompt_end="$z_prompt_end" '\''BEGIN { printf "%.6f\t%.6f\t%.6f\t%.6f", cd_end - cd_start, cd_prompt_end - cd_prompt_start, z_end - z_start, z_prompt_end - z_prompt_start }'\'')
                print -r -- "${sample}"$'\''\t'\''"${target}"$'\''\t'\''"${metrics}"
            done < "$TARGETS_FILE"
        ' | while IFS=$'\t' read -r sample target cd_seconds cd_prompt_seconds z_seconds z_prompt_seconds; do
        if (( sample <= WARMUPS )); then
            progress 'navigation warm-up' "${sample}" "${WARMUPS}"
            continue
        fi

        measured_sample=$(( sample - WARMUPS ))
        if (( measured_sample == 1 && WARMUPS > 0 )); then
            status "Running ${SAMPLES} navigation samples..."
            print
        fi
        print -r -- "${measured_sample}"$'\t'"${target}"$'\t'"${cd_seconds}"$'\t'"${cd_prompt_seconds}"$'\t'"${z_seconds}"$'\t'"${z_prompt_seconds}" >> "${results}"
        progress navigation "${measured_sample}" "${SAMPLES}"
    done
    print -r -- "mode=navigation samples=${SAMPLES} warmups=${WARMUPS} seed=${SEED} plugins=${PLUGIN_DESCRIPTION}"
    summarize "${results}" 3 'zsh config cd'
    summarize "${results}" 4 'zsh config prompt after cd'
    summarize "${results}" 5 'zsh config z'
    summarize "${results}" 6 'zsh config prompt after z'
    NAVIGATION_RESULTS=${results}
    print
    print -r -- "raw results: ${results}"
}

outlier_check() {
    local results=$1 metric=$2 label=$3 sample_count outlier_count maximum
    sample_count=$(awk -F '\t' -v metric="${metric}" 'NR > 1 { print $metric }' "${results}" | wc -l | tr -d ' ')
    outlier_count=$(awk -F '\t' -v metric="${metric}" 'NR > 1 && $metric > 1 { count++ } END { print count + 0 }' "${results}")
    maximum=$(awk -F '\t' -v metric="${metric}" 'NR > 1 && (!seen++ || $metric > max) { max = $metric } END { print max }' "${results}")

    if (( outlier_count > 0 )); then
        printf '[ %-7s ] %-32s %4d samples >1s (max %9.6fs)\n' 'WARNING' "${label}:" "${outlier_count}" "${maximum}"
    else
        printf '[ %-7s ] %-32s %4d samples >1s (max %9.6fs)\n' 'OKAY' "${label}:" "${outlier_count}" "${maximum}"
    fi
}

compare_medians() {
    local reference_label=$1 reference_results=$2 reference_metric=$3 candidate_label=$4 candidate_results=$5 candidate_metric=$6 reference candidate percent
    reference=$(metric_median "${reference_results}" "${reference_metric}")
    candidate=$(metric_median "${candidate_results}" "${candidate_metric}")

    if awk -v reference="${reference}" -v candidate="${candidate}" 'BEGIN { exit !(candidate <= reference * 0.8 && reference - candidate >= 0.02) }'; then
        percent=$(awk -v reference="${reference}" -v candidate="${candidate}" 'BEGIN { printf "%.0f", (1 - candidate / reference) * 100 }')
        printf '[ %-7s ] %-32s %3s%% (%8.6fs < %8.6fs)\n' 'NOTICE' "${candidate_label} vs ${reference_label}:" "${percent}" "${candidate}" "${reference}"
    else
        printf '[ %-7s ] %-32s %s\n' 'OKAY' "${candidate_label} vs ${reference_label}:" 'no material median advantage'
    fi
}

checkup_group() {
    print
    print -r -- "--- $1 ------------------------------------------------"
}

final_checkup() {
    print
    print -r -- '==================================================='
    print -r -- ' Final benchmark checkup'
    print -r -- '==================================================='
    print -r -- 'Outlier threshold: samples taking more than 1 second.'

    if [[ -n ${BASELINE_RESULTS} || -n ${STARTUP_RESULTS} ]]; then
        checkup_group 'Startup'
        if [[ -n ${BASELINE_RESULTS} ]]; then
            outlier_check "${BASELINE_RESULTS}" 3 'bash no-config startup'
            outlier_check "${BASELINE_RESULTS}" 4 'zsh no-config startup'
        fi
        if [[ -n ${STARTUP_RESULTS} ]]; then
            outlier_check "${STARTUP_RESULTS}" 2 'zsh config startup'
        fi
        if [[ -n ${BASELINE_RESULTS} ]]; then
            print
            print -r -- 'Startup median comparisons (notice: at least 20% and 20ms faster):'
            compare_medians 'zsh no-config' "${BASELINE_RESULTS}" 4 'bash no-config' "${BASELINE_RESULTS}" 3
            if [[ -n ${STARTUP_RESULTS} ]]; then
                compare_medians 'zsh config' "${STARTUP_RESULTS}" 2 'zsh no-config' "${BASELINE_RESULTS}" 4
                compare_medians 'zsh config' "${STARTUP_RESULTS}" 2 'bash no-config' "${BASELINE_RESULTS}" 3
            fi
        fi
    fi

    if [[ -n ${BASELINE_RESULTS} || -n ${NAVIGATION_RESULTS} ]]; then
        checkup_group 'Navigation'
        if [[ -n ${BASELINE_RESULTS} ]]; then
            outlier_check "${BASELINE_RESULTS}" 5 'bash no-config process + cd'
            outlier_check "${BASELINE_RESULTS}" 6 'zsh no-config process + cd'
        fi
        if [[ -n ${NAVIGATION_RESULTS} ]]; then
            outlier_check "${NAVIGATION_RESULTS}" 3 'zsh config cd'
            outlier_check "${NAVIGATION_RESULTS}" 4 'zsh config prompt after cd'
            outlier_check "${NAVIGATION_RESULTS}" 5 'zsh config z'
            outlier_check "${NAVIGATION_RESULTS}" 6 'zsh config prompt after z'
        fi
    fi
}

if [[ ${MODE} == all || ${MODE} == baseline ]]; then
    baseline_benchmark
fi

if [[ ${MODE} == all || ${MODE} == startup ]]; then
    startup_benchmark
fi

if [[ ${MODE} == all || ${MODE} == navigation ]]; then
    navigation_benchmark
fi

final_checkup