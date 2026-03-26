#!/usr/bin/env bash
set -euo pipefail

# READ-ONLY OBSERVER
# Não escreve nada no HAL
# Apenas monitora sinais relevantes em tempo real

DURATION="${1:-8}"
INTERVAL="${2:-0.2}"

end_ts=$(awk -v d="$DURATION" 'BEGIN{print systime()+d}')

echo "=== OBSERVE MOTION WD WINDOW (READ ONLY) ==="
echo "duration=${DURATION}s interval=${INTERVAL}s"
echo "started=$(date '+%F %T')"
echo "------------------------------------------------------------"

printf "%-12s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
"time" "armed" "mreq" "pos_cmd" "pos_fb" "fb_in" "fb_out" "fault" "lat" "track" "stall" "mode"

while awk -v now="$(date +%s)" -v end="$end_ts" 'BEGIN{exit !(now <= end)}'; do
    t=$(date '+%H:%M:%S')

    armed=$(halcmd getp motion_wd.armed 2>/dev/null || echo "NA")
    mreq=$(halcmd getp motion_wd.motion-req 2>/dev/null || echo "NA")

    pos_cmd=$(halcmd getp motion_wd.pos-cmd 2>/dev/null || echo "NA")
    pos_fb=$(halcmd getp motion_wd.pos-fb 2>/dev/null || echo "NA")

    fb_in=$(halcmd getp fault_inj_x.pos-fb-in 2>/dev/null || echo "NA")
    fb_out=$(halcmd getp fault_inj_x.pos-fb-out 2>/dev/null || echo "NA")

    fault=$(halcmd getp motion_wd.fault 2>/dev/null || echo "NA")
    lat=$(halcmd getp motion_wd.fault-latched 2>/dev/null || echo "NA")

    track=$(halcmd getp motion_wd.tracking-error 2>/dev/null || echo "NA")
    stall=$(halcmd getp motion_wd.stall 2>/dev/null || echo "NA")

    mode=$(halcmd getp fault_inj_x.mode 2>/dev/null || echo "NA")

    printf "%-12s %-6s %-6s %-10s %-10s %-10s %-10s %-6s %-6s %-6s %-6s %-6s\n" \
      "$t" "$armed" "$mreq" "$pos_cmd" "$pos_fb" "$fb_in" "$fb_out" "$fault" "$lat" "$track" "$stall" "$mode"

    sleep "$INTERVAL"
done

echo "------------------------------------------------------------"
echo "finished=$(date '+%F %T')"
