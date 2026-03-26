#!/usr/bin/env bash
set -euo pipefail

TRACKING_OFFSET="${1:-2.5}"

echo "=== TEST TRACKING ==="
echo "started=$(date '+%F %T')"
echo "tracking_offset=$TRACKING_OFFSET"

echo "[1/7] clear relevant injector bits"
halcmd sets fi-inject-tracking FALSE
halcmd sets fi-inject-stall FALSE
halcmd sets fi-inject-response-timeout FALSE
halcmd sets fi-reset TRUE
sleep 0.1
halcmd sets fi-reset FALSE

echo "[2/7] configure tracking offset"
halcmd setp fault_inj_x.tracking-offset "$TRACKING_OFFSET"

echo "[3/7] reset watchdog"
halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
sleep 0.2

echo "[4/7] assert motion request"
halcmd sets motion-req TRUE
sleep 0.5

echo "--- PREFLIGHT ---"
halcmd getp msg.allow-motion
halcmd getp mcsp.ready
halcmd getp motion_wd.armed
halcmd getp motion_wd.motion-req
halcmd getp motion_wd.pos-cmd
halcmd getp motion_wd.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out

echo "[5/7] inject tracking"
halcmd sets fi-inject-tracking TRUE
sleep 0.5

echo "--- DURING INJECTION (T0) ---"
halcmd getp motion_wd.pos-cmd
halcmd getp motion_wd.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out
halcmd getp motion_wd.fault
halcmd getp motion_wd.fault-latched
halcmd getp motion_wd.tracking-error
halcmd getp motion_wd.first-fault-code
halcmd getp fault_inj_x.mode

echo "[6/7] hold injection longer"
sleep 1.5

echo "--- DURING INJECTION (T1) ---"
halcmd getp motion_wd.pos-cmd
halcmd getp motion_wd.pos-fb
halcmd getp fault_inj_x.pos-fb-in
halcmd getp fault_inj_x.pos-fb-out
halcmd getp motion_wd.fault
halcmd getp motion_wd.fault-latched
halcmd getp motion_wd.tracking-error
halcmd getp motion_wd.first-fault-code
halcmd getp fault_inj_x.mode

echo "[7/7] final result"
halcmd getp motion_wd.fault
halcmd getp motion_wd.fault-latched
halcmd getp motion_wd.tracking-error
halcmd getp motion_wd.first-fault-code
halcmd getp fault_inj_x.mode

echo "finished=$(date '+%F %T')"
echo "NOTE: run faultinj_clear_state.sh after this test"
