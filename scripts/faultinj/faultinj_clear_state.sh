#!/usr/bin/env bash
set -euo pipefail

echo "=== FAULT INJECTOR CLEAR STATE ==="
echo "started=$(date '+%F %T')"

halcmd sets fi-inject-fault FALSE
halcmd sets fi-inject-fault-reaction FALSE
halcmd sets fi-inject-stall FALSE
halcmd sets fi-inject-response-timeout FALSE
halcmd sets fi-inject-tracking FALSE

halcmd sets fi-reset TRUE
sleep 0.1
halcmd sets fi-reset FALSE

halcmd sets motion-req FALSE

halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
sleep 0.1

echo "--- FINAL STATE ---"
halcmd getp fault_inj_x.mode || true
halcmd getp fault_inj_x.freeze-active || true
halcmd getp fault_inj_x.fault-active || true
halcmd getp motion_wd.fault || true
halcmd getp motion_wd.fault-latched || true
halcmd getp motion_wd.first-fault-code || true
halcmd getp motion_wd.tracking-error || true
halcmd getp motion_wd.stall || true
halcmd getp motion_wd.motion-req || true

echo "finished=$(date '+%F %T')"
