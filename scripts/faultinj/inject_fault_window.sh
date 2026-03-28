#!/usr/bin/env bash
set -euo pipefail

# Timed injector for fault_inj_x
# Usage examples:
#   ./scripts/inject_fault_window.sh stall 4.5
#   ./scripts/inject_fault_window.sh tracking 0.5
#   ./scripts/inject_fault_window.sh fault 0.5
#   ./scripts/inject_fault_window.sh response_timeout 2.5
#   ./scripts/inject_fault_window.sh clear

MODE="${1:-}"
DURATION="${2:-0.5}"

if [[ -z "$MODE" ]]; then
    echo "usage: $0 {fault|fault_reaction|stall|response_timeout|tracking|clear} [duration_seconds]"
    exit 1
fi

clear_all() {
    halcmd sets fi-inject-fault FALSE
    halcmd sets fi-inject-fault-reaction FALSE
    halcmd sets fi-inject-stall FALSE
    halcmd sets fi-inject-response-timeout FALSE
    halcmd sets fi-inject-tracking FALSE
}

echo "=== INJECTOR WINDOW ==="
echo "mode=$MODE duration=${DURATION}s"
echo "started=$(date '+%F %T')"

case "$MODE" in
    clear)
        clear_all
        halcmd sets fi-reset TRUE
        sleep 0.1
        halcmd sets fi-reset FALSE
        ;;
    fault)
        clear_all
        halcmd sets fi-inject-fault TRUE
        sleep "$DURATION"
        halcmd sets fi-inject-fault FALSE
        ;;
    fault_reaction)
        clear_all
        halcmd sets fi-inject-fault-reaction TRUE
        sleep "$DURATION"
        halcmd sets fi-inject-fault-reaction FALSE
        ;;
    stall)
        clear_all
        halcmd sets fi-inject-stall TRUE
        sleep "$DURATION"
        halcmd sets fi-inject-stall FALSE
        ;;
    response_timeout)
        clear_all
        halcmd sets fi-inject-response-timeout TRUE
        sleep "$DURATION"
        halcmd sets fi-inject-response-timeout FALSE
        ;;
    tracking)
        clear_all
        halcmd sets fi-inject-tracking TRUE
        sleep "$DURATION"
        halcmd sets fi-inject-tracking FALSE
        ;;
    *)
        echo "invalid mode: $MODE"
        exit 1
        ;;
esac

echo "ended=$(date '+%F %T')"
echo "state:"
halcmd getp fault_inj_x.mode || true
halcmd getp fault_inj_x.fault-active || true
halcmd getp fault_inj_x.freeze-active || true
