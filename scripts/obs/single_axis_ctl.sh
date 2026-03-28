#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAG_SCRIPT="${SCRIPT_DIR}/diag_single_axis.sh"

ACTION="${1:-snapshot}"
STEP="${2:-${ACTION}}"
ARG3="${3:-stdout}"
ARG4="${4:-}"
ARG5="${5:-}"

usage() {
    echo "Usage:"
    echo "  $0 snapshot [step] [stdout|log]"
    echo "  $0 motion-on [step] [stdout|log]"
    echo "  $0 motion-off [step] [stdout|log]"
    echo "  $0 home-on [step] [stdout|log]"
    echo "  $0 home-off [step] [stdout|log]"
    echo "  $0 wait-snapshot <step> <seconds> [stdout|log]"
    echo "  $0 home-cycle <step-prefix> [seconds] [stdout|log]"
    echo "  $0 safe-home-cycle <step-prefix> [seconds] [stdout|log]"
    echo "  $0 csp-cycle <step-prefix> [seconds] [stdout|log]"
    echo "  $0 mixed-cycle <step-prefix> [seconds] [stdout|log]"
    echo "  $0 mixed-loop <step-prefix> <count> [seconds] [stdout|log]"
    echo "  $0 sleep <seconds>"
    exit 1
}

run_diag() {
    local step="$1"
    local log_mode="$2"
    "${DIAG_SCRIPT}" "${step}" "${log_mode}"
}

do_home_cycle() {
    local prefix="$1"
    local sec="$2"
    local log_mode="$3"

    halcmd sets home-req-x TRUE
    run_diag "${prefix}_home_on" "${log_mode}"

    sleep "${sec}"
    run_diag "${prefix}_home_stable" "${log_mode}"

    halcmd sets home-req-x FALSE
    run_diag "${prefix}_home_off" "${log_mode}"

    sleep "${sec}"
    run_diag "${prefix}_back_to_csp" "${log_mode}"
}

do_safe_home_cycle() {
    local prefix="$1"
    local sec="$2"
    local log_mode="$3"

    halcmd sets motion-req-x FALSE
    run_diag "${prefix}_safe_start" "${log_mode}"

    halcmd sets home-req-x TRUE
    run_diag "${prefix}_home_on" "${log_mode}"

    sleep "${sec}"
    run_diag "${prefix}_home_stable" "${log_mode}"

    halcmd sets home-req-x FALSE
    run_diag "${prefix}_home_off" "${log_mode}"

    sleep "${sec}"
    run_diag "${prefix}_back_to_safe" "${log_mode}"
}

do_csp_cycle() {
    local prefix="$1"
    local sec="$2"
    local log_mode="$3"

    halcmd sets motion-req-x FALSE
    run_diag "${prefix}_safe_start" "${log_mode}"

    halcmd sets motion-req-x TRUE
    run_diag "${prefix}_csp_on" "${log_mode}"

    sleep "${sec}"
    run_diag "${prefix}_csp_stable" "${log_mode}"

    halcmd sets motion-req-x FALSE
    run_diag "${prefix}_csp_off" "${log_mode}"

    sleep "${sec}"
    run_diag "${prefix}_back_to_safe" "${log_mode}"
}

do_mixed_cycle() {
    local prefix="$1"
    local sec="$2"
    local log_mode="$3"

    do_csp_cycle "${prefix}_01_csp" "${sec}" "${log_mode}"

    halcmd sets motion-req-x TRUE
    sleep "${sec}"
    do_home_cycle "${prefix}_02_home_from_csp" "${sec}" "${log_mode}"

    do_safe_home_cycle "${prefix}_03_home_from_safe" "${sec}" "${log_mode}"

    run_diag "${prefix}_final_state" "${log_mode}"
}

case "${ACTION}" in
    snapshot)
        run_diag "${STEP}" "${ARG3}"
        ;;
    motion-on)
        halcmd sets motion-req-x TRUE
        run_diag "${STEP}" "${ARG3}"
        ;;
    motion-off)
        halcmd sets motion-req-x FALSE
        run_diag "${STEP}" "${ARG3}"
        ;;
    home-on)
        halcmd sets home-req-x TRUE
        run_diag "${STEP}" "${ARG3}"
        ;;
    home-off)
        halcmd sets home-req-x FALSE
        run_diag "${STEP}" "${ARG3}"
        ;;
    wait-snapshot)
        SEC="${ARG3:-1}"
        LOG_MODE="${ARG4:-stdout}"
        sleep "${SEC}"
        run_diag "${STEP}" "${LOG_MODE}"
        ;;
    home-cycle)
        PREFIX="${STEP}"
        SEC="${ARG3:-1}"
        LOG_MODE="${ARG4:-stdout}"
        do_home_cycle "${PREFIX}" "${SEC}" "${LOG_MODE}"
        ;;
    safe-home-cycle)
        PREFIX="${STEP}"
        SEC="${ARG3:-1}"
        LOG_MODE="${ARG4:-stdout}"
        do_safe_home_cycle "${PREFIX}" "${SEC}" "${LOG_MODE}"
        ;;
    csp-cycle)
        PREFIX="${STEP}"
        SEC="${ARG3:-1}"
        LOG_MODE="${ARG4:-stdout}"
        do_csp_cycle "${PREFIX}" "${SEC}" "${LOG_MODE}"
        ;;
    mixed-cycle)
        PREFIX="${STEP}"
        SEC="${ARG3:-1}"
        LOG_MODE="${ARG4:-stdout}"
        do_mixed_cycle "${PREFIX}" "${SEC}" "${LOG_MODE}"
        ;;
    mixed-loop)
        PREFIX="${STEP}"
        COUNT="${ARG3:-3}"
        SEC="${ARG4:-1}"
        LOG_MODE="${ARG5:-stdout}"

        i=1
        while [ "${i}" -le "${COUNT}" ]; do
            do_mixed_cycle "$(printf "%s_iter_%02d" "${PREFIX}" "${i}")" "${SEC}" "${LOG_MODE}"
            i=$((i + 1))
        done

        run_diag "${PREFIX}_loop_final_state" "${LOG_MODE}"
        ;;
    sleep)
        SEC="${2:-1}"
        sleep "${SEC}"
        ;;
    *)
        usage
        ;;
esac
