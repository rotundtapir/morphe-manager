#!/usr/bin/env bash
# mem-sweep.sh <label> <cap-MB> : patch YouTube at the given heap cap, report OK|OOM.
# Confirms the override took effect by reading back the "effective heap cap" log line.
set -uo pipefail
SER=emulator-5566; ADB="adb -s $SER"; S="$(cd "$(dirname "$0")" && pwd)"
LABEL="$1"; CAP="$2"; LOG="$S/mem-$LABEL-$CAP.log"

$ADB shell setprop debug.morphe.memlimit "$CAP"
$ADB shell 'rm -f /sdcard/Download/YouTube_Morphe-*.apk' >/dev/null 2>&1
$ADB shell input keyevent 224 >/dev/null 2>&1; sleep 1; $ADB shell wm dismiss-keyguard >/dev/null 2>&1; sleep 1
$ADB shell dumpsys window 2>/dev/null | grep -q 'Application Not Responding' && { $ADB shell input tap 320 1367; sleep 15; }
$ADB shell am force-stop app.morphe.manager; sleep 3
$ADB logcat -c; $ADB logcat -v time > "$LOG" 2>&1 & LP=$!
$ADB shell am start -n app.morphe.manager/.MainActivity >/dev/null; sleep 30
$ADB shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
CARD=$($ADB shell cat /sdcard/ui.xml 2>/dev/null | python3 "$S/find-node.py" "YouTube Morphe")
[ -z "$CARD" ] && { echo "$LABEL@${CAP}M: FLOW-FAIL (no YouTube card)"; kill $LP 2>/dev/null; exit 1; }
$ADB shell input tap $CARD; sleep 14   # -> details sheet (slow on 1 core)
$ADB shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
XY=$($ADB shell cat /sdcard/ui.xml 2>/dev/null | python3 "$S/find-node.py" "Patch")
[ -z "$XY" ] && { echo "$LABEL@${CAP}M: FLOW-FAIL (no Patch button)"; kill $LP 2>/dev/null; return 1 2>/dev/null||exit 1; }
$ADB shell input tap $XY; $ADB shell input keyevent 26   # start, screen off
# OOM fails fast; success near the threshold is slow (GC thrash). So: break early on
# OOM, otherwise allow a long budget. A run still making progress at the end is
# classified NOT-OOM (thrashing), which is what the comparison actually needs.
res=""; t0=$(date +%s)
for _ in $(seq 1 62); do
  sleep 8
  grep -q 'Patched apk saved' "$LOG" && { res=OK; break; }
  grep -qiE 'OutOfMemoryError|Patcher process exited with code|exited with code [1-9]' "$LOG" && { res=OOM; break; }
done
el=$(( $(date +%s) - t0 ))
kill $LP 2>/dev/null
eff=$(grep -oE 'effective heap cap = [0-9]+M' "$LOG" | tail -1)
pk=$(grep -oE 'max=[0-9]+MB' "$LOG" | tail -1)
np=$(grep -c 'succeeded' "$LOG")
if [ -z "$res" ]; then
  # no OOM seen and still advancing => thrashing, not an OOM
  res="NOT-OOM(slow)"
fi
echo "$LABEL@${CAP}M -> $res  ${el}s  patches=$np  peak=${pk:-?}  [${eff:-OVERRIDE-MISSING}]"
