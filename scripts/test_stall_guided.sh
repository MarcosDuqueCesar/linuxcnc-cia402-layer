#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$WORKSPACE" || exit 1

qdir="${WORKSPACE}/analysis_stall_wd_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$qdir"

cleanup() {
  halcmd net fb-units motion_wd.pos-fb >/dev/null 2>&1 || true
  halcmd sets motion-watchdog-reset TRUE >/dev/null 2>&1 || true
  sleep 0.1
  halcmd sets motion-watchdog-reset FALSE >/dev/null 2>&1 || true
  halcmd setp motion_wd.tracking-error-limit 0.25 >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo '===== PRECHECK =====' | tee "$qdir/00_precheck.txt"
halcmd show pin motion_wd.pos-fb | tee -a "$qdir/00_precheck.txt"
halcmd show sig motion-req | tee -a "$qdir/00_precheck.txt"
halcmd getp motion_wd.fault | tee -a "$qdir/00_precheck.txt"
halcmd getp motion_wd.fault-latched | tee -a "$qdir/00_precheck.txt"
halcmd getp motion_wd.first-fault-code | tee -a "$qdir/00_precheck.txt"
halcmd getp motion_wd.stall | tee -a "$qdir/00_precheck.txt"
halcmd getp motion_wd.response-timeout | tee -a "$qdir/00_precheck.txt"

echo
echo '===== PREP ====='
echo '1) No Axis, carregue um G-code com movimento X longo o suficiente.'
echo '2) Exemplo simples: G91 / G1 X50 F300 / M2'
echo '3) Ainda NAO clique Run.'
read -r -p 'Quando o G-code estiver carregado no Axis, pressione ENTER... '

halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
halcmd setp motion_wd.tracking-error-limit 999999

echo
echo 'Agora clique RUN no Axis.'
read -r -p 'Assim que clicar RUN, volte aqui e pressione ENTER... '

echo '===== WAIT MOVING_SEEN =====' | tee "$qdir/01_wait_moving_seen.txt"
moving_ok=0
for i in $(seq 1 120); do
  armed="$(halcmd getp motion_wd.armed 2>/dev/null | tail -n1)"
  mv="$(halcmd getp motion_wd.moving-seen 2>/dev/null | tail -n1)"
  req="$(halcmd getp motion_wd.motion-req 2>/dev/null | tail -n1)"
  pcmd="$(halcmd getp motion_wd.pos-cmd 2>/dev/null | tail -n1)"
  pfb="$(halcmd getp motion_wd.pos-fb 2>/dev/null | tail -n1)"
  echo "loop=$i armed=$armed moving_seen=$mv motion_req=$req pos_cmd=$pcmd pos_fb=$pfb" | tee -a "$qdir/01_wait_moving_seen.txt"
  if [ "$mv" = "TRUE" ]; then
    moving_ok=1
    break
  fi
  sleep 0.1
done

if [ "$moving_ok" -ne 1 ]; then
  echo 'ABORT: moving-seen nao virou TRUE.' | tee "$qdir/ABORT.txt"
  exit 1
fi

echo
echo 'Movimento confirmado. Vou congelar o feedback do watchdog.'
read -r -p 'Pressione ENTER para injetar o stall... '

frozen_fb="$(halcmd getp fb-units | tail -n1)"
halcmd unlinkp motion_wd.pos-fb
halcmd setp motion_wd.pos-fb "$frozen_fb"

echo '===== FREEZE =====' | tee "$qdir/02_freeze.txt"
echo "frozen_fb=$frozen_fb" | tee -a "$qdir/02_freeze.txt"
halcmd show pin motion_wd.pos-fb | tee -a "$qdir/02_freeze.txt"
halcmd getp motion_wd.pos-cmd | tee -a "$qdir/02_freeze.txt"
halcmd getp motion_wd.pos-fb | tee -a "$qdir/02_freeze.txt"
halcmd getp fb-units | tee -a "$qdir/02_freeze.txt"

echo '===== WAIT STALL =====' | tee "$qdir/03_wait_stall.txt"
for i in $(seq 1 200); do
  stall_now="$(halcmd getp motion_wd.stall 2>/dev/null | tail -n1)"
  latched_now="$(halcmd getp motion_wd.fault-latched 2>/dev/null | tail -n1)"
  code_now="$(halcmd getp motion_wd.first-fault-code 2>/dev/null | tail -n1)"
  fault_now="$(halcmd getp motion_wd.fault 2>/dev/null | tail -n1)"
  pcmd="$(halcmd getp motion_wd.pos-cmd 2>/dev/null | tail -n1)"
  pfb="$(halcmd getp motion_wd.pos-fb 2>/dev/null | tail -n1)"
  echo "loop=$i fault=$fault_now latched=$latched_now code=$code_now stall=$stall_now pos_cmd=$pcmd pos_fb=$pfb" | tee -a "$qdir/03_wait_stall.txt"
  if [ "$stall_now" = "TRUE" ] || { [ "$latched_now" = "TRUE" ] && [ "$code_now" = "2" ]; }; then
    echo "STALL_DETECTED loop=$i" | tee -a "$qdir/03_wait_stall.txt"
    break
  fi
  sleep 0.1
done

halcmd net fb-units motion_wd.pos-fb

halcmd sets motion-watchdog-reset TRUE
sleep 0.1
halcmd sets motion-watchdog-reset FALSE
halcmd setp motion_wd.tracking-error-limit 0.25

echo '===== FINAL =====' | tee "$qdir/04_final.txt"
halcmd show pin motion_wd.pos-fb | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.fault | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.fault-latched | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.first-fault-code | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.stall | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.response-timeout | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.tracking-error | tee -a "$qdir/04_final.txt"
halcmd getp motion_wd.tracking-error-limit | tee -a "$qdir/04_final.txt"

zip -r "${qdir}.zip" "$qdir" >/dev/null 2>&1 || true

echo
echo "ARTIFACT_DIR=$qdir"
echo "ARTIFACT_ZIP=${qdir}.zip"
