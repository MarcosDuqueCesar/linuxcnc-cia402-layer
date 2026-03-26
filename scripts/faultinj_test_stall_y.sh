#!/usr/bin/env bash
set -euo pipefail

OBSERVE_SECONDS="${1:-12}"
SAMPLE_INTERVAL="${2:-0.2}"
INJECT_SECONDS="${3:-4.5}"

readp() {
    halcmd getp "$1" 2>/dev/null || echo "NA"
}

echo "=== TEST STALL Y ==="
echo "started=$(date '+%F %T')"
echo "observe_seconds=$OBSERVE_SECONDS sample_interval=$SAMPLE_INTERVAL inject_seconds=$INJECT_SECONDS"
echo "ASSUMPTION: machine can produce Y movement while this test runs"

echo "[1/5] clear relevant injector bits (Y only)"
halcmd sets fi-inject-fault-y FALSE
halcmd sets fi-inject-fault-reaction-y FALSE
halcmd sets fi-inject-stall-y FALSE
halcmd sets fi-inject-response-timeout-y FALSE
halcmd sets fi-inject-tracking-y FALSE
halcmd sets fi-reset-y TRUE
sleep 0.1
halcmd sets fi-reset-y FALSE

echo "[2/5] configure watchdog Y for stall test"
halcmd setp motion_wd_y.tracking-error-limit 999999
halcmd sets motion-watchdog-reset-y TRUE
sleep 0.1
halcmd sets motion-watchdog-reset-y FALSE
sleep 0.1

echo "[3/5] assert motion request Y"
halcmd sets motion-req-y TRUE
sleep 0.3

echo "--- PREFLIGHT Y ---"
halcmd getp msg_y.allow-motion
halcmd getp mcsp_y.ready
halcmd getp motion_wd_y.armed
halcmd getp motion_wd_y.motion-req
halcmd getp motion_wd_y.moving-seen
halcmd getp motion_wd_y.pos-cmd
halcmd getp motion_wd_y.pos-fb
halcmd getp fault_inj_y.pos-fb-in
halcmd getp fault_inj_y.pos-fb-out
halcmd getp fault_inj_y.mode

echo "[4/5] observe and inject stall Y"
echo "------------------------------------------------------------"
printf "%-12s %-6s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
  "time" "armed" "mreq" "move" "pos_cmd" "pos_fb" "fb_in" "fb_out" "fault" "lat" "track" "stall" "mode"

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
        halcmd sets fi-inject-stall-y TRUE
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
            halcmd sets fi-inject-stall-y FALSE
            INJECT_DONE="TRUE"
        fi
    fi

    t=$(date '+%H:%M:%S')
    armed="$(readp motion_wd_y.armed)"
    mreq="$(readp motion_wd_y.motion-req)"
    move="$(readp motion_wd_y.moving-seen)"
    pos_cmd="$(readp motion_wd_y.pos-cmd)"
    pos_fb="$(readp motion_wd_y.pos-fb)"
    fb_in="$(readp fault_inj_y.pos-fb-in)"
    fb_out="$(readp fault_inj_y.pos-fb-out)"
    fault="$(readp motion_wd_y.fault)"
    lat="$(readp motion_wd_y.fault-latched)"
    track="$(readp motion_wd_y.tracking-error)"
    stall="$(readp motion_wd_y.stall)"
    mode="$(readp fault_inj_y.mode)"

    printf "%-12s %-6s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
      "$t" "$armed" "$mreq" "$move" "$pos_cmd" "$pos_fb" "$fb_in" "$fb_out" "$fault" "$lat" "$track" "$stall" "$mode"

    sleep "$SAMPLE_INTERVAL"
done

halcmd sets fi-inject-stall-y FALSE

echo "------------------------------------------------------------"
echo "[5/5] final result Y"
halcmd getp motion_wd_y.fault
halcmd getp motion_wd_y.fault-latched
halcmd getp motion_wd_y.stall
halcmd getp motion_wd_y.first-fault-code
halcmd getp fault_inj_y.mode
halcmd getp fault_inj_y.freeze-active

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state_multi.sh after this test"
