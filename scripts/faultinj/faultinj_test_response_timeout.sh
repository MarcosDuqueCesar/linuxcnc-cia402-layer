#!/usr/bin/env bash
set -euo pipefail

OBSERVE_SECONDS="${1:-6}"
SAMPLE_INTERVAL="${2:-0.2}"
INJECT_SECONDS="${3:-2.5}"

readp() {
    halcmd getp "$1" 2>/dev/null || echo "NA"
}

echo "=== TEST RESPONSE TIMEOUT (EARLY INJECTION) ==="
echo "started=$(date '+%F %T')"
echo "observe_seconds=$OBSERVE_SECONDS sample_interval=$SAMPLE_INTERVAL inject_seconds=$INJECT_SECONDS"
echo "ASSUMPTION: G-code is already running"

echo "[1/5] clear relevant injector bits"
halcmd sets fi-inject-fault FALSE
halcmd sets fi-inject-fault-reaction FALSE
halcmd sets fi-inject-stall FALSE
halcmd sets fi-inject-response-timeout FALSE
halcmd sets fi-inject-tracking FALSE
halcmd sets fi-reset TRUE
sleep 0.1
halcmd sets fi-reset FALSE

echo "[2/5] reset watchdog"
halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
sleep 0.1

echo "[3/5] assert motion request and inject immediately"
halcmd sets motion-req TRUE
halcmd sets fi-inject-response-timeout TRUE
sleep 0.05

echo "--- EARLY PREFLIGHT ---"
halcmd getp motion_wd.armed
halcmd getp motion_wd.motion-req
halcmd getp msg.allow-motion
halcmd getp mcsp.ready
halcmd getp motion_wd.moving-seen
halcmd getp motion_wd.response-pending
halcmd getp motion_wd.response-tmr
halcmd getp motion_wd.pos-cmd
halcmd getp motion_wd.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out
halcmd getp fault_inj_x.mode

echo "[4/5] observe while response-timeout injection is active"
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
            halcmd sets fi-inject-response-timeout FALSE
            INJECT_DONE="TRUE"
        fi
    fi

    t=$(date '+%H:%M:%S')
    armed="$(readp motion_wd.armed)"
    mreq="$(readp motion_wd.motion-req)"
    move="$(readp motion_wd.moving-seen)"
    rpend="$(readp motion_wd.response-pending)"
    rtmr="$(readp motion_wd.response-tmr)"
    pos_cmd="$(readp motion_wd.pos-cmd)"
    pos_fb="$(readp motion_wd.pos-fb)"
    fb_in="$(readp fault_inj_x.pos-fb-in)"
    fb_out="$(readp fault_inj_x.pos-fb-out)"
    fault="$(readp motion_wd.fault)"
    lat="$(readp motion_wd.fault-latched)"
    rto="$(readp motion_wd.response-timeout)"
    stall="$(readp motion_wd.stall)"
    mode="$(readp fault_inj_x.mode)"

    printf "%-12s %-6s %-6s %-6s %-6s %-8s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
      "$t" "$armed" "$mreq" "$move" "$rpend" "$rtmr" "$pos_cmd" "$pos_fb" "$fb_in" "$fb_out" "$fault" "$lat" "$rto" "$stall" "$mode"

    sleep "$SAMPLE_INTERVAL"
done

halcmd sets fi-inject-response-timeout FALSE

echo "------------------------------------------------------------"
echo "[5/5] final state"
halcmd getp motion_wd.armed
halcmd getp motion_wd.motion-req
halcmd getp motion_wd.moving-seen
halcmd getp motion_wd.response-pending
halcmd getp motion_wd.response-tmr
halcmd getp motion_wd.fault
halcmd getp motion_wd.fault-latched
halcmd getp motion_wd.response-timeout
halcmd getp motion_wd.first-fault-code
halcmd getp fault_inj_x.mode
halcmd getp fault_inj_x.freeze-active

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state.sh after this test"
