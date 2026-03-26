#!/usr/bin/env bash
set -euo pipefail

echo "=== STALL TEST PREFLIGHT (READ ONLY) ==="
echo "started=$(date '+%F %T')"
echo "------------------------------------------------------------"

readp() {
    halcmd getp "$1" 2>/dev/null || echo "NA"
}

armed="$(readp motion_wd.armed)"
mreq="$(readp motion_wd.motion-req)"
allow_motion="$(readp msg.allow-motion)"
mcsp_ready="$(readp mcsp.ready)"
pos_cmd="$(readp motion_wd.pos-cmd)"
pos_fb="$(readp motion_wd.pos-fb)"
fb_in="$(readp fault_inj_x.pos-fb-in)"
fb_out="$(readp fault_inj_x.pos-fb-out)"
fault="$(readp motion_wd.fault)"
latched="$(readp motion_wd.fault-latched)"
track="$(readp motion_wd.tracking-error)"
stall="$(readp motion_wd.stall)"
mode="$(readp fault_inj_x.mode)"
freeze_active="$(readp fault_inj_x.freeze-active)"
fault_active="$(readp fault_inj_x.fault-active)"

printf "%-28s %s\n" "motion_wd.armed"              "$armed"
printf "%-28s %s\n" "motion_wd.motion-req"         "$mreq"
printf "%-28s %s\n" "msg.allow-motion"             "$allow_motion"
printf "%-28s %s\n" "mcsp.ready"                   "$mcsp_ready"
printf "%-28s %s\n" "motion_wd.pos-cmd"            "$pos_cmd"
printf "%-28s %s\n" "motion_wd.pos-fb"             "$pos_fb"
printf "%-28s %s\n" "fault_inj_x.pos-fb-in"        "$fb_in"
printf "%-28s %s\n" "fault_inj_x.pos-fb-out"       "$fb_out"
printf "%-28s %s\n" "motion_wd.fault"              "$fault"
printf "%-28s %s\n" "motion_wd.fault-latched"      "$latched"
printf "%-28s %s\n" "motion_wd.tracking-error"     "$track"
printf "%-28s %s\n" "motion_wd.stall"              "$stall"
printf "%-28s %s\n" "fault_inj_x.mode"             "$mode"
printf "%-28s %s\n" "fault_inj_x.freeze-active"    "$freeze_active"
printf "%-28s %s\n" "fault_inj_x.fault-active"     "$fault_active"

echo "------------------------------------------------------------"

ready="YES"
reason=""

if [[ "$armed" != "TRUE" ]]; then
    ready="NO"
    reason="${reason} motion_wd_not_armed"
fi

if [[ "$mreq" != "TRUE" ]]; then
    ready="NO"
    reason="${reason} motion_req_false"
fi

if [[ "$allow_motion" != "TRUE" ]]; then
    ready="NO"
    reason="${reason} allow_motion_false"
fi

if [[ "$mcsp_ready" != "TRUE" ]]; then
    ready="NO"
    reason="${reason} mcsp_not_ready"
fi

if [[ "$mode" != "0" ]]; then
    ready="NO"
    reason="${reason} injector_not_idle"
fi

if [[ "$freeze_active" != "FALSE" ]]; then
    ready="NO"
    reason="${reason} freeze_already_active"
fi

if [[ "$fault_active" != "FALSE" ]]; then
    ready="NO"
    reason="${reason} fault_injector_active"
fi

if [[ "$fault" != "FALSE" ]]; then
    ready="NO"
    reason="${reason} watchdog_fault_present"
fi

if [[ "$latched" != "FALSE" ]]; then
    ready="NO"
    reason="${reason} watchdog_fault_latched"
fi

if [[ "$track" != "FALSE" ]]; then
    ready="NO"
    reason="${reason} tracking_error_present"
fi

if [[ "$stall" != "FALSE" ]]; then
    ready="NO"
    reason="${reason} stall_already_present"
fi

echo "READY_FOR_STALL_TEST=$ready"
echo "REASON=${reason# }"
echo "finished=$(date '+%F %T')"
