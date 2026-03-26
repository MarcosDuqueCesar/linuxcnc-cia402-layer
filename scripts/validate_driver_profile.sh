#!/usr/bin/env bash

set -euo pipefail

PROFILE="${1:-}"
SCHEMA="${2:-}"
RUNTIME_CHECK=false

if [[ "${3:-}" == "--runtime" ]]; then
  RUNTIME_CHECK=true
fi

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

fail=0

error() {
  echo -e "${RED}ERROR: $1${NC}"
  fail=1
}

warn() {
  echo -e "${YELLOW}WARN: $1${NC}"
}

pass() {
  echo -e "${GREEN}$1${NC}"
}

if [[ -z "$PROFILE" || -z "$SCHEMA" ]]; then
  error "usage: validate_driver_profile.sh <profile.yaml> <schema.yaml> [--runtime]"
  exit 1
fi

if [[ ! -f "$PROFILE" ]]; then
  error "profile not found: $PROFILE"
  exit 1
fi

if [[ ! -f "$SCHEMA" ]]; then
  error "schema not found: $SCHEMA"
  exit 1
fi

PY_OUTPUT="$(
python3 - "$PROFILE" "$SCHEMA" <<'PYEOF'
import sys
import yaml

profile_path = sys.argv[1]
schema_path = sys.argv[2]

fail = False
errors = []

def error(msg):
    global fail
    errors.append(msg)

try:
    with open(profile_path, "r", encoding="utf-8") as f:
        profile = yaml.safe_load(f)
except Exception as e:
    print(f"PARSE_ERROR: failed to parse profile: {e}")
    sys.exit(2)

try:
    with open(schema_path, "r", encoding="utf-8") as f:
        schema = yaml.safe_load(f)
except Exception as e:
    print(f"PARSE_ERROR: failed to parse schema: {e}")
    sys.exit(2)

if not isinstance(profile, dict):
    print("PARSE_ERROR: profile root must be a mapping")
    sys.exit(2)

required_sections = [
    "identity",
    "contract",
    "capabilities",
    "backend_contract",
    "statusword_contract",
    "control_authority",
    "scaling",
    "axes",
    "integration_rules",
    "watchdog_semantics",
    "third_party_contract",
]

for sec in required_sections:
    if sec not in profile:
        error(f"missing section: {sec}")

mw = profile.get("watchdog_semantics", {}).get("motion_watchdog", {})
if mw.get("fault_is_instantaneous") is not True:
    error("fault_is_instantaneous must be true")

tpc = profile.get("third_party_contract", {})
if tpc.get("consumer_needs_internal_hal_knowledge") is not False:
    error("consumer_needs_internal_hal_knowledge must be false")

if tpc.get("profile_is_runtime_executable") is not False:
    error("profile_is_runtime_executable must be false")

if tpc.get("provides_integration_contract") is not True:
    error("provides_integration_contract must be true")

axes = profile.get("axes", {})
if not isinstance(axes, dict) or not axes:
    error("axes must be a non-empty mapping")

sc = profile.get("scaling", {})
if "per_axis_defaults" not in sc:
    error("scaling.per_axis_defaults missing")

if errors:
    for e in errors:
        print(f"ERROR: {e}")
    sys.exit(1)

axis_names = ", ".join(profile.get("axes", {}).keys())
print(f"AXES: {axis_names}")
sys.exit(0)
PYEOF
)"
PY_STATUS=$?

if [[ $PY_STATUS -eq 2 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && error "${line#PARSE_ERROR: }"
  done <<< "$PY_OUTPUT"
  echo -e "${RED}VALIDATION: FAIL${NC}"
  exit 1
elif [[ $PY_STATUS -ne 0 ]]; then
  while IFS= read -r line; do
    if [[ "$line" == ERROR:* ]]; then
      error "${line#ERROR: }"
    elif [[ -n "$line" ]]; then
      error "$line"
    fi
  done <<< "$PY_OUTPUT"
  echo -e "${RED}VALIDATION: FAIL${NC}"
  exit 1
fi

AXES_LINE="$(printf '%s\n' "$PY_OUTPUT" | grep '^AXES:' || true)"
AXES="${AXES_LINE#AXES: }"

if $RUNTIME_CHECK; then
  if ! command -v halcmd >/dev/null 2>&1; then
    warn "halcmd not available, skipping runtime checks"
  else
    pass "Running runtime checks..."

    if ! halcmd show thread | grep -q 'servo-thread'; then
      error "servo-thread not found"
    fi

    for axis in x y; do
      if ! halcmd show pin | grep -q "adapter_${axis}\.in-controlword"; then
        warn "adapter_${axis}.in-controlword not found in runtime"
      fi
    done
  fi
fi

if [[ $fail -eq 1 ]]; then
  echo -e "${RED}VALIDATION: FAIL${NC}"
  exit 1
fi

echo -e "${GREEN}VALIDATION: PASS${NC}"
echo "Profile: $PROFILE"
echo "Axes: $AXES"
echo "Schema: $SCHEMA"
