#!/usr/bin/env bash
set -euo pipefail

# stall_test_orchestrator.sh
#
# Uso:
#   ./scripts/stall_test_orchestrator.sh [observe_seconds] [sample_interval] [inject_seconds]
#
# Exemplo:
#   ./scripts/stall_test_orchestrator.sh 12 0.2 4.5
#
# IMPORTANTE:
# - Este script assume que o LinuxCNC e o HAL correto já estão carregados.
# - Este script NÃO inicia G-code.
# - O G-code deve já estar rodando antes de executar este script.
# - O script prepara o estado lógico do watchdog, observa, injeta stall e resume o resultado.

OBSERVE_SECONDS="${1:-12}"
SAMPLE_INTERVAL="${2:-0.2}"
INJECT_SECONDS="${3:-4.5}"

readp() {
    halcmd getp "$1" 2>/dev/null || echo "NA"
}

clear_injector() {
    halcmd sets fi-inject-fault FALSE
    halcmd sets fi-inject-fault-reaction FALSE
    halcmd sets fi-inject-stall FALSE
    halcmd sets fi-inject-response-timeout FALSE
    halcmd sets fi-inject-tracking FALSE
    halcmd sets fi-reset TRUE
    sleep 0.1
    halcmd sets fi-reset FALSE
}

print_preflight() {
    local armed mreq allow_motion mcsp_ready pos_cmd pos_fb fb_in fb_out fault latched track stall mode freeze_active fault_active

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

    echo "=== PREFLIGHT ==="
    printf "%-28s %s\n" "motion_wd.armed"           "$armed"
    printf "%-28s %s\n" "motion_wd.motion-req"      "$mreq"
    printf "%-28s %s\n" "msg.allow-motion"          "$allow_motion"
    printf "%-28s %s\n" "mcsp.ready"                "$mcsp_ready"
    printf "%-28s %s\n" "motion_wd.pos-cmd"         "$pos_cmd"
    printf "%-28s %s\n" "motion_wd.pos-fb"          "$pos_fb"
    printf "%-28s %s\n" "fault_inj_x.pos-fb-in"     "$fb_in"
    printf "%-28s %s\n" "fault_inj_x.pos-fb-out"    "$fb_out"
    printf "%-28s %s\n" "motion_wd.fault"           "$fault"
    printf "%-28s %s\n" "motion_wd.fault-latched"   "$latched"
    printf "%-28s %s\n" "motion_wd.tracking-error"  "$track"
    printf "%-28s %s\n" "motion_wd.stall"           "$stall"
    printf "%-28s %s\n" "fault_inj_x.mode"          "$mode"
    printf "%-28s %s\n" "fault_inj_x.freeze-active" "$freeze_active"
    printf "%-28s %s\n" "fault_inj_x.fault-active"  "$fault_active"

    local ready="YES"
    local reason=""

    [[ "$armed" == "TRUE" ]] || { ready="NO"; reason+=" motion_wd_not_armed"; }
    [[ "$mreq" == "TRUE" ]] || { ready="NO"; reason+=" motion_req_false"; }
    [[ "$allow_motion" == "TRUE" ]] || { ready="NO"; reason+=" allow_motion_false"; }
    [[ "$mcsp_ready" == "TRUE" ]] || { ready="NO"; reason+=" mcsp_not_ready"; }
    [[ "$mode" == "0" ]] || { ready="NO"; reason+=" injector_not_idle"; }
    [[ "$freeze_active" == "FALSE" ]] || { ready="NO"; reason+=" freeze_already_active"; }
    [[ "$fault_active" == "FALSE" ]] || { ready="NO"; reason+=" fault_injector_active"; }
    [[ "$fault" == "FALSE" ]] || { ready="NO"; reason+=" watchdog_fault_present"; }
    [[ "$latched" == "FALSE" ]] || { ready="NO"; reason+=" watchdog_fault_latched"; }
    [[ "$track" == "FALSE" ]] || { ready="NO"; reason+=" tracking_error_present"; }
    [[ "$stall" == "FALSE" ]] || { ready="NO"; reason+=" stall_already_present"; }

    echo "READY_FOR_STALL_TEST=$ready"
    echo "REASON=${reason# }"

    [[ "$ready" == "YES" ]]
}

observe_window() {
    local duration="$1"
    local interval="$2"
    local inject_after="$3"
    local inject_for="$4"

    local start_ts now elapsed
    start_ts=$(date +%s)

    echo "=== OBSERVATION WINDOW ==="
    echo "observe_seconds=$duration sample_interval=$interval inject_after=$inject_after inject_for=$inject_for"
    echo "------------------------------------------------------------"
    printf "%-12s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
      "time" "armed" "mreq" "pos_cmd" "pos_fb" "fb_in" "fb_out" "fault" "lat" "track" "stall" "mode"

    local injected="FALSE"

    while true; do
        now=$(date +%s)
        elapsed=$((now - start_ts))
        [[ "$elapsed" -le "$duration" ]] || break

        if [[ "$injected" == "FALSE" && "$elapsed" -ge "$inject_after" ]]; then
            halcmd sets fi-inject-stall TRUE
            injected="TRUE"
            inject_start_ts=$(date +%s)
        fi

        if [[ "$injected" == "TRUE" ]]; then
            local inject_elapsed=$((now - inject_start_ts))
            if [[ "$inject_elapsed" -ge "$inject_for" ]]; then
                halcmd sets fi-inject-stall FALSE
                injected="DONE"
            fi
        fi

        local t armed mreq pos_cmd pos_fb fb_in fb_out fault lat track stall mode
        t=$(date '+%H:%M:%S')
        armed="$(readp motion_wd.armed)"
        mreq="$(readp motion_wd.motion-req)"
        pos_cmd="$(readp motion_wd.pos-cmd)"
        pos_fb="$(readp motion_wd.pos-fb)"
        fb_in="$(readp fault_inj_x.pos-fb-in)"
        fb_out="$(readp fault_inj_x.pos-fb-out)"
        fault="$(readp motion_wd.fault)"
        lat="$(readp motion_wd.fault-latched)"
        track="$(readp motion_wd.tracking-error)"
        stall="$(readp motion_wd.stall)"
        mode="$(readp fault_inj_x.mode)"

        printf "%-12s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
          "$t" "$armed" "$mreq" "$pos_cmd" "$pos_fb" "$fb_in" "$fb_out" "$fault" "$lat" "$track" "$stall" "$mode"

        sleep "$interval"
    done

    halcmd sets fi-inject-stall FALSE
    echo "------------------------------------------------------------"
}

echo "=== STALL TEST ORCHESTRATOR ==="
echo "started=$(date '+%F %T')"
echo "ASSUMPTION: G-code is already running"
echo

echo "[1/4] clearing injector and watchdog state"
clear_injector
halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
sleep 0.1

echo "[2/4] asserting motion-req"
halcmd sets motion-req TRUE
sleep 0.3

echo "[3/4] preflight"
if ! print_preflight; then
    echo
    echo "STALL TEST ABORTED: preflight not ready"
    echo "finished=$(date '+%F %T')"
    exit 2
fi

echo
echo "[4/4] observing and injecting stall"
# inject after 2 seconds of observation
observe_window "$OBSERVE_SECONDS" "$SAMPLE_INTERVAL" 2 "$INJECT_SECONDS"

echo "=== FINAL STATE ==="
printf "%-28s %s\n" "motion_wd.fault"          "$(readp motion_wd.fault)"
printf "%-28s %s\n" "motion_wd.fault-latched"  "$(readp motion_wd.fault-latched)"
printf "%-28s %s\n" "motion_wd.stall"          "$(readp motion_wd.stall)"
printf "%-28s %s\n" "motion_wd.first-fault-code" "$(readp motion_wd.first-fault-code)"
printf "%-28s %s\n" "fault_inj_x.mode"         "$(readp fault_inj_x.mode)"
printf "%-28s %s\n" "fault_inj_x.freeze-active" "$(readp fault_inj_x.freeze-active)"

echo
echo "finished=$(date '+%F %T')"
echo "NOTE: script leaves motion-req asserted; clear manually if desired:"
echo "  halcmd sets motion-req FALSE"
echo "  halcmd sets motion-watchdog-reset TRUE"
echo "  sleep 0.1"
echo "  halcmd sets motion-watchdog-reset FALSE"
