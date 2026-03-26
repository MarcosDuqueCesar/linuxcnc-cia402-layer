#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROFILE_PATH="${PROFILE_PATH:-$WORKSPACE/profiles/stub_multi_xy.profile.yaml}"
SCHEMA_PATH="${SCHEMA_PATH:-$WORKSPACE/profiles/driver_profile.schema.yaml}"
VALIDATOR="${VALIDATOR:-$WORKSPACE/scripts/validate_driver_profile.sh}"
CTL_SCRIPT="${CTL_SCRIPT:-$WORKSPACE/scripts/single_axis_ctl.sh}"
DIAG_SCRIPT="${DIAG_SCRIPT:-$WORKSPACE/scripts/diag_single_axis.sh}"
CLEAR_MULTI_SCRIPT="${CLEAR_MULTI_SCRIPT:-$WORKSPACE/scripts/faultinj_clear_state_multi.sh}"
OUTDIR="${OUTDIR:-$WORKSPACE/test_runtime_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  NC=''
fi

declare -a SUMMARY_LINES=()
PASS_COUNT=0
FAIL_COUNT=0
INFO_COUNT=0

record_pass() {
  local stage="$1"
  SUMMARY_LINES+=("${stage}: PASS")
  PASS_COUNT=$((PASS_COUNT + 1))
}

record_fail() {
  local stage="$1"
  local msg="${2:-}"
  if [[ -n "$msg" ]]; then
    SUMMARY_LINES+=("${stage}: FAIL - ${msg}")
    echo -e "${RED}${stage}: FAIL - ${msg}${NC}"
  else
    SUMMARY_LINES+=("${stage}: FAIL")
    echo -e "${RED}${stage}: FAIL${NC}"
  fi
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

record_info() {
  local stage="$1"
  local msg="$2"
  SUMMARY_LINES+=("${stage}: INFO - ${msg}")
  echo -e "${YELLOW}${stage}: INFO - ${msg}${NC}"
  INFO_COUNT=$((INFO_COUNT + 1))
}

print_summary_and_exit() {
  local rc="${1:-0}"
  local zipfile="${OUTDIR}.zip"

  if command -v zip >/dev/null 2>&1; then
    (cd "$WORKSPACE" && zip -rq "$zipfile" "$(basename "$OUTDIR")") >/dev/null 2>&1 || true
  fi

  echo
  echo "=== FINAL SUMMARY ==="
  local line
  for line in "${SUMMARY_LINES[@]}"; do
    case "$line" in
      *": PASS")  echo -e "${GREEN}${line}${NC}" ;;
      *": FAIL"*) echo -e "${RED}${line}${NC}" ;;
      *": INFO"*) echo -e "${YELLOW}${line}${NC}" ;;
      *)          echo "$line" ;;
    esac
  done

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}FINAL RESULT: PASS${NC}"
  else
    echo -e "${RED}FINAL RESULT: FAIL${NC}"
  fi
  echo "PASS COUNT: $PASS_COUNT"
  echo "FAIL COUNT: $FAIL_COUNT"
  echo "INFO COUNT: $INFO_COUNT"
  if [[ -f "$zipfile" ]]; then
    echo "Bundle: $(basename "$zipfile")"
  fi
  exit "$rc"
}

require_file() {
  local path="$1"
  local label="$2"
  [[ -f "$path" ]] || { record_fail "$label" "missing file: $path"; print_summary_and_exit 1; }
}

require_exec() {
  local path="$1"
  local label="$2"
  [[ -x "$path" ]] || { record_fail "$label" "script not executable: $path"; print_summary_and_exit 1; }
}

runtime_loaded() {
  command -v halcmd >/dev/null 2>&1 && halcmd show thread 2>/dev/null | grep -q 'servo-thread'
}

get_axes() {
  python3 - "$PROFILE_PATH" <<'PYEOF'
import sys, yaml
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    p = yaml.safe_load(f)
axes = p.get("axes", {})
if isinstance(axes, dict):
    print(" ".join(axes.keys()))
else:
    print("")
PYEOF
}

getp_safe() {
  local pin="$1"
  halcmd getp "$pin" 2>/dev/null || echo "NA"
}

fault_script_for_axis() {
  local fault_kind="$1"
  local axis="$2"
  case "$fault_kind" in
    response_timeout) echo "$WORKSPACE/scripts/faultinj_test_response_timeout_${axis}.sh" ;;
    stall)            echo "$WORKSPACE/scripts/faultinj_test_stall_${axis}.sh" ;;
    tracking)         echo "$WORKSPACE/scripts/faultinj_test_tracking_${axis}.sh" ;;
    *)                return 1 ;;
  esac
}

axis_has_runtime_pins() {
  local axis="$1"
  halcmd show pin 2>/dev/null | grep -q "motion_wd_${axis}\.fault" &&
  halcmd show pin 2>/dev/null | grep -q "motion_wd_${axis}\.fault-latched" &&
  halcmd show pin 2>/dev/null | grep -q "motion_wd_${axis}\.response-timeout"
}

clear_state_all() {
  local logfile="$OUTDIR/clear_state_prebaseline.log"
  "$CLEAR_MULTI_SCRIPT" >"$logfile" 2>&1
}

baseline_axis() {
  local axis="$1"
  local logfile="$OUTDIR/baseline_${axis}.log"
  {
    echo "fault=$(getp_safe motion_wd_${axis}.fault)"
    echo "fault_latched=$(getp_safe motion_wd_${axis}.fault-latched)"
    echo "response_timeout=$(getp_safe motion_wd_${axis}.response-timeout)"
    echo "stall=$(getp_safe motion_wd_${axis}.stall)"
    echo "tracking_error=$(getp_safe motion_wd_${axis}.tracking-error)"
  } >"$logfile"
  grep -q '^fault=FALSE$' "$logfile" &&
  grep -q '^fault_latched=FALSE$' "$logfile"
}

running_axis() {
  local axis="$1"
  local logfile="$OUTDIR/running_${axis}.log"
  {
    halcmd sets "motion-req-${axis}" TRUE
    "$CTL_SCRIPT" sleep 0.2
    echo "motion_req=$(getp_safe motion_wd_${axis}.motion-req)"
    echo "fault=$(getp_safe motion_wd_${axis}.fault)"
    echo "fault_latched=$(getp_safe motion_wd_${axis}.fault-latched)"
    halcmd sets "motion-req-${axis}" FALSE
    "$CTL_SCRIPT" sleep 0.2
  } >"$logfile" 2>&1
  grep -q '^motion_req=TRUE$' "$logfile" &&
  grep -q '^fault=FALSE$' "$logfile" &&
  grep -q '^fault_latched=FALSE$' "$logfile"
}

diag_snapshot() {
  "$DIAG_SCRIPT" runner_snapshot log >"$OUTDIR/diag_snapshot.stdout.log" 2>&1
}

validate_response_timeout_semantics() {
  local axis="$1"
  local logfile="$2"

  # Robust event detection:
  # 1) prefer explicit table line with fault/lat/rto all TRUE
  # 2) accept explicit final-state/latch evidence if table format drifts
  local saw_event=0

  if grep -E '[[:space:]]TRUE[[:space:]]+TRUE[[:space:]]+TRUE[[:space:]]+FALSE[[:space:]]+4$' "$logfile" >/dev/null 2>&1; then
    saw_event=1
  fi

  if grep -F '[5/6] observe from idle-arm window (X)' "$logfile" >/dev/null 2>&1 || \
     grep -F '[5/6] observe from idle-arm window (Y)' "$logfile" >/dev/null 2>&1; then
    if grep -E '[[:space:]]TRUE[[:space:]]+TRUE[[:space:]]+TRUE' "$logfile" >/dev/null 2>&1; then
      saw_event=1
    fi
  fi

  local latched final_fault final_rto
  latched="$(getp_safe motion_wd_${axis}.fault-latched)"
  final_fault="$(getp_safe motion_wd_${axis}.fault)"
  final_rto="$(getp_safe motion_wd_${axis}.response-timeout)"

  {
    echo "semantic_check=fault_event_plus_latch_retention"
    echo "saw_event=$saw_event"
    echo "final_fault=$final_fault"
    echo "final_fault_latched=$latched"
    echo "final_response_timeout=$final_rto"
  } >> "$logfile"

  [[ "$saw_event" == "1" && "$latched" == "TRUE" ]]
}

run_fault_axis() {
  local fault_kind="$1"
  local axis="$2"
  local script_path logfile
  script_path="$(fault_script_for_axis "$fault_kind" "$axis")"
  logfile="$OUTDIR/${fault_kind}_${axis}.log"

  [[ -x "$script_path" ]] || return 2
  "$script_path" >"$logfile" 2>&1 || return 1

  case "$fault_kind" in
    response_timeout)
      validate_response_timeout_semantics "$axis" "$logfile"
      ;;
    *)
      return 3
      ;;
  esac
}

run_reset_axis() {
  local axis="$1"
  local logfile="$OUTDIR/reset_${axis}.log"

  "$CLEAR_MULTI_SCRIPT" >"$logfile" 2>&1 || return 1

  [[ "$(getp_safe motion_wd_${axis}.fault)" == "FALSE" ]] &&
  [[ "$(getp_safe motion_wd_${axis}.fault-latched)" == "FALSE" ]]
}

run_restore_axis() {
  local axis="$1"
  local logfile="$OUTDIR/restore_${axis}.log"

  {
    echo "response_timeout=$(getp_safe motion_wd_${axis}.response-timeout)"
    echo "fault=$(getp_safe motion_wd_${axis}.fault)"
    echo "fault_latched=$(getp_safe motion_wd_${axis}.fault-latched)"
    echo "motion_req=$(getp_safe motion_wd_${axis}.motion-req)"
  } >"$logfile"

  grep -q '^response_timeout=FALSE$' "$logfile" &&
  grep -q '^fault=FALSE$' "$logfile" &&
  grep -q '^fault_latched=FALSE$' "$logfile" &&
  grep -q '^motion_req=FALSE$' "$logfile"
}

echo "=== RUN TESTS (MULTI-AXIS OFFICIAL, ROBUST FAULT SEMANTICS) ==="
echo "Workspace: $WORKSPACE"
echo "Output dir: $(basename "$OUTDIR")"

require_file "$PROFILE_PATH" "PRECHECK"
require_file "$SCHEMA_PATH" "PRECHECK"
require_exec "$VALIDATOR" "PRECHECK"
require_exec "$CTL_SCRIPT" "PRECHECK"
require_exec "$DIAG_SCRIPT" "PRECHECK"
require_exec "$CLEAR_MULTI_SCRIPT" "PRECHECK"

echo "--- DRIVER PROFILE VALIDATION ---"
if "$VALIDATOR" "$PROFILE_PATH" "$SCHEMA_PATH" >"$OUTDIR/driver_profile_validation.log" 2>&1; then
  cat "$OUTDIR/driver_profile_validation.log"
  record_pass "DRIVER_PROFILE"
else
  cat "$OUTDIR/driver_profile_validation.log"
  record_fail "DRIVER_PROFILE" "validator returned non-zero"
  print_summary_and_exit 1
fi

AXES="$(get_axes)"
if [[ -z "${AXES// }" ]]; then
  record_fail "AXES" "no axes found in profile"
  print_summary_and_exit 1
fi
record_info "AXES" "$AXES"

if ! runtime_loaded; then
  record_info "RUNTIME" "servo-thread not loaded; only profile validation executed"
  print_summary_and_exit 0
fi
record_pass "RUNTIME"

echo "--- FAULT INJECTION PRECHECK ---"
for axis in $AXES; do
  if axis_has_runtime_pins "$axis"; then
    record_pass "FAULT_PRECHECK_${axis^^}"
  else
    record_fail "FAULT_PRECHECK_${axis^^}" "required runtime pins not present"
    print_summary_and_exit 1
  fi
done

echo "--- PRE-BASELINE CLEAR STATE ---"
if clear_state_all; then
  record_pass "PRECLEAR"
else
  record_fail "PRECLEAR" "faultinj_clear_state_multi.sh failed before baseline"
  print_summary_and_exit 1
fi

echo "--- BASELINE ---"
for axis in $AXES; do
  if baseline_axis "$axis"; then
    record_pass "BASELINE_${axis^^}"
  else
    record_fail "BASELINE_${axis^^}" "fault state not clean at start"
    print_summary_and_exit 1
  fi
done

echo "--- DIAGNOSTIC SNAPSHOT ---"
if diag_snapshot; then
  record_pass "DIAG_SNAPSHOT"
else
  record_fail "DIAG_SNAPSHOT" "diag_single_axis.sh returned non-zero"
  print_summary_and_exit 1
fi
record_info "DIAG_SCOPE" "diag_single_axis.sh is current workspace snapshot tool; not axis-parameterized"
record_info "FAULT_SEMANTICS" "response-timeout validated as event + latch retention, not persistent final active fault"

echo "--- RUNNING CHECK ---"
for axis in $AXES; do
  if running_axis "$axis"; then
    record_pass "RUNNING_${axis^^}"
  else
    record_fail "RUNNING_${axis^^}" "motion request path did not reach expected clean running state"
    print_summary_and_exit 1
  fi
done

echo "--- RESPONSE-TIMEOUT / RESET / RESTORE ---"
for axis in $AXES; do
  local_fault_script="$(fault_script_for_axis response_timeout "$axis")"
  if [[ ! -x "$local_fault_script" ]]; then
    record_fail "FAULT_RESPONSE_TIMEOUT_${axis^^}" "missing official fault script: $(basename "$local_fault_script")"
    print_summary_and_exit 1
  fi

  if run_fault_axis response_timeout "$axis"; then
    record_pass "FAULT_RESPONSE_TIMEOUT_${axis^^}"
  else
    record_fail "FAULT_RESPONSE_TIMEOUT_${axis^^}" "official fault script did not produce response-timeout event + final latch retention"
    print_summary_and_exit 1
  fi

  if run_reset_axis "$axis"; then
    record_pass "RESET_${axis^^}"
  else
    record_fail "RESET_${axis^^}" "faultinj_clear_state_multi.sh did not clear watchdog fault state"
    print_summary_and_exit 1
  fi

  if run_restore_axis "$axis"; then
    record_pass "RESTORE_${axis^^}"
  else
    record_fail "RESTORE_${axis^^}" "post-clear state not clean"
    print_summary_and_exit 1
  fi
done

print_summary_and_exit 0
