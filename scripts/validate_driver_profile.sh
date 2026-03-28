#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  validate_driver_profile.sh <profile.yaml> [--runtime]
EOF
}

[[ $# -ge 1 ]] || { echo "ERROR: missing profile"; usage; exit 1; }

FILE="$1"

[[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE"; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

# --------------------------------------------------
# REQUIRED TOP-LEVEL KEYS (from schema)
# --------------------------------------------------

require_key() {
  local key="$1"
  grep -Eq "^[[:space:]]*$key:" "$FILE" || fail "missing required key: $key"
}

require_key "profile_version"
require_key "profile_kind"
require_key "identity"
require_key "contract"
require_key "capabilities"
require_key "backend_contract"
require_key "statusword_contract"
require_key "control_authority"
require_key "scaling"
require_key "axes"
require_key "integration_rules"
require_key "watchdog_semantics"
require_key "third_party_contract"

# --------------------------------------------------
# BASIC VALUE CHECKS
# --------------------------------------------------

grep -Eq "^profile_kind:[[:space:]]*ciA402_driver_profile" "$FILE" \
  || fail "profile_kind must be ciA402_driver_profile"

grep -Eq "^[[:space:]]+name:" "$FILE" || fail "identity.name missing"
grep -Eq "^[[:space:]]+vendor:" "$FILE" || fail "identity.vendor missing"
grep -Eq "^[[:space:]]+model:" "$FILE" || fail "identity.model missing"

# --------------------------------------------------
# CONTRACT INTEGRITY
# --------------------------------------------------

grep -Eq "declarative_only:[[:space:]]*true" "$FILE" || fail "contract.declarative_only must be true"
grep -Eq "no_logic_inside_profile:[[:space:]]*true" "$FILE" || fail "contract.no_logic_inside_profile must be true"
grep -Eq "no_semantic_override:[[:space:]]*true" "$FILE" || fail "contract.no_semantic_override must be true"

# --------------------------------------------------
# BACKEND MINIMUM SIGNALS
# --------------------------------------------------

grep -q "controlword" "$FILE" || fail "missing controlword"
grep -q "statusword" "$FILE" || fail "missing statusword"

# --------------------------------------------------
# AXES CHECK
# --------------------------------------------------

AXIS_COUNT=$(awk '
  /^axes:/ { in_axes=1; next }
  in_axes && /^[^[:space:]]/ { in_axes=0 }
  in_axes && /^[[:space:]]+(x|y|z):/ { count++ }
  END { print count+0 }
' "$FILE")

if [[ "$AXIS_COUNT" -lt 1 ]]; then
  fail "no axes defined"
fi

# opcional: coerência esperada
EXPECTED=$(grep -E "expected_axes:" "$FILE" | awk '{print $2}' || true)

if [[ -n "$EXPECTED" ]]; then
  if [[ "$EXPECTED" != "$AXIS_COUNT" ]]; then
    warn "expected_axes ($EXPECTED) != detected axes ($AXIS_COUNT)"
  fi
fi

# --------------------------------------------------
# INTEGRATION RULES
# --------------------------------------------------

grep -q "required_runtime_functions" "$FILE" || warn "missing integration_rules.required_runtime_functions"

# --------------------------------------------------
# RESULT
# --------------------------------------------------

echo "PASS"
