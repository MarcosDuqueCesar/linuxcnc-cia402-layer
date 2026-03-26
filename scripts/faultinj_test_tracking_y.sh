#!/usr/bin/env bash
set -euo pipefail

TRACKING_OFFSET="${1:-2.5}"

echo "=== TEST TRACKING Y ==="
echo "started=$(date '+%F %T')"
echo "tracking_offset=$TRACKING_OFFSET"

echo "[1/7] clear relevant injector bits (Y only)"
halcmd sets fi-inject-tracking-y FALSE
halcmd sets fi-inject-stall-y FALSE
halcmd sets fi-inject-response-timeout-y FALSE
halcmd sets fi-reset-y TRUE
sleep 0.1
halcmd sets fi-reset-y FALSE

echo "[2/7] configure tracking offset"
halcmd setp fault_inj_y.tracking-offset "$TRACKING_OFFSET"

echo "[3/7] reset watchdog Y"
halcmd sets motion-watchdog-reset-y TRUE
sleep 0.1
halcmd sets motion-watchdog-reset-y FALSE
sleep 0.2

echo "[4/7] assert motion request Y"
halcmd sets motion-req-y TRUE
sleep 0.5

echo "--- PREFLIGHT Y ---"
halcmd getp msg_y.allow-motion
halcmd getp mcsp_y.ready
halcmd getp motion_wd_y.armed
halcmd getp motion_wd_y.motion-req
halcmd getp motion_wd_y.pos-cmd
halcmd getp motion_wd_y.pos-fb
halcmd getp fault_inj_y.pos-fb-in
halcmd getp fault_inj_y.pos-fb-out

echo "[5/7] inject tracking Y"
halcmd sets fi-inject-tracking-y TRUE
sleep 0.5

echo "--- DURING INJECTION Y (T0) ---"
halcmd getp motion_wd_y.pos-cmd
halcmd getp motion_wd_y.pos-fb
halcmd getp fault_inj_y.pos-fb-in
halcmd getp fault_inj_y.pos-fb-out
halcmd getp motion_wd_y.fault
halcmd getp motion_wd_y.fault-latched
halcmd getp motion_wd_y.tracking-error
halcmd getp motion_wd_y.first-fault-code
halcmd getp fault_inj_y.mode

echo "[6/7] hold injection longer"
sleep 1.5

echo "--- DURING INJECTION Y (T1) ---"
halcmd getp motion_wd_y.pos-cmd
halcmd getp motion_wd_y.pos-fb
halcmd getp fault_inj_y.pos-fb-in
halcmd getp fault_inj_y.pos-fb-out
halcmd getp motion_wd_y.fault
halcmd getp motion_wd_y.fault-latched
halcmd getp motion_wd_y.tracking-error
halcmd getp motion_wd_y.first-fault-code
halcmd getp fault_inj_y.mode

echo "[7/7] final result Y"
halcmd getp motion_wd_y.fault
halcmd getp motion_wd_y.fault-latched
halcmd getp motion_wd_y.tracking-error
halcmd getp motion_wd_y.first-fault-code
halcmd getp fault_inj_y.mode

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state_multi.sh after this test"
