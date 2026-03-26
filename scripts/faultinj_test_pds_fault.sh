#!/usr/bin/env bash
set -euo pipefail

echo "=== TEST PDS FAULT ==="
echo "started=$(date '+%F %T')"

echo "[1/4] inject fault"
halcmd sets fi-inject-fault TRUE
sleep 0.2

echo "--- DURING FAULT ---"
halcmd getp pds.fault
halcmd getp pds.op-enabled
halcmd getp fault_inj_x.fault-active
halcmd getp fault_inj_x.mode

echo "[2/4] clear injector"
halcmd sets fi-inject-fault FALSE
sleep 0.2

echo "--- AFTER INJECTOR CLEAR ---"
halcmd getp pds.fault
halcmd getp pds.op-enabled
halcmd getp fault_inj_x.fault-active
halcmd getp fault_inj_x.mode

echo "[3/4] issue fault reset"
halcmd sets fault-reset-req TRUE
sleep 0.2
halcmd sets fault-reset-req FALSE
sleep 0.2

echo "--- AFTER FAULT RESET ---"
halcmd getp pds.fault
halcmd getp pds.op-enabled
halcmd getp fault_inj_x.fault-active
halcmd getp fault_inj_x.mode

echo "[4/4] local injector reset"
halcmd sets fi-reset TRUE
sleep 0.1
halcmd sets fi-reset FALSE

echo "finished=$(date '+%F %T')"
