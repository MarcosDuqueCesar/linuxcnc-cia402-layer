#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 [x|y|all] [stdout|file]

Examples:
  $0 x
  $0 y file
  $0 all file
USAGE
}

axis_arg="${1:-all}"
out_mode="${2:-stdout}"

case "$axis_arg" in
  x|X) axes=(x) ;;
  y|Y) axes=(y) ;;
  all|ALL) axes=(x y z) ;;
  *) usage >&2; exit 1 ;;
esac

case "$out_mode" in
  stdout|file) ;;
  *) usage >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/logs"
TS="$(date '+%Y%m%d_%H%M%S')"
OUT_FILE="${OUT_DIR}/obs_snapshot_${axis_arg}_${TS}.txt"
mkdir -p "$OUT_DIR"

getv() {
  local target="$1"
  halcmd getp "$target" 2>/dev/null || echo "<absent>"
}

emit_axis() {
  local a="$1"
  local A="${a^^}"

  echo "============================================================"
  echo "OBSERVABILITY SNAPSHOT :: AXIS ${A}"
  echo "DATE : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================================"
  echo

  echo "[NORMAL MODE :: CORE]"
  echo "mux-sel-home-${a}=$(getv "mux-sel-home-${a}")"
  echo "mux-sel-csp-${a}=$(getv "mux-sel-csp-${a}")"
  echo "mcsp-owner-${a}=$(getv "mcsp-owner-${a}")"
  echo "mcsp-ready-${a}=$(getv "mcsp-ready-${a}")"
  echo "ut-owner-${a}=$(getv "ut-owner-${a}")"
  echo "ut-state-${a}=$(getv "ut-state-${a}")"
  echo "pds-op-enabled-${a}=$(getv "pds-op-enabled-${a}")"
  echo "sw-${a}=$(getv "sw-${a}")"
  echo "omd-${a}=$(getv "omd-${a}")"
  echo "ap-${a}=$(getv "ap-${a}")"
  echo

  echo "[NORMAL MODE :: MOTION WATCHDOG]"
  echo "motion-watchdog-fault-${a}=$(getv "motion-watchdog-fault-${a}")"
  echo "motion-watchdog-latched-${a}=$(getv "motion-watchdog-latched-${a}")"
  echo "motion-watchdog-code-${a}=$(getv "motion-watchdog-code-${a}")"
  echo "motion-watchdog-response-${a}=$(getv "motion-watchdog-response-${a}")"
  echo "motion-watchdog-stall-${a}=$(getv "motion-watchdog-stall-${a}")"
  echo "motion-watchdog-trackerr-${a}=$(getv "motion-watchdog-trackerr-${a}")"
  echo

  echo "[NORMAL MODE :: HOME WATCHDOG]"
  echo "home-watchdog-fault-${a}=$(getv "home-watchdog-fault-${a}")"
  echo "home-watchdog-latched-${a}=$(getv "home-watchdog-latched-${a}")"
  echo "home-watchdog-code-${a}=$(getv "home-watchdog-code-${a}")"
  echo

  echo "[DIAGNOSTIC MODE :: INVARIANT MONITOR]"
  echo "invmon-err-latched-${a}=$(getv "invmon-err-latched-${a}")"
  echo "invmon-err-count-${a}=$(getv "invmon-err-count-${a}")"
  echo "invmon-first-error-code-${a}=$(getv "invmon-first-error-code-${a}")"
  echo "invmon-err-mux-conflict-${a}=$(getv "invmon-err-mux-conflict-${a}")"
  echo "invmon-err-csp-without-owner-${a}=$(getv "invmon-err-csp-without-owner-${a}")"
  echo "invmon-err-home-without-owner-${a}=$(getv "invmon-err-home-without-owner-${a}")"
  echo "invmon-err-ready-without-owner-${a}=$(getv "invmon-err-ready-without-owner-${a}")"
  echo
}

emit_all() {
  echo "===== OBSERVABILITY SNAPSHOT ====="
  echo "axes=${axes[*]}"
  echo "mode=${out_mode}"
  echo
  for a in "${axes[@]}"; do
    emit_axis "$a"
  done
}

if [[ "$out_mode" == "file" ]]; then
  emit_all | tee "$OUT_FILE"
  echo "Saved: $OUT_FILE"
else
  emit_all
fi
