#!/usr/bin/env bash

# ============================================================
#  CiA402 Framework Conformance Runner
# ============================================================
#
# Purpose:
# - validate profiles (YAML)
# - run HAL examples
# - collect diagnostics (diag.sh)
#
# No external dependencies required.
# Works with any Debian environment.
#
# ============================================================

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${BASE_DIR}/scripts"
PROFILES_DIR="${BASE_DIR}/profiles"
LOG_DIR="${BASE_DIR}/logs"

VALIDATOR="${SCRIPTS_DIR}/validate_profile.sh"
DIAG="${SCRIPTS_DIR}/diag.sh"

mkdir -p "${LOG_DIR}"

timestamp() {
  date +"%Y%m%d_%H%M%S"
}

log() {
  echo "[RUNNER] $*"
}

error() {
  echo "[ERROR] $*" >&2
}

# ============================================================
# STEP 1 — VALIDATE PROFILES
# ============================================================

run_validator() {
  log "Running profile validation..."

  if [[ ! -f "$VALIDATOR" ]]; then
    error "validate_profile.sh not found"
    return 1
  fi

  "$VALIDATOR" "${PROFILES_DIR}" | tee "${LOG_DIR}/validator_$(timestamp).log"
}

# ============================================================
# STEP 2 — RUN DIAG
# ============================================================

run_diag() {
  local mode="$1"

  if [[ ! -f "$DIAG" ]]; then
    error "diag.sh not found"
    return 1
  fi

  log "Running diag (${mode})..."

  "$DIAG" "$mode" stdout | tee "${LOG_DIR}/diag_${mode}_$(timestamp).log"
}

# ============================================================
# STEP 3 — HAL TEST EXECUTION (MANUAL TRIGGER)
# ============================================================

run_hal_note() {
  echo
  echo "--------------------------------------------------"
  echo "HAL EXECUTION STEP"
  echo "--------------------------------------------------"
  echo "Start LinuxCNC manually before running diag."
  echo
  echo "Examples:"
  echo
  echo "  Single-axis:"
  echo "    HALFILE = hal/examples/single_axis/example_single_axis_generic.hal"
  echo
  echo "  Multi-axis:"
  echo "    HALFILE = hal/examples/multi_axis/example_multi_axis_generic_xy.hal"
  echo
  echo "--------------------------------------------------"
  echo
}

# ============================================================
# MAIN
# ============================================================

MODE="${1:-all}"

echo "============================================================"
echo "        CiA402 Framework Conformance Runner"
echo "============================================================"
echo

case "$MODE" in
  validate)
    run_validator
    ;;

  single)
    run_diag single
    ;;

  multi)
    run_diag multi
    ;;

  all)
    run_validator
    run_hal_note
    run_diag single
    run_diag multi
    ;;

  *)
    echo "Usage:"
    echo "  runner.sh validate"
    echo "  runner.sh single"
    echo "  runner.sh multi"
    echo "  runner.sh all"
    exit 1
    ;;
esac

echo
echo "==================== DONE ===================="
echo
