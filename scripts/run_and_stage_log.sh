#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/.." && pwd)"

BASE_DIR="$SCRIPT_DIR"
LOG_DIR="${WORKSPACE}/logs"
OUTBOX_ROOT="${WORKSPACE}/outbox"

RUN_NAME="${STAGE_RUN:-default_run}"
OUTBOX_DIR="${OUTBOX_ROOT}/${RUN_NAME}"

mkdir -p "$LOG_DIR" "$OUTBOX_DIR"

cd "$BASE_DIR"

before_latest=""
for f in "$LOG_DIR"/*.log; do
    [ -e "$f" ] || continue
    if [ -z "$before_latest" ] || [ "$f" -nt "$before_latest" ]; then
        before_latest="$f"
    fi
done

./single_axis_ctl.sh "$@"

after_latest=""
for f in "$LOG_DIR"/*.log; do
    [ -e "$f" ] || continue
    if [ -z "$after_latest" ] || [ "$f" -nt "$after_latest" ]; then
        after_latest="$f"
    fi
done

if [ -z "$after_latest" ]; then
    echo "ERROR: no log file found in $LOG_DIR"
    exit 1
fi

if [ -n "$before_latest" ] && [ "$after_latest" = "$before_latest" ]; then
    echo "WARNING: no newer log detected; staging latest existing log"
fi

cp -f "$after_latest" "$OUTBOX_DIR"/

echo
echo "Run name:"
echo "  $RUN_NAME"
echo "Staged for upload:"
echo "  $OUTBOX_DIR/$(basename "$after_latest")"
