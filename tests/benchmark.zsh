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

# Keep usage output independent from the currently selected benchmark mode.
usage() {
    print -r -- "Usage: ${SCRIPT_NAME} [startup|navigation] [options]"
    print -r -- ''
    print -r -- 'Without a mode, runs both startup and navigation benchmarks.'
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

cleanup() {
    [[ -n ${SANDBOX} && -d ${SANDBOX} ]] && rm -rf -- "${SANDBOX}"
}
trap cleanup EXIT INT TERM

# A mode is optional; arguments otherwise tune the complete benchmark suite.
while (( $# )); do
    case $1 in
        startup|navigation)
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
[[ -d ${HOME}/.oh-my-zsh ]] || fail "missing Oh My Zsh installation: ${HOME}/.oh-my-zsh"
PLUGIN_DESCRIPTION=${PLUGIN_OVERRIDE_SET:+${PLUGIN_OVERRIDE:-none}}
[[ ${PLUGIN_OVERRIDE_SET} == true ]] || PLUGIN_DESCRIPTION=default

# The copied configuration derives ZSH from HOME, so expose the installed
# dependencies through the disposable benchmark home rather than the real one.
status 'Starting benchmark...'
status "Configuration: ${SAMPLES} samples, ${WARMUPS} warm-ups, plugins=${PLUGIN_DESCRIPTION:-default}"
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

elapsed_seconds() {
    local command=$1 start end
    zmodload zsh/datetime
    start=${EPOCHREALTIME}
    eval "${command}"
    end=${EPOCHREALTIME}
    awk -v start="${start}" -v end="${end}" 'BEGIN { printf "%.6f", end - start }'
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
    fail '--output requires startup or navigation mode'
fi
[[ -n ${OUTPUT} ]] || {
    mkdir -p "${OUTPUT_DIRECTORY}"
}

# Configuration load time includes launching a new shell and sourcing zshrc.
startup_benchmark() {
    local results=${OUTPUT:-${OUTPUT_DIRECTORY}/startup.tsv}
    print
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
    summarize "${results}" 2 startup
    print
    print -r -- "raw results: ${results}"
}

# Navigation uses one initialized sandbox Zsh process, matching an existing
# terminal session while keeping startup cost isolated to startup_benchmark.
navigation_benchmark() {
    local results=${OUTPUT:-${OUTPUT_DIRECTORY}/navigation.tsv} targets_file=${SANDBOX}/navigation-targets.tsv
    print
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
    summarize "${results}" 3 cd
    summarize "${results}" 4 'prompt_git after cd'
    summarize "${results}" 5 z
    summarize "${results}" 6 'prompt_git after z'
    print
    print -r -- "raw results: ${results}"
}

if [[ ${MODE} == all || ${MODE} == startup ]]; then
    startup_benchmark
fi

if [[ ${MODE} == all || ${MODE} == navigation ]]; then
    navigation_benchmark
fi