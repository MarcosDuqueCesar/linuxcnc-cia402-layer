#!/usr/bin/env bash
set -euo pipefail

TRACKING_OFFSET="${1:-2.5}"

echo "=== TEST TRACKING X ==="
echo "started=$(date '+%F %T')"
echo "tracking_offset=$TRACKING_OFFSET"

echo "[1/7] clear relevant injector bits (X only)"
halcmd sets fi-inject-tracking-x FALSE
halcmd sets fi-inject-stall-x FALSE
halcmd sets fi-inject-response-timeout-x FALSE
halcmd sets fi-reset-x TRUE
sleep 0.1
halcmd sets fi-reset-x FALSE

echo "[2/7] configure tracking offset"
halcmd setp fault_inj_x.tracking-offset "$TRACKING_OFFSET"

echo "[3/7] reset watchdog X"
halcmd sets motion-watchdog-reset-x TRUE
sleep 0.1
halcmd sets motion-watchdog-reset-x FALSE
sleep 0.2

echo "[4/7] assert motion request X"
halcmd sets motion-req-x TRUE
sleep 0.5

echo "--- PREFLIGHT X ---"
halcmd getp msg_x.allow-motion
halcmd getp mcsp_x.ready
halcmd getp motion_wd_x.armed
halcmd getp motion_wd_x.motion-req
halcmd getp motion_wd_x.pos-cmd
halcmd getp motion_wd_x.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out

echo "[5/7] inject tracking X"
halcmd sets fi-inject-tracking-x TRUE
sleep 0.5

echo "--- DURING INJECTION X (T0) ---"
halcmd getp motion_wd_x.pos-cmd
halcmd getp motion_wd_x.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out
halcmd getp motion_wd_x.fault
halcmd getp motion_wd_x.fault-latched
halcmd getp motion_wd_x.tracking-error
halcmd getp motion_wd_x.first-fault-code
halcmd getp fault_inj_x.mode

echo "[6/7] hold injection longer"
sleep 1.5

echo "--- DURING INJECTION X (T1) ---"
halcmd getp motion_wd_x.pos-cmd
halcmd getp motion_wd_x.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out
halcmd getp motion_wd_x.fault
halcmd getp motion_wd_x.fault-latched
halcmd getp motion_wd_x.tracking-error
halcmd getp motion_wd_x.first-fault-code
halcmd getp fault_inj_x.mode

echo "[7/7] final result X"
halcmd getp motion_wd_x.fault
halcmd getp motion_wd_x.fault-latched
halcmd getp motion_wd_x.tracking-error
halcmd getp motion_wd_x.first-fault-code
halcmd getp fault_inj_x.mode

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state_multi.sh after this test"
