import QtQuick
import QtQuick.Window
// Frame timing for any version of the notch, same scene each time (music
// playing, two agents at work): frames drawn per second at idle, and for
// opening and closing the notch: how long until it's settled, how many
// frames, and the longest gap between two frames.
//   QT_QPA_PLATFORM=offscreen qml6 tests/BenchFrames.qml -- <smooth|light|off>
// To see it on a weak machine: run it inside
//   systemd-run --user --scope -p CPUQuota=15% -p MemoryMax=300M -- taskset -c 0 ...
Window {
  id: win
  width: 1920; height: 340; visible: true; color: "#5a4a6a"
  readonly property string level: Qt.application.arguments[Qt.application.arguments.length - 1]
  property var status: ({ wifi: { kind: "wifi", strength: 0.8 }, battery: { present: true, level: 0.8 }, workspaces: [], privacy: ({}) })
  property var media: ({ available: true, playing: true, title: "Song", artist: "Artist", position: 30, length: 200 })
  property var claude: ({ sessions: [{ agent: "claude", state: "working" }, { agent: "codex", state: "working" }], counts: { working: 2 } })
  Loader { id: l; source: Qt.resolvedUrl("../Ear.qml"); x: 0
    onLoaded: { item.side = "left"; item.items = ["media"]; item.status = win.status; item.media = win.media; item.hoverEnabled = false } }
  Loader { id: n; source: Qt.resolvedUrl("../Notch.qml"); x: (win.width - width) / 2
    onLoaded: { item.items = ["agents", "clock"]; item.status = win.status; item.media = win.media; item.claude = win.claude; item.seeThroughWhenIdle = false } }
  Component.onCompleted: {
    if (level !== "default") {
      try { Qt.createQmlObject('import QtQuick; import ".."; QtObject { Component.onCompleted: Motion.level = "' + level + '" }', win) } catch (e) {}
    }
  }
  property bool recording: false
  property var swaps: []
  onFrameSwapped: if (recording) swaps.push(Date.now())
  property var result: ({})
  property double t0: 0
  property string phase: "warm"
  function gaps(list) { var g = 0; for (var i = 1; i < list.length; i++) g = Math.max(g, list[i] - list[i - 1]); return g }
  Timer {
    id: step; interval: 1000; running: true
    onTriggered: {
      if (win.phase === "warm") { win.phase = "idle"; win.swaps = []; win.recording = true; win.t0 = Date.now(); step.interval = 3000; step.start(); return }
      if (win.phase === "idle") {
        win.result.idleFps = Math.round(win.swaps.length / ((Date.now() - win.t0) / 1000) * 10) / 10
        win.phase = "open"; win.swaps = []; win.t0 = Date.now(); n.item.forceOpen = true; watch.start(); return
      }
    }
  }
  Timer {
    id: watch; interval: 1; repeat: true
    onTriggered: {
      var p = n.item.progress
      var done = win.phase === "open" ? p >= 0.999 : p <= 0.001
      if (!done) return
      watch.stop()
      var ms = Date.now() - win.t0
      win.result[win.phase] = { settledMs: ms, frames: win.swaps.length, worstGapMs: win.gaps([win.t0].concat(win.swaps)) }
      if (win.phase === "open") { win.phase = "close"; win.swaps = []; win.t0 = Date.now(); n.item.forceOpen = false; watch.start() }
      else { console.log("RESULT " + JSON.stringify(win.result)); Qt.quit() }
    }
  }
  Timer { running: true; interval: 15000; onTriggered: { console.log("RESULT timeout " + JSON.stringify(win.result)); Qt.quit() } }
}
