#!/usr/bin/env bash
set -uo pipefail

# --------------------------------------------------
# COLORS
# --------------------------------------------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
WHITE="\e[97m"
BOLD="\e[1m"
RESET="\e[0m"

# --------------------------------------------------
# WORKSPACE DETECTION
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/.." && pwd)"

DOCS_DIR="${WORKSPACE}/docs"
SCRIPTS_DIR="${WORKSPACE}/scripts"
PROFILES_DIR="${WORKSPACE}/profiles"
HAL_DIR="${WORKSPACE}/hal"
INI_DIR="${WORKSPACE}/ini"
LOG_DIR="${WORKSPACE}/logs"

STATE_FILE="${WORKSPACE}/.framework_state"

mkdir -p "$LOG_DIR"

# --------------------------------------------------
# STATE
# --------------------------------------------------
SELECTED_PROFILE=""
SELECTED_PROFILE_NAME=""
SELECTED_PROFILE_VENDOR=""
SELECTED_PROFILE_MODEL=""

SELECTED_TOPOLOGY=""
SELECTED_HAL=""
SELECTED_INI=""

load_state() {
  [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
}

save_state() {
  cat > "$STATE_FILE" <<EOF
SELECTED_PROFILE="${SELECTED_PROFILE}"
SELECTED_PROFILE_NAME="${SELECTED_PROFILE_NAME}"
SELECTED_PROFILE_VENDOR="${SELECTED_PROFILE_VENDOR}"
SELECTED_PROFILE_MODEL="${SELECTED_PROFILE_MODEL}"
SELECTED_TOPOLOGY="${SELECTED_TOPOLOGY}"
SELECTED_HAL="${SELECTED_HAL}"
SELECTED_INI="${SELECTED_INI}"
EOF
}

# --------------------------------------------------
# HELPERS
# --------------------------------------------------
header() {
  clear
  echo -e "${CYAN}============================================================${RESET}"
  echo -e "${WHITE}${BOLD}         LinuxCNC CIA402 Framework Tool${RESET}"
  echo -e "${CYAN}============================================================${RESET}"
  echo
}

pause() {
  echo
  read -rp "Press ENTER to continue..."
}

ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
fail() { echo -e "${RED}[FAIL]${RESET} $1"; }
info() { echo -e "${CYAN}[INFO]${RESET} $1"; }

script_exists() {
  [[ -f "$1" ]]
}

status_mark_file() {
  local path="$1"
  [[ -f "$path" ]] && echo -e "${GREEN}Found${RESET}" || echo -e "${RED}Missing${RESET}"
}

status_mark_dir() {
  local path="$1"
  [[ -d "$path" ]] && echo -e "${GREEN}Found${RESET}" || echo -e "${RED}Missing${RESET}"
}

timestamp() {
  date "+%Y%m%d_%H%M%S"
}

run_with_log() {
  local name="$1"
  shift
  local file="${LOG_DIR}/${name}_$(timestamp).log"
  info "Logging to: $file"
  echo
  "$@" | tee "$file"
  return 0
}

# --------------------------------------------------
# PROFILE PARSING
# shell-only, no external YAML parser
# --------------------------------------------------
profile_present() {
  [[ -n "$SELECTED_PROFILE" && -f "$SELECTED_PROFILE" ]]
}

profile_read_field() {
  local field="$1"
  awk -v want="$field" '
    BEGIN { in_profile=0 }
    /^profile:/ { in_profile=1; next }
    in_profile && /^[^[:space:]]/ { in_profile=0 }
    in_profile && $1 == want ":" {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print $0
      exit
    }
  ' "$SELECTED_PROFILE"
}

load_profile_metadata() {
  if ! profile_present; then
    SELECTED_PROFILE_NAME=""
    SELECTED_PROFILE_VENDOR=""
    SELECTED_PROFILE_MODEL=""
    return
  fi

  SELECTED_PROFILE_NAME="$(profile_read_field name)"
  SELECTED_PROFILE_VENDOR="$(profile_read_field vendor)"
  SELECTED_PROFILE_MODEL="$(profile_read_field model)"
}

basename_noext() {
  local x="$1"
  x="$(basename "$x")"
  echo "${x%.yaml}"
}

path_noext() {
  local x="$1"
  x="$(basename "$x")"
  echo "${x%.hal}"
}

# --------------------------------------------------
# STATUS PANEL
# --------------------------------------------------
status_panel() {
  echo -e "${CYAN}------------------------ [ STATUS ] ------------------------${RESET}"

  [[ -n "$SELECTED_PROFILE" ]] \
    && ok "Profile: ${SELECTED_PROFILE#$WORKSPACE/}" \
    || warn "Profile: not selected"

  [[ -n "$SELECTED_TOPOLOGY" ]] \
    && ok "Topology: $SELECTED_TOPOLOGY" \
    || warn "Topology: not selected"

  [[ -n "$SELECTED_HAL" ]] \
    && ok "HAL: ${SELECTED_HAL#$WORKSPACE/}" \
    || warn "HAL: not selected"

  [[ -n "$SELECTED_INI" ]] \
    && ok "INI: ${SELECTED_INI#$WORKSPACE/}" \
    || warn "INI: not selected"

  echo
}

# --------------------------------------------------
# PROFILE SELECTION
# --------------------------------------------------
select_profile_from_category() {
  local category="$1"
  local -a files

  mapfile -t files < <(find "${PROFILES_DIR}/${category}" -maxdepth 1 -name "*.yaml" 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No profiles found in profiles/${category}"
    pause
    return 2
  fi

  echo "Select profile:"
  for i in "${!files[@]}"; do
    echo "[$i] ${files[$i]#$WORKSPACE/}"
  done
  echo

  read -rp "Choice: " idx

  [[ -z "${files[$idx]:-}" ]] && {
    fail "Invalid selection"
    pause
    return 2
  }

  SELECTED_PROFILE="${files[$idx]}"
  load_profile_metadata
  ok "Profile selected"
  save_state
  pause
  return 0
}

select_profile_menu() {
  header
  echo "Select profile category:"
  echo "1) validated"
  echo "2) reference"
  echo "3) experimental"
  echo "0) Back"
  echo

  read -rp "Choice: " opt
  case "$opt" in
    1) select_profile_from_category "validated" ;;
    2) select_profile_from_category "reference" ;;
    3) select_profile_from_category "experimental" ;;
    0) return ;;
    *)
      fail "Invalid option"
      pause
      ;;
  esac
}

# --------------------------------------------------
# TOPOLOGY
# --------------------------------------------------
select_topology() {
  header
  echo "Select topology:"
  echo "1) single_axis"
  echo "2) multi_axis"
  echo "3) gantry"
  echo "0) Back"
  echo

  read -rp "Choice: " opt

  case "$opt" in
    1) SELECTED_TOPOLOGY="single_axis" ;;
    2) SELECTED_TOPOLOGY="multi_axis" ;;
    3) SELECTED_TOPOLOGY="gantry" ;;
    0) return ;;
    *)
      fail "Invalid option"
      pause
      return
      ;;
  esac

  ok "Topology selected: $SELECTED_TOPOLOGY"
  save_state
  pause
}

# --------------------------------------------------
# HAL / INI MANUAL SELECTION
# --------------------------------------------------
select_hal() {
  header

  [[ -z "$SELECTED_TOPOLOGY" ]] && {
    warn "Select topology first"
    pause
    return
  }

  mapfile -t files < <(find "${HAL_DIR}/examples/${SELECTED_TOPOLOGY}" -maxdepth 1 -name "*.hal" 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No HAL examples found for topology: $SELECTED_TOPOLOGY"
    pause
    return
  fi

  echo "Select HAL example:"
  for i in "${!files[@]}"; do
    echo "[$i] ${files[$i]#$WORKSPACE/}"
  done
  echo

  read -rp "Choice: " idx

  [[ -z "${files[$idx]:-}" ]] && {
    fail "Invalid selection"
    pause
    return
  }

  SELECTED_HAL="${files[$idx]}"
  ok "HAL selected"
  save_state
  pause
}

select_ini() {
  header

  [[ -z "$SELECTED_TOPOLOGY" ]] && {
    warn "Select topology first"
    pause
    return
  }

  mapfile -t files < <(find "${INI_DIR}/${SELECTED_TOPOLOGY}" -maxdepth 1 -name "*.ini" 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No INI files found for topology: $SELECTED_TOPOLOGY"
    pause
    return
  fi

  echo "Select INI:"
  for i in "${!files[@]}"; do
    echo "[$i] ${files[$i]#$WORKSPACE/}"
  done
  echo

  read -rp "Choice: " idx

  [[ -z "${files[$idx]:-}" ]] && {
    fail "Invalid selection"
    pause
    return
  }

  SELECTED_INI="${files[$idx]}"
  ok "INI selected"
  save_state
  pause
}

# --------------------------------------------------
# PROFILE-ASSISTED MATCHING
# --------------------------------------------------
suggest_topology_from_ini_or_hal() {
  local p="$1"
  case "$p" in
    *single_axis*) echo "single_axis" ;;
    *multi_axis*)  echo "multi_axis" ;;
    *gantry*)      echo "gantry" ;;
    *)             echo "" ;;
  esac
}

suggest_hal_for_profile() {
  profile_present || return 1

  local profile_base vendor match
  profile_base="$(basename_noext "$SELECTED_PROFILE")"
  vendor="$SELECTED_PROFILE_VENDOR"

  # 1) Try exact single-axis vendor-specific example
  match="$(find "${HAL_DIR}/examples" -name "*${profile_base}*.hal" 2>/dev/null | head -n 1)"
  [[ -n "$match" ]] && { echo "$match"; return 0; }

  # 2) Try vendor-only match
  if [[ -n "$vendor" ]]; then
    match="$(find "${HAL_DIR}/examples" -name "*${vendor}*.hal" 2>/dev/null | head -n 1)"
    [[ -n "$match" ]] && { echo "$match"; return 0; }
  fi

  # 3) Generic fallback
  match="$(find "${HAL_DIR}/examples/single_axis" -name "example_single_axis_generic.hal" 2>/dev/null | head -n 1)"
  [[ -n "$match" ]] && { echo "$match"; return 0; }

  return 1
}

suggest_ini_for_profile() {
  profile_present || return 1

  local profile_base vendor match
  profile_base="$(basename_noext "$SELECTED_PROFILE")"
  vendor="$SELECTED_PROFILE_VENDOR"

  # 1) Exact ini
  match="$(find "${INI_DIR}" -name "*${profile_base}*.ini" 2>/dev/null | head -n 1)"
  [[ -n "$match" ]] && { echo "$match"; return 0; }

  # 2) Vendor-based
  if [[ -n "$vendor" ]]; then
    match="$(find "${INI_DIR}" -name "*${vendor}*.ini" 2>/dev/null | head -n 1)"
    [[ -n "$match" ]] && { echo "$match"; return 0; }
  fi

  # 3) Generic fallback
  match="$(find "${INI_DIR}/single_axis" -name "single_axis_generic.ini" 2>/dev/null | head -n 1)"
  [[ -n "$match" ]] && { echo "$match"; return 0; }

  return 1
}

profile_assisted_setup() {
  header

  if ! profile_present; then
    warn "Select a profile first"
    pause
    return
  fi

  info "Profile-assisted setup"
  echo

  local suggested_hal suggested_ini suggested_topology
  suggested_hal="$(suggest_hal_for_profile || true)"
  suggested_ini="$(suggest_ini_for_profile || true)"

  [[ -n "$suggested_hal" ]] && suggested_topology="$(suggest_topology_from_ini_or_hal "$suggested_hal")"
  [[ -z "$suggested_topology" && -n "$suggested_ini" ]] && suggested_topology="$(suggest_topology_from_ini_or_hal "$suggested_ini")"

  echo "Profile:"
  echo "  name   : ${SELECTED_PROFILE_NAME:-<unknown>}"
  echo "  vendor : ${SELECTED_PROFILE_VENDOR:-<unknown>}"
  echo "  model  : ${SELECTED_PROFILE_MODEL:-<unknown>}"
  echo

  [[ -n "$suggested_topology" ]] \
    && ok "Suggested topology: $suggested_topology" \
    || warn "No topology suggestion available"

  [[ -n "$suggested_hal" ]] \
    && ok "Suggested HAL: ${suggested_hal#$WORKSPACE/}" \
    || warn "No HAL suggestion available"

  [[ -n "$suggested_ini" ]] \
    && ok "Suggested INI: ${suggested_ini#$WORKSPACE/}" \
    || warn "No INI suggestion available"

  echo
  echo "1) Accept all suggestions"
  echo "2) Accept topology only"
  echo "3) Accept HAL only"
  echo "4) Accept INI only"
  echo "5) Keep current selections"
  echo "0) Back"
  echo

  read -rp "Choice: " opt

  case "$opt" in
    1)
      [[ -n "$suggested_topology" ]] && SELECTED_TOPOLOGY="$suggested_topology"
      [[ -n "$suggested_hal" ]] && SELECTED_HAL="$suggested_hal"
      [[ -n "$suggested_ini" ]] && SELECTED_INI="$suggested_ini"
      ok "Suggestions applied"
      ;;
    2)
      [[ -n "$suggested_topology" ]] && SELECTED_TOPOLOGY="$suggested_topology"
      ok "Topology applied"
      ;;
    3)
      [[ -n "$suggested_hal" ]] && SELECTED_HAL="$suggested_hal"
      ok "HAL applied"
      ;;
    4)
      [[ -n "$suggested_ini" ]] && SELECTED_INI="$suggested_ini"
      ok "INI applied"
      ;;
    5)
      info "Keeping current selections"
      ;;
    0)
      return
      ;;
    *)
      fail "Invalid option"
      ;;
  esac

  save_state
  pause
}

# --------------------------------------------------
# CROSS-CHECKS
# --------------------------------------------------
cross_check_selections() {
  header
  echo "Selection cross-check"
  echo

  [[ -z "$SELECTED_PROFILE" ]] && warn "No profile selected"
  [[ -z "$SELECTED_HAL" ]] && warn "No HAL selected"
  [[ -z "$SELECTED_INI" ]] && warn "No INI selected"
  [[ -z "$SELECTED_TOPOLOGY" ]] && warn "No topology selected"

  echo

  if [[ -n "$SELECTED_TOPOLOGY" && -n "$SELECTED_HAL" ]]; then
    if [[ "$SELECTED_HAL" == *"/${SELECTED_TOPOLOGY}/"* ]]; then
      ok "HAL matches selected topology"
    else
      warn "HAL does not appear to match selected topology"
    fi
  fi

  if [[ -n "$SELECTED_TOPOLOGY" && -n "$SELECTED_INI" ]]; then
    if [[ "$SELECTED_INI" == *"/${SELECTED_TOPOLOGY}/"* ]]; then
      ok "INI matches selected topology"
    else
      warn "INI does not appear to match selected topology"
    fi
  fi

  if profile_present && [[ -n "$SELECTED_HAL" ]]; then
    if [[ -n "$SELECTED_PROFILE_VENDOR" && "$SELECTED_HAL" == *"${SELECTED_PROFILE_VENDOR}"* ]]; then
      ok "HAL appears vendor-consistent with selected profile"
    elif [[ "$SELECTED_HAL" == *"generic"* ]]; then
      warn "HAL is generic; vendor-specific match not enforced"
    else
      warn "HAL may not match selected profile vendor"
    fi
  fi

  if profile_present && [[ -n "$SELECTED_INI" ]]; then
    if [[ -n "$SELECTED_PROFILE_VENDOR" && "$SELECTED_INI" == *"${SELECTED_PROFILE_VENDOR}"* ]]; then
      ok "INI appears vendor-consistent with selected profile"
    elif [[ "$SELECTED_INI" == *"generic"* ]]; then
      warn "INI is generic; vendor-specific match not enforced"
    else
      warn "INI may not match selected profile vendor"
    fi
  fi

  pause
}

# --------------------------------------------------
# GUIDED WORKFLOW
# --------------------------------------------------
guided_workflow() {
  header
  info "Guided workflow"
  echo

  [[ -z "$SELECTED_TOPOLOGY" ]] && {
    warn "No topology selected"
    pause
    return
  }

  if [[ ! -f "${SCRIPTS_DIR}/diag.sh" ]]; then
    warn "diag.sh not found"
    pause
    return
  fi

  info "Running axis diagnostic..."
  if [[ "$SELECTED_TOPOLOGY" == "single_axis" ]]; then
    bash "${SCRIPTS_DIR}/diag.sh" single stdout || true
  else
    bash "${SCRIPTS_DIR}/diag.sh" multi stdout || true
  fi

  if [[ "$SELECTED_TOPOLOGY" == "gantry" ]]; then
    echo
    info "Selected topology is gantry"
    if [[ -f "${SCRIPTS_DIR}/gantry_diag.sh" ]]; then
      info "Running gantry diagnostic..."
      bash "${SCRIPTS_DIR}/gantry_diag.sh" || true
    else
      warn "gantry_diag.sh not available"
    fi
  fi

  pause
}

# --------------------------------------------------
# VALIDATE PROFILE
# --------------------------------------------------
run_validate_profile() {
  header

  if [[ ! -f "${SCRIPTS_DIR}/validate_profile.sh" ]]; then
    warn "validate_profile.sh not found"
    pause
    return
  fi

  if ! profile_present; then
    warn "Select a profile first"
    pause
    return
  fi

  bash "${SCRIPTS_DIR}/validate_profile.sh" "$SELECTED_PROFILE" || true
  pause
}

# --------------------------------------------------
# WORKSPACE INFO
# --------------------------------------------------
show_workspace() {
  header
  echo -e "${CYAN}--------------------- [ Workspace Info ] ---------------------${RESET}"
  echo

  printf " %-16s %s\n" "WORKSPACE:" "$WORKSPACE"
  printf " %-16s %s\n" "DOCS:"      "$DOCS_DIR"
  printf " %-16s %s\n" "SCRIPTS:"   "$SCRIPTS_DIR"
  printf " %-16s %s\n" "PROFILES:"  "$PROFILES_DIR"
  printf " %-16s %s\n" "HAL:"       "$HAL_DIR"
  printf " %-16s %s\n" "INI:"       "$INI_DIR"
  printf " %-16s %s\n" "LOGS:"      "$LOG_DIR"
  echo

  printf " %-24s %b\n" "docs/:"                "$(status_mark_dir "${DOCS_DIR}")"
  printf " %-24s %b\n" "scripts/:"             "$(status_mark_dir "${SCRIPTS_DIR}")"
  printf " %-24s %b\n" "profiles/:"            "$(status_mark_dir "${PROFILES_DIR}")"
  printf " %-24s %b\n" "hal/:"                 "$(status_mark_dir "${HAL_DIR}")"
  printf " %-24s %b\n" "ini/:"                 "$(status_mark_dir "${INI_DIR}")"
  printf " %-24s %b\n" "logs/:"                "$(status_mark_dir "${LOG_DIR}")"
  printf " %-24s %b\n" "diag.sh:"              "$(status_mark_file "${SCRIPTS_DIR}/diag.sh")"
  printf " %-24s %b\n" "validate_profile.sh:"  "$(status_mark_file "${SCRIPTS_DIR}/validate_profile.sh")"
  printf " %-24s %b\n" "framework.sh:"         "$(status_mark_file "${SCRIPTS_DIR}/framework.sh")"
  printf " %-24s %b\n" "gantry_diag.sh:"       "$(status_mark_file "${SCRIPTS_DIR}/gantry_diag.sh")"
  echo

  pause
}

# --------------------------------------------------
# MAIN
# --------------------------------------------------
load_state
load_profile_metadata

while true; do
  header
  status_panel

  echo "1) Select profile"
  echo "2) Select topology"
  echo "3) Select HAL example"
  echo "4) Select INI"
  echo "5) Profile-assisted setup"
  echo "6) Cross-check selections"
  echo "7) Guided workflow"
  echo "8) Validate selected profile"
  echo "9) Show workspace"
  echo
  echo "0) Exit"
  echo

  read -rp "Select option: " opt

  case "$opt" in
    1) select_profile_menu ;;
    2) select_topology ;;
    3) select_hal ;;
    4) select_ini ;;
    5) profile_assisted_setup ;;
    6) cross_check_selections ;;
    7) guided_workflow ;;
    8) run_validate_profile ;;
    9) show_workspace ;;
    0) exit 0 ;;
    *)
      fail "Invalid option"
      pause
      ;;
  esac
done
