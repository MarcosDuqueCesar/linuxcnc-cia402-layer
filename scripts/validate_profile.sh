#!/usr/bin/env bash

set -euo pipefail

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <file.yaml | directory>"
  exit 1
fi

fail=0
total_count=0
pass_count=0
fail_count=0
info_count=0

check_file() {
  f="$1"
  echo "---- $f ----"

  local file_fail=0
  local block
  local dup_keys

  total_count=$((total_count + 1))

  dup_keys=$(grep -E '^[a-zA-Z0-9_]+:' "$f" | sed 's/:.*//' | sort | uniq -d || true)
  if [ -n "$dup_keys" ]; then
    echo "ERROR: duplicate top-level fields -> $dup_keys"
    file_fail=1
  fi

  for key in profile modes objects; do
    if ! grep -q "^$key:" "$f"; then
      echo "ERROR: invalid profile structure (missing top-level field: $key)"
      file_fail=1
    fi
  done

  if grep -q "framework_supported:" "$f"; then
    block="$(awk '
      /^[[:space:]]*framework_supported:[[:space:]]*$/ {capture=1; next}
      capture && /^[^[:space:]]/ {capture=0}
      capture {print}
    ' "$f")"

    echo "$block" | grep -q '^[[:space:]]*-[[:space:]]*CSP[[:space:]]*$' || {
      echo "ERROR: framework_supported must include CSP"
      file_fail=1
    }

    echo "$block" | grep -q '^[[:space:]]*-[[:space:]]*HM[[:space:]]*$' || {
      echo "ERROR: framework_supported must include HM"
      file_fail=1
    }
  else
    echo "ERROR: missing required section: framework_supported"
    file_fail=1
  fi

  if awk '
    /^modes:[[:space:]]*$/ {in_modes=1; next}
    in_modes && /^[^[:space:]]/ {in_modes=0}
    in_modes && /^[[:space:]]+supported:[[:space:]]*$/ {found=1}
    END {exit(found ? 0 : 1)}
  ' "$f"; then
    echo "ERROR: deprecated structure detected: modes.supported"
    file_fail=1
  fi

  if grep -q '^[[:space:]]*classification:[[:space:]]*reference[[:space:]]*$' "$f"; then
    if ! grep -q '^quick_stop:' "$f"; then
      echo "ERROR: reference profile must define quick_stop block"
      file_fail=1
    fi
  fi

  if grep -q "stub" "$f"; then
    echo "INFO: stub profile (not a real driver profile)"
    info_count=$((info_count + 1))
  fi

  if [ "$file_fail" -eq 0 ]; then
    echo "PASS"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL"
    fail_count=$((fail_count + 1))
    fail=1
  fi

  echo
}

if [ -d "$TARGET" ]; then
  while IFS= read -r f; do
    check_file "$f"
  done < <(
    find "$TARGET" \
      \( -path "*/validated/*.yaml" -o \
         -path "*/reference/*.yaml" -o \
         -path "*/experimental/*.yaml" \) \
      | sort
  )
else
  check_file "$TARGET"
fi

echo "================ VALIDATION SUMMARY ================"
echo "Total files checked : $total_count"
echo "PASS                : $pass_count"
echo "FAIL                : $fail_count"
echo "INFO                : $info_count"
echo "===================================================="

exit $fail
