#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# PATH RESOLUTION (ROOT-INDEPENDENT)
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/.." && pwd)"

LOG_DIR="${WORKSPACE}/logs"
OUTBOX_DIR="${WORKSPACE}/outbox"

mkdir -p "$LOG_DIR" "$OUTBOX_DIR"

# --------------------------------------------------
# ARGS
# --------------------------------------------------
MODE="${1:-auto}"        # auto | single | multi
OUTPUT="${2:-stdout}"    # stdout | log

timestamp() {
  date "+%Y%m%d_%H%M%S"
}

logfile="${LOG_DIR}/diag_$(timestamp).log"

# --------------------------------------------------
# HELPERS
# --------------------------------------------------
print_param() {
  local param="$1"
  local label="${2:-$1}"

  if halcmd getp "$param" >/dev/null 2>&1; then
    printf "%-28s %s\n" "$label" "$(halcmd getp "$param" | tail -n1)"
  else
    printf "%-28s %s\n" "$label" "N/A"
  fi
}

print_axis_block() {
  local wd="$1"
  local axis_label="$2"

  echo "----- WATCHDOG: ${axis_label} (${wd}) -----"
  print_param "${wd}.fault" "fault"
  print_param "${wd}.fault-latched" "fault-latched"
  print_param "${wd}.first-fault-code" "first-fault-code"
  print_param "${wd}.stall" "stall"
  print_param "${wd}.response-timeout" "response-timeout"
  print_param "${wd}.pos-cmd" "pos-cmd"
  print_param "${wd}.pos-fb" "pos-fb"
  print_param "${wd}.motion-req" "motion-req"
  print_param "${wd}.armed" "armed"
  print_param "${wd}.tracking-error" "tracking-error"
  print_param "${wd}.tracking-error-limit" "tracking-error-limit"
  echo
}

discover_watchdogs() {
  local names=()
  local line
  local seen=""

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [[ "$seen" != *"|$line|"* ]]; then
      names+=("$line")
      seen="${seen}|$line|"
    fi
  done < <(
    halcmd show pin 2>/dev/null \
      | sed -n 's/.*\b\(motion_wd[^.[:space:]]*\)\..*/\1/p' \
      | sort
  )

  printf '%s\n' "${names[@]}"
}

axis_label_from_wd() {
  local wd="$1"

  case "$wd" in
    motion_wd)   echo "single" ;;
    motion_wd_x) echo "X" ;;
    motion_wd_y) echo "Y" ;;
    motion_wd_z) echo "Z" ;;
    motion_wd_a) echo "A" ;;
    motion_wd_b) echo "B" ;;
    motion_wd_c) echo "C" ;;
    motion_wd_u) echo "U" ;;
    motion_wd_v) echo "V" ;;
    motion_wd_w) echo "W" ;;
    *)           echo "$wd" ;;
  esac
}

print_cia402_raw() {
  echo "----- CiA402 (RAW) -----"
  halcmd show pin 2>/dev/null | grep -E "cia402|statusword|controlword|adapter_.*(controlword|statusword)|adapter\.(in-controlword|out-statusword)" || true
  echo
}

run_diag() {
  local watchdogs=()
  local wd
  local count=0

  mapfile -t watchdogs < <(discover_watchdogs)

  echo "===== DIAG START ====="
  echo "MODE=$MODE"
  echo

  if [ "${#watchdogs[@]}" -eq 0 ]; then
    echo "No motion watchdog instances found in HAL."
    echo
    print_cia402_raw
    echo "===== DIAG END ====="
    return 0
  fi

  echo "----- DISCOVERED WATCHDOGS -----"
  for wd in "${watchdogs[@]}"; do
    echo "$wd"
    count=$((count + 1))
  done
  echo

  echo "----- SUMMARY -----"
  echo "watchdog_count=$count"
  echo

  for wd in "${watchdogs[@]}"; do
    print_axis_block "$wd" "$(axis_label_from_wd "$wd")"
  done

  print_cia402_raw

  echo "===== DIAG END ====="
}

# --------------------------------------------------
# EXECUTION
# --------------------------------------------------
if [ "$OUTPUT" = "stdout" ]; then
  run_diag
else
  run_diag | tee "$logfile"
  echo
  echo "Log saved to: $logfile"
fi
