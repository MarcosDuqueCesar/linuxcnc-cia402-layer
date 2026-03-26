#!/usr/bin/env bash
set -euo pipefail

OBSERVE_SECONDS="${1:-6}"
SAMPLE_INTERVAL="${2:-0.2}"
INJECT_SECONDS="${3:-2.5}"

readp() {
    halcmd getp "$1" 2>/dev/null || echo "NA"
}

echo "=== TEST RESPONSE TIMEOUT Y (FROM IDLE) ==="
echo "started=$(date '+%F %T')"
echo "observe_seconds=$OBSERVE_SECONDS sample_interval=$SAMPLE_INTERVAL inject_seconds=$INJECT_SECONDS"
echo "ASSUMPTION: Y axis is idle before this script starts"

echo "[1/6] clear injector bits (Y only)"
halcmd sets fi-inject-fault-y FALSE
halcmd sets fi-inject-fault-reaction-y FALSE
halcmd sets fi-inject-stall-y FALSE
halcmd sets fi-inject-response-timeout-y FALSE
halcmd sets fi-inject-tracking-y FALSE
halcmd sets fi-reset-y TRUE
sleep 0.1
halcmd sets fi-reset-y FALSE

echo "[2/6] force neutral semantic state (Y only)"
halcmd sets motion-req-y FALSE
sleep 0.1

echo "[3/6] reset watchdog Y from idle"
halcmd sets motion-watchdog-reset-y TRUE
sleep 0.1
halcmd sets motion-watchdog-reset-y FALSE
sleep 0.1

echo "--- IDLE PREFLIGHT Y ---"
halcmd getp motion_wd_y.armed
halcmd getp motion_wd_y.motion-req
halcmd getp motion_wd_y.moving-seen
halcmd getp motion_wd_y.response-pending
halcmd getp motion_wd_y.response-tmr
halcmd getp motion_wd_y.fault
halcmd getp motion_wd_y.fault-latched
halcmd getp motion_wd_y.first-fault-code
halcmd getp motion_wd_y.pos-cmd
halcmd getp motion_wd_y.pos-fb
halcmd getp fault_inj_y.pos-fb-in
halcmd getp fault_inj_y.pos-fb-out
halcmd getp fault_inj_y.mode

echo "[4/6] arm response-timeout path from idle (Y)"
halcmd sets fi-inject-response-timeout-y TRUE
sleep 0.05
halcmd sets motion-req-y TRUE
sleep 0.05

echo "--- EARLY ARM PREFLIGHT Y ---"
halcmd getp motion_wd_y.armed
halcmd getp motion_wd_y.motion-req
halcmd getp msg_y.allow-motion
halcmd getp mcsp_y.ready
halcmd getp motion_wd_y.moving-seen
halcmd getp motion_wd_y.response-pending
halcmd getp motion_wd_y.response-tmr
halcmd getp motion_wd_y.pos-cmd
halcmd getp motion_wd_y.pos-fb
halcmd getp fault_inj_y.pos-fb-in
halcmd getp fault_inj_y.pos-fb-out
halcmd getp fault_inj_y.mode

echo "[5/6] observe from idle-arm window (Y)"
echo "------------------------------------------------------------"
printf "%-12s %-6s %-6s %-6s %-6s %-8s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
  "time" "armed" "mreq" "move" "rpend" "rtmr" "pos_cmd" "pos_fb" "fb_in" "fb_out" "fault" "lat" "rto" "stall" "mode"

START_TS=$(python3 - <<'PY'
import time
print(time.time())
PY
)

INJECT_START="$START_TS"
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

    if [[ "$INJECT_DONE" == "FALSE" ]]; then
        STOP_INJECT=$(python3 - <<PY
inj_start = float("$INJECT_START")
now = float("$NOW_TS")
inj_for = float("$INJECT_SECONDS")
print("YES" if (now - inj_start) >= inj_for else "NO")
PY
)
        if [[ "$STOP_INJECT" == "YES" ]]; then
            halcmd sets fi-inject-response-timeout-y FALSE
            INJECT_DONE="TRUE"
        fi
    fi

    t=$(date '+%H:%M:%S')
    armed="$(readp motion_wd_y.armed)"
    mreq="$(readp motion_wd_y.motion-req)"
    move="$(readp motion_wd_y.moving-seen)"
    rpend="$(readp motion_wd_y.response-pending)"
    rtmr="$(readp motion_wd_y.response-tmr)"
    pos_cmd="$(readp motion_wd_y.pos-cmd)"
    pos_fb="$(readp motion_wd_y.pos-fb)"
    fb_in="$(readp fault_inj_y.pos-fb-in)"
    fb_out="$(readp fault_inj_y.pos-fb-out)"
    fault="$(readp motion_wd_y.fault)"
    lat="$(readp motion_wd_y.fault-latched)"
    rto="$(readp motion_wd_y.response-timeout)"
    stall="$(readp motion_wd_y.stall)"
    mode="$(readp fault_inj_y.mode)"

    printf "%-12s %-6s %-6s %-6s %-6s %-8s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
      "$t" "$armed" "$mreq" "$move" "$rpend" "$rtmr" "$pos_cmd" "$pos_fb" "$fb_in" "$fb_out" "$fault" "$lat" "$rto" "$stall" "$mode"

    sleep "$SAMPLE_INTERVAL"
done

halcmd sets fi-inject-response-timeout-y FALSE

echo "------------------------------------------------------------"
echo "[6/6] final state Y"
halcmd getp motion_wd_y.armed
halcmd getp motion_wd_y.motion-req
halcmd getp motion_wd_y.moving-seen
halcmd getp motion_wd_y.response-pending
halcmd getp motion_wd_y.response-tmr
halcmd getp motion_wd_y.fault
halcmd getp motion_wd_y.fault-latched
halcmd getp motion_wd_y.response-timeout
halcmd getp motion_wd_y.first-fault-code
halcmd getp fault_inj_y.mode
halcmd getp fault_inj_y.freeze-active

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state_multi.sh after this test"

