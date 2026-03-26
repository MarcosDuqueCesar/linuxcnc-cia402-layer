#!/usr/bin/env bash
set -euo pipefail

echo "=== FAULT INJECTOR CLEAR STATE (MULTI) ==="
echo "started=$(date '+%F %T')"

# clear injectors X
halcmd sets fi-inject-fault-x FALSE
halcmd sets fi-inject-fault-reaction-x FALSE
halcmd sets fi-inject-stall-x FALSE
halcmd sets fi-inject-response-timeout-x FALSE
halcmd sets fi-inject-tracking-x FALSE
halcmd sets fi-reset-x TRUE
sleep 0.1
halcmd sets fi-reset-x FALSE

# clear injectors Y
halcmd sets fi-inject-fault-y FALSE
halcmd sets fi-inject-fault-reaction-y FALSE
halcmd sets fi-inject-stall-y FALSE
halcmd sets fi-inject-response-timeout-y FALSE
halcmd sets fi-inject-tracking-y FALSE
halcmd sets fi-reset-y TRUE
sleep 0.1
halcmd sets fi-reset-y FALSE

# clear semantic requests
halcmd sets motion-req-x FALSE
halcmd sets motion-req-y FALSE

# reset watchdogs
halcmd sets motion-watchdog-reset-x TRUE
halcmd sets motion-watchdog-reset-y TRUE
sleep 0.1
halcmd sets motion-watchdog-reset-x FALSE
halcmd sets motion-watchdog-reset-y FALSE
sleep 0.1

echo "--- FINAL STATE X ---"
halcmd getp fault_inj_x.mode || true
halcmd getp fault_inj_x.freeze-active || true
halcmd getp fault_inj_x.fault-active || true
halcmd getp motion_wd_x.fault || true
halcmd getp motion_wd_x.fault-latched || true
halcmd getp motion_wd_x.first-fault-code || true
halcmd getp motion_wd_x.tracking-error || true
halcmd getp motion_wd_x.stall || true
halcmd getp motion_wd_x.motion-req || true

echo "--- FINAL STATE Y ---"
halcmd getp fault_inj_y.mode || true
halcmd getp fault_inj_y.freeze-active || true
halcmd getp fault_inj_y.fault-active || true
halcmd getp motion_wd_y.fault || true
halcmd getp motion_wd_y.fault-latched || true
halcmd getp motion_wd_y.first-fault-code || true
halcmd getp motion_wd_y.tracking-error || true
halcmd getp motion_wd_y.stall || true
halcmd getp motion_wd_y.motion-req || true

echo "finished=$(date '+%F %T')"
