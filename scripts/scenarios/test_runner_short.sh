#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HARNESS="${PROJECT_DIR}/hal/stub_test_modular_axis_csp.hal"
LOG_DIR="${PROJECT_DIR}/logs"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/test_short_${TS}.log"
STATUS_FILE="${LOG_DIR}/test_short_last_status.txt"
SNAP_FILE="${LOG_DIR}/failure_snapshot_${TS}.txt"
HALRUN_STDOUT="${LOG_DIR}/halrun_${TS}.stdout"

CYCLES="${1:-20}"

mkdir -p "${LOG_DIR}"

log() {
    local msg="$*"
    echo "[$(date '+%F %T')] ${msg}" | tee -a "${LOG_FILE}"
}

write_status() {
    {
        echo "timestamp=$(date '+%F %T')"
        echo "status=$1"
        echo "cycle=$2"
        echo "detail=$3"
        echo "log_file=${LOG_FILE}"
        echo "snapshot_file=${SNAP_FILE}"
        echo "halrun_stdout=${HALRUN_STDOUT}"
    } > "${STATUS_FILE}"
}

cleanup() {
    if [[ -n "${HALRUN_PID:-}" ]]; then
        if kill -0 "${HALRUN_PID}" 2>/dev/null; then
            printf '\n' >&"${HAL_IN}" 2>/dev/null || true
            sleep 0.2
            kill "${HALRUN_PID}" 2>/dev/null || true
            wait "${HALRUN_PID}" 2>/dev/null || true
        fi
    fi
}

fail() {
    local cycle="$1"
    local detail="$2"

    log "FAIL cycle=${cycle} detail=${detail}"
    write_status "FAIL" "${cycle}" "${detail}"
    snapshot
    cleanup
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Required command not found: $1" >&2
        exit 1
    }
}

start_hal() {

    log "Stopping any previous halrun session"
    halrun -U >/dev/null 2>&1 || true

    : > "${HALRUN_STDOUT}"

    log "Starting interactive halrun keeper coprocess"

    coproc HALPROC { halrun -I "${HARNESS}" >> "${HALRUN_STDOUT}" 2>&1; }

    HAL_IN="${HALPROC[1]}"
    HAL_OUT="${HALPROC[0]}"
    HALRUN_PID="${HALPROC_PID}"

    sleep 1

    if ! kill -0 "${HALRUN_PID}" 2>/dev/null; then
        log "halrun did not stay alive; see ${HALRUN_STDOUT}"
        write_status "FAIL" "0" "halrun failed to start"
        exit 1
    fi

    log "Harness started with PID ${HALRUN_PID}"

    timeout 1 cat <&"${HAL_OUT}" >> "${HALRUN_STDOUT}" 2>/dev/null || true
}

hal_set() {
    local sig="$1"
    local val="$2"
    halcmd sets "${sig}" "${val}" >> "${LOG_FILE}" 2>&1
}

hal_get_pin_value() {

    local comp="$1"
    local pin="$2"

    halcmd show pin "${comp}" | awk -v p="${comp}.${pin}" '
        $0 ~ ("[[:space:]]" p "([[:space:]]|$)") { print $4; exit }
    '
}

hal_get_sig_value() {

    local sig="$1"

    halcmd show sig "${sig}" | awk -v s="${sig}" '
        $3 == s { print $2; exit }
    '
}

wait_for_pin_value() {

    local cycle="$1"
    local comp="$2"
    local pin="$3"
    local expected="$4"
    local timeout_s="$5"

    local start now elapsed value

    start=$(date +%s)

    while true; do

        value="$(hal_get_pin_value "${comp}" "${pin}" || true)"

        if [[ "${value}" == "${expected}" ]]; then
            return 0
        fi

        now=$(date +%s)
        elapsed=$((now - start))

        if (( elapsed >= timeout_s )); then
            fail "${cycle}" "timeout waiting ${comp}.${pin}=${expected} current=${value}"
        fi

        sleep 0.1
    done
}

wait_for_sig_value() {

    local cycle="$1"
    local sig="$2"
    local expected="$3"
    local timeout_s="$4"

    local start now elapsed value

    start=$(date +%s)

    while true; do

        value="$(hal_get_sig_value "${sig}" || true)"

        if [[ "${value}" == "${expected}" ]]; then
            return 0
        fi

        now=$(date +%s)
        elapsed=$((now - start))

        if (( elapsed >= timeout_s )); then
            fail "${cycle}" "timeout waiting signal ${sig}=${expected} current=${value}"
        fi

        sleep 0.1
    done
}

check_invariants() {

    local cycle="$1"
    local phase="$2"

    local sel_home sel_csp om stub_in_opmode mcsp_active mcsp_ready ut_owner

    sel_home="$(hal_get_pin_value mux sel-home || true)"
    sel_csp="$(hal_get_pin_value mux sel-csp || true)"
    om="$(hal_get_sig_value om || true)"
    stub_in_opmode="$(hal_get_pin_value stub in-opmode || true)"
    mcsp_active="$(hal_get_pin_value mcsp active || true)"
    mcsp_ready="$(hal_get_pin_value mcsp ready || true)"
    ut_owner="$(hal_get_pin_value ut owner || true)"

    if [[ "${sel_home}" == "TRUE" && "${sel_csp}" == "TRUE" ]]; then
        fail "${cycle}" "phase=${phase} mux selected HOME and CSP simultaneously"
    fi

    if [[ "${sel_home}" == "TRUE" && "${om}" != "6" ]]; then
        fail "${cycle}" "phase=${phase} HOME selected but om=${om} expected 6"
    fi

    if [[ "${sel_csp}" == "TRUE" && "${om}" != "8" ]]; then
        fail "${cycle}" "phase=${phase} CSP selected but om=${om} expected 8"
    fi

    if [[ "${mcsp_active}" == "TRUE" && "${mcsp_ready}" != "TRUE" ]]; then
        fail "${cycle}" "phase=${phase} mcsp.active TRUE while mcsp.ready != TRUE"
    fi

    if [[ -n "${stub_in_opmode}" && -n "${om}" && "${stub_in_opmode}" != "${om}" ]]; then
        fail "${cycle}" "phase=${phase} stub.in-opmode=${stub_in_opmode} differs from om=${om}"
    fi

    if [[ "${phase}" == "post-home-release" && "${ut_owner}" == "TRUE" ]]; then
        fail "${cycle}" "phase=${phase} ut.owner stuck TRUE after home release"
    fi
}

snapshot() {

    log "Collecting failure snapshot into ${SNAP_FILE}"

    {
        echo "===== FAILURE SNAPSHOT $(date '+%F %T') ====="
        echo
        halcmd show thread
        echo
        halcmd show pin msg
        echo
        halcmd show pin pds
        echo
        halcmd show pin ut
        echo
        halcmd show pin mcsp
        echo
        halcmd show pin mux
        echo
        halcmd show pin cw
        echo
        halcmd show pin stub
        echo
        halcmd show sig om
        echo
        halcmd show sig tp
        echo
        halcmd show sig home-req
        echo
        halcmd show sig motion-req
        echo
        halcmd show sig allow-motion
    } > "${SNAP_FILE}" 2>&1 || true
}

init_baseline() {

    log "Initializing baseline signals"

    hal_set motion-req FALSE
    hal_set home-req FALSE
    hal_set axis-cmd-pos 0

    sleep 0.5
}

run_cycle() {

    local cycle="$1"

    log "Cycle ${cycle}: request CSP"

    hal_set motion-req TRUE
    hal_set axis-cmd-pos 100

    wait_for_pin_value "${cycle}" mcsp owner TRUE 5
    wait_for_pin_value "${cycle}" mcsp ready TRUE 5
    wait_for_pin_value "${cycle}" mux sel-csp TRUE 5
    wait_for_sig_value "${cycle}" om 8 5

    check_invariants "${cycle}" "csp-active"

    log "Cycle ${cycle}: request HOME"

    hal_set home-req TRUE

    wait_for_pin_value "${cycle}" ut owner TRUE 5
    wait_for_pin_value "${cycle}" mux sel-home TRUE 5
    wait_for_sig_value "${cycle}" om 6 5
    wait_for_pin_value "${cycle}" ut homed TRUE 5

    check_invariants "${cycle}" "home-active"

    log "Cycle ${cycle}: release HOME"

    hal_set home-req FALSE

    wait_for_pin_value "${cycle}" ut owner FALSE 5
    wait_for_pin_value "${cycle}" mux sel-csp TRUE 5
    wait_for_sig_value "${cycle}" om 8 5
    wait_for_pin_value "${cycle}" mcsp ready TRUE 5

    check_invariants "${cycle}" "post-home-release"

    log "Cycle ${cycle}: PASS"
}

main() {

    require_cmd halrun
    require_cmd halcmd

    if [[ ! -f "${HARNESS}" ]]; then
        echo "Harness not found: ${HARNESS}" >&2
        exit 1
    fi

    trap cleanup EXIT INT TERM

    : > "${LOG_FILE}"
    write_status "RUNNING" "0" "starting"

    log "==== test_runner_short.sh starting ===="
    log "Script dir: ${SCRIPT_DIR}"
    log "Project dir: ${PROJECT_DIR}"
    log "Harness: ${HARNESS}"
    log "Cycles: ${CYCLES}"
    log "Log file: ${LOG_FILE}"

    start_hal
    init_baseline

    local i

    for ((i=1; i<=CYCLES; i++)); do
        write_status "RUNNING" "${i}" "executing"
        run_cycle "${i}"
    done

    log "All cycles passed"

    write_status "PASS" "${CYCLES}" "all cycles passed"

    cleanup

    log "==== test_runner_short.sh finished successfully ===="
}

main "$@"
