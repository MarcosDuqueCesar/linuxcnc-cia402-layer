#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# COLORS
# --------------------------------------------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
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
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
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

clear_state() {
  rm -f "$STATE_FILE"
  SELECTED_PROFILE=""
  SELECTED_PROFILE_NAME=""
  SELECTED_PROFILE_VENDOR=""
  SELECTED_PROFILE_MODEL=""
  SELECTED_TOPOLOGY=""
  SELECTED_HAL=""
  SELECTED_INI=""
}

# --------------------------------------------------
# HELPERS
# --------------------------------------------------
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
fail() { echo -e "${RED}[FAIL]${RESET} $*" >&2; }
info() { echo -e "${CYAN}[INFO]${RESET} $*"; }

die() {
  fail "$*"
  exit 1
}

timestamp() {
  date "+%Y%m%d_%H%M%S"
}

run_with_log() {
  local name="$1"
  shift
  local file="${LOG_DIR}/${name}_$(timestamp).log"
  info "Logging to: $file"
  "$@" | tee "$file"
}

relpath() {
  local p="$1"
  if [[ "$p" == "${WORKSPACE}"* ]]; then
    echo "${p#$WORKSPACE/}"
  else
    echo "$p"
  fi
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || die "File not found: $path"
}

require_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "Directory not found: $path"
}

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    echo "$input"
  else
    echo "${WORKSPACE}/${input}"
  fi
}

basename_noext() {
  local x="$1"
  x="$(basename "$x")"
  x="${x%.driver.yaml}"
  x="${x%.profile.yaml}"
  x="${x%.yaml}"
  echo "$x"
}

print_status_hints() {
  local any_missing=0

  if [[ -z "$SELECTED_PROFILE" ]]; then
    any_missing=1
  fi
  if [[ -z "$SELECTED_TOPOLOGY" ]]; then
    any_missing=1
  fi
  if [[ -z "$SELECTED_HAL" ]]; then
    any_missing=1
  fi

  if [[ "$any_missing" -eq 0 ]]; then
    return 0
  fi

  echo
  echo "Hints:"

  if [[ -z "$SELECTED_PROFILE" ]]; then
    echo "  - List profiles:   scripts/framework.sh list-profiles"
    echo "  - Select one:      scripts/framework.sh set-profile <path>"
  fi

  if [[ -z "$SELECTED_TOPOLOGY" ]]; then
    echo "  - Set topology:    scripts/framework.sh set-topology <single_axis|multi_axis|gantry>"
  fi

  if [[ -z "$SELECTED_HAL" ]]; then
    echo "  - List HAL:        scripts/framework.sh list-hal"
    echo "  - Select HAL:      scripts/framework.sh set-hal <path>"
  fi

  if [[ -z "$SELECTED_INI" ]]; then
    echo "  - Optional INI:    scripts/framework.sh set-ini <path-to-your-linuxcnc-ini>"
  fi

  if [[ -n "$SELECTED_PROFILE" ]]; then
    echo "  - Try suggestions: scripts/framework.sh suggest"
    echo "  - Apply them:      scripts/framework.sh apply-suggestions"
  fi
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
    BEGIN { in_identity=0 }
    /^identity:/ { in_identity=1; next }
    in_identity && /^[^[:space:]]/ { in_identity=0 }
    in_identity && $1 == want ":" {
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

  SELECTED_PROFILE_NAME="$(profile_read_field name || true)"
  SELECTED_PROFILE_VENDOR="$(profile_read_field vendor || true)"
  SELECTED_PROFILE_MODEL="$(profile_read_field model || true)"
}

# --------------------------------------------------
# SUGGESTION LOGIC
# --------------------------------------------------
suggest_topology_from_path() {
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
  [[ -d "${HAL_DIR}/examples" ]] || return 1

  local profile_base vendor match
  profile_base="$(basename_noext "$SELECTED_PROFILE")"
  vendor="$SELECTED_PROFILE_VENDOR"

  match="$(find "${HAL_DIR}/examples" -type f -name "*${profile_base}*.hal" 2>/dev/null | head -n 1)"
  [[ -n "$match" ]] && { echo "$match"; return 0; }

  if [[ -n "$vendor" ]]; then
    match="$(find "${HAL_DIR}/examples" -type f -name "*${vendor}*.hal" 2>/dev/null | head -n 1)"
    [[ -n "$match" ]] && { echo "$match"; return 0; }
  fi

  match="$(find "${HAL_DIR}/examples/single_axis" -type f -name "example_single_axis_generic.hal" 2>/dev/null | head -n 1)"
  [[ -n "$match" ]] && { echo "$match"; return 0; }

  return 1
}

suggest_ini_for_profile() {
  profile_present || return 1
  [[ -d "${INI_DIR}" ]] || return 1

  echo "INI is user-specific."
  echo ""
  echo "Use your own LinuxCNC INI and include:"
  echo ""
  echo "  HALFILE = <your_host_hal>"
  echo "  HALFILE = hal/examples/..."
  echo ""
  echo "Examples available:"
  find "${INI_DIR}/examples" -maxdepth 1 -type f -name "*.ini" 2>/dev/null | sed "s|^${WORKSPACE}/||"

  return 0
}

# --------------------------------------------------
# REPORTING
# --------------------------------------------------
print_status() {
  echo "Framework status"
  echo "workspace: ${WORKSPACE}"
  echo

  if [[ -n "$SELECTED_PROFILE" ]]; then
    ok "Profile: $(relpath "$SELECTED_PROFILE")"
    echo "  name   : ${SELECTED_PROFILE_NAME:-<unknown>}"
    echo "  vendor : ${SELECTED_PROFILE_VENDOR:-<unknown>}"
    echo "  model  : ${SELECTED_PROFILE_MODEL:-<unknown>}"
  else
    warn "Profile: not selected"
  fi

  if [[ -n "$SELECTED_TOPOLOGY" ]]; then
    ok "Topology: ${SELECTED_TOPOLOGY}"
  else
    warn "Topology: not selected"
  fi

  if [[ -n "$SELECTED_HAL" ]]; then
    ok "HAL: $(relpath "$SELECTED_HAL")"
  else
    warn "HAL: not selected"
  fi

  if [[ -n "$SELECTED_INI" ]]; then
    ok "INI: $(relpath "$SELECTED_INI")"
  else
    info "INI: not selected (optional, user-specific)"
  fi

  print_status_hints
}

print_suggestions() {
  if ! profile_present; then
    die "No profile selected"
  fi

  local suggested_hal suggested_ini suggested_topology
  suggested_hal="$(suggest_hal_for_profile || true)"
  suggested_ini="$(suggest_ini_for_profile || true)"

  if [[ -n "$suggested_hal" ]]; then
    suggested_topology="$(suggest_topology_from_path "$suggested_hal")"
  elif [[ -n "$suggested_ini" ]]; then
    suggested_topology="$(suggest_topology_from_path "$suggested_ini")"
  else
    suggested_topology=""
  fi

  echo "Suggestions for selected profile"
  echo
  echo "Profile:"
  echo "  file   : $(relpath "$SELECTED_PROFILE")"
  echo "  name   : ${SELECTED_PROFILE_NAME:-<unknown>}"
  echo "  vendor : ${SELECTED_PROFILE_VENDOR:-<unknown>}"
  echo "  model  : ${SELECTED_PROFILE_MODEL:-<unknown>}"
  echo

  [[ -n "$suggested_topology" ]] && ok "Suggested topology: $suggested_topology" || warn "Suggested topology: none"
  [[ -n "$suggested_hal" ]] && ok "Suggested HAL: $(relpath "$suggested_hal")" || warn "Suggested HAL: none"
if [[ -n "$suggested_ini" ]]; then
  info "INI guidance:"
  echo "$suggested_ini"
else
  info "INI guidance: none"
fi
}

cross_check() {
  echo "Selection cross-check"
  echo

  [[ -z "$SELECTED_PROFILE" ]] && warn "No profile selected"
  [[ -z "$SELECTED_HAL" ]] && warn "No HAL selected"
  [[ -z "$SELECTED_TOPOLOGY" ]] && warn "No topology selected"
  [[ -z "$SELECTED_INI" ]] && info "No INI selected (optional)"
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
    if [[ "$SELECTED_HAL" == *"${SELECTED_PROFILE_VENDOR}"* || "$SELECTED_HAL" == *"$(basename_noext "$SELECTED_PROFILE")"* ]]; then
      ok "HAL appears consistent with selected profile"
    else
      warn "HAL does not obviously match selected profile"
    fi
  fi

  if profile_present && [[ -n "$SELECTED_INI" ]]; then
    if [[ "$SELECTED_INI" == *"${SELECTED_PROFILE_VENDOR}"* || "$SELECTED_INI" == *"$(basename_noext "$SELECTED_PROFILE")"* ]]; then
      ok "INI appears consistent with selected profile"
    else
      warn "INI does not obviously match selected profile"
    fi
  fi
}

# --------------------------------------------------
# LIST COMMANDS
# --------------------------------------------------
list_profiles() {
  local category="${1:-}"

  case "$category" in
    "")
      find "${PROFILES_DIR}" \
        \( -path "${PROFILES_DIR}/driver/*.yaml" \
        -o -path "${PROFILES_DIR}/reference/*.yaml" \
        -o -path "${PROFILES_DIR}/validated/*.yaml" \) \
        -type f | sort | sed "s|^${WORKSPACE}/||"
      ;;
    driver|reference|validated)
      require_dir "${PROFILES_DIR}/${category}"
      find "${PROFILES_DIR}/${category}" -maxdepth 1 -type f -name "*.yaml" | sort | sed "s|^${WORKSPACE}/||"
      ;;
    *)
      die "Invalid profile category: $category (expected: driver, reference, or validated)"
      ;;
  esac
}

list_hal() {
  local topology="${1:-}"
  require_dir "${HAL_DIR}/examples"

  if [[ -n "$topology" ]]; then
    require_dir "${HAL_DIR}/examples/${topology}"
    find "${HAL_DIR}/examples/${topology}" -maxdepth 1 -type f -name "*.hal" | sort | sed "s|^${WORKSPACE}/||"
  else
    find "${HAL_DIR}/examples" -maxdepth 2 -type f -name "*.hal" | sort | sed "s|^${WORKSPACE}/||"
  fi
}

list_ini() {
  local topology="${1:-}"

  if [[ ! -d "${INI_DIR}" ]]; then
    warn "No ini/ directory found in workspace"
    return 0
  fi

  if [[ -n "$topology" ]]; then
    if [[ ! -d "${INI_DIR}/${topology}" ]]; then
      warn "No ini directory for topology: ${topology}"
      return 0
    fi
    find "${INI_DIR}/${topology}" -maxdepth 1 -type f -name "*.ini" | sort | sed "s|^${WORKSPACE}/||"
  else
    find "${INI_DIR}" -maxdepth 3 -type f -name "*.ini" | sort | sed "s|^${WORKSPACE}/||"
  fi
}

# --------------------------------------------------
# SELECT COMMANDS
# --------------------------------------------------
set_profile() {
  local input="$1"
  local resolved
  resolved="$(resolve_path "$input")"
  require_file "$resolved"

  SELECTED_PROFILE="$resolved"
  load_profile_metadata
  save_state
  ok "Profile selected: $(relpath "$SELECTED_PROFILE")"
}

set_topology() {
  local topology="$1"
  case "$topology" in
    single_axis|multi_axis|gantry) ;;
    *) die "Invalid topology: $topology" ;;
  esac

  SELECTED_TOPOLOGY="$topology"
  save_state
  ok "Topology selected: $SELECTED_TOPOLOGY"
}

set_hal() {
  local input="$1"
  local resolved
  resolved="$(resolve_path "$input")"
  require_file "$resolved"

  SELECTED_HAL="$resolved"
  save_state
  ok "HAL selected: $(relpath "$SELECTED_HAL")"
}

set_ini() {
  local input="$1"
  local resolved
  resolved="$(resolve_path "$input")"
  require_file "$resolved"

  SELECTED_INI="$resolved"
  save_state
  ok "INI selected: $(relpath "$SELECTED_INI")"
}

apply_suggestions() {
  if ! profile_present; then
    die "No profile selected"
  fi

  local suggested_hal suggested_ini suggested_topology
  suggested_hal="$(suggest_hal_for_profile || true)"
  suggested_ini="$(suggest_ini_for_profile || true)"

  if [[ -n "$suggested_hal" ]]; then
    suggested_topology="$(suggest_topology_from_path "$suggested_hal")"
  elif [[ -n "$suggested_ini" ]]; then
    suggested_topology="$(suggest_topology_from_path "$suggested_ini")"
  else
    suggested_topology=""
  fi

  [[ -n "$suggested_topology" ]] && SELECTED_TOPOLOGY="$suggested_topology"
  [[ -n "$suggested_hal" ]] && SELECTED_HAL="$suggested_hal"
  [[ -n "$suggested_ini" ]] && SELECTED_INI="$suggested_ini"

  save_state
  ok "Suggestions applied"
  print_status
}

# --------------------------------------------------
# WRAPPERS FOR EXISTING TOOLS
# --------------------------------------------------
run_diag() {
  local mode="${1:-auto}"
  local output="${2:-stdout}"
  "${SCRIPTS_DIR}/diag.sh" "$mode" "$output"
}

run_validate_profile() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    if profile_present; then
      target="$SELECTED_PROFILE"
    else
      die "No profile provided and no profile selected"
    fi
  else
    target="$(resolve_path "$target")"
  fi

  require_file "$target"
  "${SCRIPTS_DIR}/validate_profile.sh" "$target"
}

run_validate_driver_profile() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    if profile_present; then
      target="$SELECTED_PROFILE"
    else
      die "No profile provided and no profile selected"
    fi
  else
    target="$(resolve_path "$target")"
  fi

  require_file "$target"
  "${SCRIPTS_DIR}/validate_driver_profile.sh" "$target"
}

run_tests() {
  "${SCRIPTS_DIR}/run_tests.sh"
}

# --------------------------------------------------
# USAGE
# --------------------------------------------------
usage() {
  cat <<EOF
LinuxCNC CiA402 Framework CLI

Usage:
  scripts/framework.sh <command> [args]

Commands:
  help
  status
  clear-state

  list-profiles [driver|reference|validated]
  list-hal [single_axis|multi_axis|gantry]
  list-ini [single_axis|multi_axis|gantry]

  set-profile <path>
  set-topology <single_axis|multi_axis|gantry>
  set-hal <path>
  set-ini <path>

  suggest
  apply-suggestions
  cross-check

  diag [auto|single|multi] [stdout|log]
  validate-profile [path]
  validate-driver-profile [path]
  run-tests

Examples:
  scripts/framework.sh status
  scripts/framework.sh list-profiles
  scripts/framework.sh list-profiles driver
  scripts/framework.sh set-profile profiles/driver/leadshine_el7_ec.driver.yaml
  scripts/framework.sh set-topology single_axis
  scripts/framework.sh set-hal hal/examples/single_axis/example_single_axis_generic.hal
  scripts/framework.sh set-ini /path/to/your/linuxcnc/config.ini
  scripts/framework.sh suggest
  scripts/framework.sh apply-suggestions
  scripts/framework.sh cross-check
  scripts/framework.sh diag
  scripts/framework.sh diag auto log
  scripts/framework.sh validate-profile
  scripts/framework.sh validate-driver-profile
  scripts/framework.sh run-tests

Notes:
  - State is stored in: ${STATE_FILE}
  - INI selection is optional and user-specific.
  - Gantry remains experimental.
  - This CLI does not modify HAL wiring by itself.
EOF
}

# --------------------------------------------------
# MAIN
# --------------------------------------------------
load_state
load_profile_metadata

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    usage
    ;;
  status)
    print_status
    ;;
  clear-state)
    clear_state
    ok "Framework state cleared"
    ;;
  list-profiles)
    list_profiles "${1:-}"
    ;;
  list-hal)
    list_hal "${1:-}"
    ;;
  list-ini)
    list_ini "${1:-}"
    ;;
  set-profile)
    [[ $# -ge 1 ]] || die "set-profile requires a path"
    set_profile "$1"
    ;;
  set-topology)
    [[ $# -ge 1 ]] || die "set-topology requires a topology"
    set_topology "$1"
    ;;
  set-hal)
    [[ $# -ge 1 ]] || die "set-hal requires a path"
    set_hal "$1"
    ;;
  set-ini)
    [[ $# -ge 1 ]] || die "set-ini requires a path"
    set_ini "$1"
    ;;
  suggest)
    print_suggestions
    ;;
  apply-suggestions)
    apply_suggestions
    ;;
  cross-check)
    cross_check
    ;;
  diag)
    run_diag "${1:-auto}" "${2:-stdout}"
    ;;
  validate-profile)
    run_validate_profile "${1:-}"
    ;;
  validate-driver-profile)
    run_validate_driver_profile "${1:-}"
    ;;
  run-tests)
    run_tests
    ;;
  *)
    fail "Unknown command: $cmd"
    echo
    usage
    exit 2
    ;;
esac
