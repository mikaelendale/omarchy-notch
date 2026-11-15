#!/bin/bash
# Renders every notch, corner, editor and dock scenario off screen into a folder,
# for looking at, and runs the pointer tests (drag, click, hover).
#   tests/run.sh [outdir]
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$(mktemp -d)}
mkdir -p "$out"
export QT_QPA_PLATFORM=offscreen
for s in open idle needs toast art steps open-light needs-light toast-light; do timeout 30 qml6 "$here/tests/Harness.qml" -- "$out" "$s" >/dev/null 2>&1; done
# The dock's pieces, on every edge; tests/mock stands in for Omarchy's qs.Commons.
for m in dark light; do timeout 30 qml6 -I "$here/tests/mock" "$here/tests/DockHarness.qml" -- "$out" "$m" >/dev/null 2>&1; done
# The battery's number at every level, where it crosses the fill.
for m in dark light; do timeout 30 qml6 "$here/tests/BatteryStrip.qml" -- "$out" "$m" >/dev/null 2>&1; done
# A crowd of sessions, long names and a full row of buttons.
for s in many many-light many-toast; do timeout 30 qml6 "$here/tests/Harness.qml" -- "$out" "$s" >/dev/null 2>&1; done
# The corners beside the notch, closed and open, and the editor.
for s in closed paused quiet left right everything steps closed-light left-light right-light; do timeout 30 qml6 "$here/tests/EarHarness.qml" -- "$out" "$s" >/dev/null 2>&1; done
for s in editor dragging everything charging editor-light; do timeout 30 qml6 "$here/tests/EditorHarness.qml" -- "$out" "$s" >/dev/null 2>&1; done
for t in tst_notch tst_editor; do
  QT_QPA_PLATFORM=offscreen timeout 60 /usr/lib/qt6/bin/qmltestrunner -input "$here/tests/$t.qml" 2>&1 | grep -E "^(FAIL|Totals)" | sed "s/^/$t: /" || true
done
count=$(ls "$out"/*.png 2>/dev/null | wc -l)
echo "$count frames in $out"
[[ $count -ge 30 ]]
