#!/usr/bin/env bash
set -u

STEP="${1:-snapshot}"
LOG_MODE="${2:-stdout}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TS="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/diag_single_axis_${TS}_${STEP}.log"

mkdir -p "${LOG_DIR}"

write_report() {
    echo
    echo "============================================================"
    echo "SINGLE AXIS DIAGNOSTIC :: ${STEP}"
    echo "DATE : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "PWD  : $(pwd)"
    echo "USER : $(whoami)"
    echo "============================================================"
    echo

    run_show() {
        local title="$1"
        shift
        echo "----- ${title} -----"
        "$@"
        local rc=$?
        echo
        if [ $rc -ne 0 ]; then
            echo "ERROR: command failed in '${title}' with return code ${rc}"
            echo
        fi
    }

    run_show "THREADS" halcmd show thread
    run_show "PIN MSG" halcmd show pin msg
    run_show "PIN UT" halcmd show pin ut
    run_show "PIN MCSP" halcmd show pin mcsp
    run_show "PIN MUX" halcmd show pin mux
    run_show "PIN STUB" halcmd show pin stub
    run_show "SIGNAL XPOS-CMD" halcmd show sig xpos-cmd
}

if [ "${LOG_MODE}" = "log" ]; then
    write_report | tee "${LOG_FILE}"
    echo "Log saved to: ${LOG_FILE}"
else
    write_report
fi
