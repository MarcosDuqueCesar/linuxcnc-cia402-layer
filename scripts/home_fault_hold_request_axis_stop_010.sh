#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$SCRIPT_DIR"

runid="home_fault_hold_request_axis_stop_010"

echo "============================================================"
echo "RUN: $runid"
echo "============================================================"

# ------------------------------------------------------------
# BASELINE
# ------------------------------------------------------------
./run_and_stage_log.sh snapshot "${runid}_baseline" log

echo
echo '=== ACTION REQUIRED IN AXIS ==='
echo 'Confirm the G-code is loaded, then click RUN'
echo 'When motion has actually started, press ENTER here'
read -r

# ------------------------------------------------------------
# RUNNING
# ------------------------------------------------------------
./single_axis_ctl.sh sleep 1.0
./run_and_stage_log.sh snapshot "${runid}_running_pre_requests" log

# ------------------------------------------------------------
# ENABLE MOTION (CSP)
# ------------------------------------------------------------
echo ">>> Enabling motion request (CSP)"
halcmd sets motion-req TRUE
./single_axis_ctl.sh sleep 0.3
./run_and_stage_log.sh snapshot "${runid}_csp_engaged" log

# ------------------------------------------------------------
# ENABLE HOME REQUEST
# ------------------------------------------------------------
echo ">>> Enabling home request"
halcmd sets home-req TRUE
./single_axis_ctl.sh sleep 0.3
./run_and_stage_log.sh snapshot "${runid}_home_active" log

./single_axis_ctl.sh sleep 0.5
./run_and_stage_log.sh snapshot "${runid}_home_settle" log

# ------------------------------------------------------------
# AXIS STOP
# ------------------------------------------------------------
echo
echo '=== ACTION REQUIRED IN AXIS ==='
echo 'Click STOP'
echo 'When the program has actually stopped, press ENTER here'
read -r

./run_and_stage_log.sh snapshot "${runid}_axis_stopped_home_request_held" log

# ------------------------------------------------------------
# INJECT FAULT
# ------------------------------------------------------------
echo ">>> Injecting fault"
halcmd setp adapter.inject-fault TRUE
./single_axis_ctl.sh sleep 0.3
./run_and_stage_log.sh snapshot "${runid}_home_fault_after_axis_stop" log

# ------------------------------------------------------------
# CLEAR FAULT
# ------------------------------------------------------------
echo ">>> Clearing fault"
halcmd setp adapter.inject-fault FALSE
halcmd sets fault-reset-req TRUE
./single_axis_ctl.sh sleep 0.3
./run_and_stage_log.sh snapshot "${runid}_home_fault_clear_after_axis_stop" log

halcmd sets fault-reset-req FALSE

./single_axis_ctl.sh sleep 0.5
./run_and_stage_log.sh snapshot "${runid}_home_post_clear_after_axis_stop" log

# ------------------------------------------------------------
# RELEASE HOME
# ------------------------------------------------------------
echo ">>> Releasing home request"
halcmd sets home-req FALSE
./single_axis_ctl.sh sleep 0.3
./run_and_stage_log.sh snapshot "${runid}_home_release" log

./single_axis_ctl.sh sleep 0.5
./run_and_stage_log.sh snapshot "${runid}_csp_recovered" log

# ------------------------------------------------------------
# DISABLE MOTION
# ------------------------------------------------------------
echo ">>> Disabling motion request"
halcmd sets motion-req FALSE
./single_axis_ctl.sh sleep 0.3
./run_and_stage_log.sh snapshot "${runid}_motionreq_off" log

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------
./run_and_stage_log.sh snapshot "${runid}_final" log

# ------------------------------------------------------------
# PACKAGE ZIP
# ------------------------------------------------------------
echo
echo ">>> Packaging logs into ZIP"

mkdir -p "${WORKSPACE}/outbox"
zipname="${WORKSPACE}/outbox/${runid}.zip"

zip -j "$zipname" "${WORKSPACE}/logs"/*"${runid}"*.log

echo
echo "ZIP generated:"
echo "  $zipname"
echo
