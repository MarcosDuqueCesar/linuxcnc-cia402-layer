#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAG_SCRIPT="${SCRIPT_DIR}/diag_single_axis.sh"

PREFIX="${1:-monitor}"
COUNT="${2:-10}"
INTERVAL="${3:-60}"

i=1
while [ "${i}" -le "${COUNT}" ]; do
    STEP="$(printf "%s_%03d" "${PREFIX}" "${i}")"
    "${DIAG_SCRIPT}" "${STEP}" log
    sleep "${INTERVAL}"
    i=$((i + 1))
done
