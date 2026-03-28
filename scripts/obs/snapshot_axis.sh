#!/usr/bin/env bash
set -euo pipefail

axis="${1:-x}"

case "$axis" in
  x|X) axis="x" ;;
  y|Y) axis="y" ;;
  *)
    echo "Usage: $0 [x|y]" >&2
    exit 1
    ;;
esac

echo "===== AXIS SNAPSHOT: ${axis^^} ====="
echo

echo -e "\n----- MOTION WATCHDOG -----"
halcmd getp "motion_wd_${axis}.fault"
halcmd getp "motion_wd_${axis}.fault-latched"
halcmd getp "motion_wd_${axis}.first-fault-code"
halcmd getp "motion_wd_${axis}.response-timeout"
halcmd getp "motion_wd_${axis}.stall"
halcmd getp "motion_wd_${axis}.tracking-error"
halcmd getp "motion_wd_${axis}.tracking-error-abs"
halcmd getp "motion_wd_${axis}.armed"
halcmd getp "motion_wd_${axis}.motion-req"
halcmd getp "motion_wd_${axis}.op-enabled"
halcmd getp "motion_wd_${axis}.pos-cmd"
halcmd getp "motion_wd_${axis}.pos-fb"
echo

echo -e "\n----- HOME WATCHDOG -----"
halcmd getp "home_wd_${axis}.fault"
halcmd getp "home_wd_${axis}.fault-latched"
halcmd getp "home_wd_${axis}.first-fault-code"
halcmd getp "home_wd_${axis}.home-req"
halcmd getp "home_wd_${axis}.homing"
halcmd getp "home_wd_${axis}.homed"
halcmd getp "home_wd_${axis}.home-owner"
echo

echo -e "\n----- HOMING / UNIT TASK -----"
halcmd getp "ut_${axis}.owner"
halcmd getp "ut_${axis}.homing"
halcmd getp "ut_${axis}.homed"
halcmd getp "ut_${axis}.state"
halcmd getp "ut_${axis}.reason"
halcmd getp "ut_${axis}.mode-ok"
halcmd getp "ut_${axis}.done-lat"
halcmd getp "ut_${axis}.err-lat"
echo

echo -e "\n----- CSP / MUX -----"
halcmd getp "mcsp_${axis}.owner"
halcmd getp "mcsp_${axis}.state"
halcmd getp "mcsp_${axis}.reason"
halcmd getp "mcsp_${axis}.ready"
halcmd getp "mux_${axis}.sel-home"
halcmd getp "mux_${axis}.sel-csp"
halcmd getp "mux_${axis}.state"
halcmd getp "mux_${axis}.reason"
echo

echo -e "\n----- BACKEND / PDS -----"
halcmd getp "adapter_${axis}.out-statusword"
halcmd getp "adapter_${axis}.out-opmode-display"
halcmd getp "adapter_${axis}.out-actual-position"
halcmd getp "pds_${axis}.op-enabled"
echo

echo -e "\n----- TIMING -----"
halcmd getp "motion_wd_${axis}.update.time"
halcmd getp "home_wd_${axis}.update.time"
halcmd getp "ut_${axis}.update.time"
halcmd getp "mcsp_${axis}.update.time"
halcmd getp "mux_${axis}.update.time"
halcmd getp "invmon_${axis}.update.time"
