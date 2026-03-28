#!/usr/bin/env bash
set -euo pipefail

OBSERVE_SECONDS="${1:-12}"
SAMPLE_INTERVAL="${2:-0.2}"
INJECT_SECONDS="${3:-4.5}"

readp() {
    halcmd getp "$1" 2>/dev/null || echo "NA"
}

echo "=== TEST STALL ==="
echo "started=$(date '+%F %T')"
echo "observe_seconds=$OBSERVE_SECONDS sample_interval=$SAMPLE_INTERVAL inject_seconds=$INJECT_SECONDS"
echo "ASSUMPTION: G-code is already running"

echo "[1/4] clear relevant injector bits"
halcmd sets fi-inject-fault FALSE
halcmd sets fi-inject-fault-reaction FALSE
halcmd sets fi-inject-stall FALSE
halcmd sets fi-inject-response-timeout FALSE
halcmd sets fi-inject-tracking FALSE
halcmd sets fi-reset TRUE
sleep 0.1
halcmd sets fi-reset FALSE

echo "[2/4] set watchdog for stall test"
halcmd setp motion_wd.tracking-error-limit 999999
halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
sleep 0.1

echo "[3/4] assert motion request"
halcmd sets motion-req TRUE
sleep 0.3

echo "--- PREFLIGHT ---"
halcmd getp motion_wd.armed
halcmd getp motion_wd.motion-req
halcmd getp msg.allow-motion
halcmd getp mcsp.ready
halcmd getp motion_wd.pos-cmd
halcmd getp motion_wd.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out
halcmd getp fault_inj_x.mode

echo "[4/4] observe and inject stall"
echo "------------------------------------------------------------"
printf "%-12s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
  "time" "armed" "mreq" "pos_cmd" "pos_fb" "fb_in" "fb_out" "fault" "lat" "track" "stall" "mode"

START_TS=$(python3 - <<'PY'
import time
print(time.time())
PY
)

INJECT_START=""
INJECT_DONE="FALSE"

while true; do
    NOW_TS=$(python3 - <<'PY'
import time
print(time.time())
PY
)

    ELAPSED=$(python3 - <<PY
start = float("$START_TS")
now = float("$NOW_TS")
print(now - start)
PY
)

    DONE=$(python3 - <<PY
elapsed = float("$ELAPSED")
limit = float("$OBSERVE_SECONDS")
print("YES" if elapsed > limit else "NO")
PY
)
    [[ "$DONE" == "YES" ]] && break

    SHOULD_INJECT=$(python3 - <<PY
elapsed = float("$ELAPSED")
print("YES" if elapsed >= 2.0 else "NO")
PY
)

    if [[ -z "$INJECT_START" && "$SHOULD_INJECT" == "YES" ]]; then
        halcmd sets fi-inject-stall TRUE
        INJECT_START="$NOW_TS"
    fi

    if [[ -n "$INJECT_START" && "$INJECT_DONE" == "FALSE" ]]; then
        STOP_INJECT=$(python3 - <<PY
inj_start = float("$INJECT_START")
now = float("$NOW_TS")
inj_for = float("$INJECT_SECONDS")
print("YES" if (now - inj_start) >= inj_for else "NO")
PY
)
        if [[ "$STOP_INJECT" == "YES" ]]; then
            halcmd sets fi-inject-stall FALSE
            INJECT_DONE="TRUE"
        fi
    fi

    t=$(date '+%H:%M:%S')
    armed="$(readp motion_wd.armed)"
    mreq="$(readp motion_wd.motion-req)"
    pos_cmd="$(readp motion_wd.pos-cmd)"
    pos_fb="$(readp motion_wd.pos-fb)"
    fb_in="$(readp fault_inj_x.pos-fb-in)"
    fb_out="$(readp fault_inj_x.pos-fb-out)"
    fault="$(readp motion_wd.fault)"
    lat="$(readp motion_wd.fault-latched)"
    track="$(readp motion_wd.tracking-error)"
    stall="$(readp motion_wd.stall)"
    mode="$(readp fault_inj_x.mode)"

    printf "%-12s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
      "$t" "$armed" "$mreq" "$pos_cmd" "$pos_fb" "$fb_in" "$fb_out" "$fault" "$lat" "$track" "$stall" "$mode"

    sleep "$SAMPLE_INTERVAL"
done

halcmd sets fi-inject-stall FALSE

echo "------------------------------------------------------------"
echo "--- FINAL STATE ---"
halcmd getp motion_wd.fault
halcmd getp motion_wd.fault-latched
halcmd getp motion_wd.stall
halcmd getp motion_wd.first-fault-code
halcmd getp fault_inj_x.mode
halcmd getp fault_inj_x.freeze-active

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state.sh after this test"
