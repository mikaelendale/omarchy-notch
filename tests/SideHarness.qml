import QtQuick
import QtQuick.Window
import ".."

// Renders the side notch off screen with made-up data and saves frames:
//   QT_QPA_PLATFORM=offscreen qml6 tests/SideHarness.qml -- <outdir> [scenario]
// Scenarios: open (several states side by side), motion (frames of the
// modes list and a tab opening, in real time).
Window {
  id: win
  width: 1180
  height: 560
  visible: true

  readonly property var args: Qt.application.arguments
  readonly property string outDir: args.length > 1 ? args[args.length - 2] : "/tmp"
  // A "-light" suffix draws it with a light theme (Catppuccin Latte).
  readonly property string rawScenario: args.length > 0 ? args[args.length - 1] : "open"
  readonly property bool light: rawScenario.indexOf("-light") !== -1
  readonly property string scenario: rawScenario.replace("-light", "")
  Component.onCompleted: if (light) Theme.apply(({ mode: "light", accent: "#1e66f5", background: "#eff1f5", foreground: "#4c4f69", red: "#d20f39", yellow: "#df8e1d", green: "#40a02b", cyan: "#179299", blue: "#1e66f5", magenta: "#ea76cb", orange: "#fe640b" }))

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: win.light ? "#dfe6f0" : "#9aa3ad" }
      GradientStop { position: 1; color: win.light ? "#f3ece2" : "#c9c3b6" }
    }
  }

  property var sampleModes: ({ dnd: true, awake: false, nightlight: true, muted: false, layout: "dwindle" })
  property var sampleUsage: ({ ready: true, session: 0.14, weekly: 0.81 })

  // Panel 1: right edge, at rest.
  Item {
    x: 0; width: 290; height: win.height; clip: true
    SideNotch { id: rest; x: parent.width - width; y: 40; modes: win.sampleModes; volume: 0.4; brightness: 0.35; usage: win.sampleUsage }
  }
  // Panel 2: right edge, modes open, a switch's name out.
  Item {
    x: 300; width: 290; height: win.height; clip: true
    SideNotch { id: modesOpen; x: parent.width - width; y: 20; modes: win.sampleModes; volume: 0.4; brightness: 0.35; usage: win.sampleUsage
      Component.onCompleted: { modesOpen.modesOpen = true; modesOpen.active = "mode:nightlight" } }
  }
  // Panel 3: right edge, volume slid out.
  Item {
    x: 600; width: 290; height: win.height; clip: true
    SideNotch { id: vol; x: parent.width - width; y: 40; modes: ({ muted: false }); volume: 0.62; brightness: 0.35; usage: win.sampleUsage
      Component.onCompleted: vol.active = "volume" }
  }
  // Panel 4: left edge, usage slid out.
  Item {
    x: 890; width: 290; height: win.height; clip: true
    SideNotch { id: use; edge: "left"; x: 0; y: 40; modes: ({ muted: true }); volume: 0.62; brightness: 0.35; usage: win.sampleUsage
      Component.onCompleted: use.active = "usage" }
  }

  function shot(name) {
    win.contentItem.grabToImage(function(result) { result.saveToFile(win.outDir + "/" + name + ".png") })
  }
  function pad(n) { return (n < 10 ? "0" : "") + n }

  Timer {
    interval: 700
    running: true
    onTriggered: {
      win.shot("side-" + win.rawScenario)
      if (win.scenario === "motion") { rest.modesOpen = true; rest.active = "volume"; frames.start() }
      else quit.start()
    }
  }
  Timer {
    id: frames
    interval: 20
    repeat: true
    property int count: 0
    onTriggered: {
      win.shot("sidemotion-" + win.pad(count))
      count++
      if (count > 12) { stop(); quit.start() }
    }
  }
  Timer { id: quit; interval: 300; onTriggered: Qt.quit() }
}
