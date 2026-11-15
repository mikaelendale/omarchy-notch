import QtQuick
import QtQuick.Window
import ".."

// Renders the top bar's editor off screen, with made-up data:
//   QT_QPA_PLATFORM=offscreen qml6 tests/EditorHarness.qml -- <outdir> [scenario]
// Scenarios: editor, dragging (Wi-Fi on its way to the left corner),
// everything (every item on the bar). A "-light" suffix draws it light.
Window {
  id: win
  width: 1000
  height: 760
  visible: true
  color: "#d9d7d2"

  readonly property var args: Qt.application.arguments
  readonly property string outDir: args.length > 1 ? args[args.length - 2] : "/tmp"
  readonly property string rawScenario: args.length > 0 ? args[args.length - 1] : "editor"
  readonly property bool light: rawScenario.indexOf("-light") !== -1
  readonly property string scenario: rawScenario.replace("-light", "")
  Component.onCompleted: if (light) Theme.apply(({ mode: "light", accent: "#1e66f5", background: "#eff1f5", foreground: "#4c4f69" }))

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: win.light ? "#c9d6ea" : "#3b4a6b" }
      GradientStop { position: 0.55; color: win.light ? "#e8dcef" : "#7a5a78" }
      GradientStop { position: 1; color: win.light ? "#f6e3d3" : "#c08a6a" }
    }
  }

  Editor {
    id: editor
    anchors.centerIn: parent
    layout: win.scenario === "everything"
      ? ({ left: ["media", "agents", "date"], center: ["clock"], right: ["speed", "volume", "wifi", "bluetooth", "battery"] })
      : ({ left: ["w:omarchy.weather", "media"], center: ["agents", "clock"], right: ["wifi", "bluetooth", "battery"] })
    buttons: [
      { id: "omarchy.keyboard-layout", name: "Keyboard layout" }, { id: "mike.claude-sessions", name: "Claude sessions" },
      { id: "omarchy.agents", name: "Agents" }, { id: "omarchy.bluetooth", name: "Bluetooth" },
      { id: "omarchy.network", name: "Network" }, { id: "omarchy.audio", name: "Audio" },
      { id: "omarchy.monitor", name: "Monitor" }, { id: "omarchy.power", name: "Power" },
      { id: "omarchy.indicators", name: "Indicators" }, { id: "omarchy.elsewhen", name: "Elsewhen" },
      { id: "omarchy.weather", name: "Weather" }, { id: "omarchy.system-update", name: "System update" }
    ]
    status: ({
      wifi: { kind: "wifi", strength: 0.8, name: "Studio 5G" },
      bluetooth: { enabled: true, connected: true, device: "AirPods Pro" },
      battery: { present: true, level: win.scenario === "charging" ? 1 : 0.82, charging: win.scenario === "charging" },
      volume: { level: 0.6, muted: false },
      net: { down: 2340000, up: 118000 }
    })
    media: ({ available: true, playing: true, title: "Which One", artist: "JYT" })
    screens: [{ id: "eDP-1", name: "Laptop" }, { id: "HDMI-A-1", name: "LG HDR 4K" }]
    now: new Date(2026, 10, 15, 18, 41)
    lead: ({ agent: "claude", state: "working" })
  }

  function shot(name) {
    win.contentItem.grabToImage(function(result) { result.saveToFile(win.outDir + "/" + name + ".png") })
  }

  Timer {
    interval: 600
    running: true
    onTriggered: {
      if (win.scenario === "picked") {
        var list0 = editor.chips()
        for (var j = 0; j < list0.length; j++) if (list0[j].chipId === "wifi") editor.pick(list0[j])
      }
      if (win.scenario === "dragging") {
        // Pick Wi-Fi up from the right corner and hold it over the left one.
        var c = null
        var list = editor.chips()
        for (var i = 0; i < list.length; i++) if (list[i].chipId === "wifi") c = list[i]
        var from = c.mapToItem(editor, c.width / 2, c.height / 2)
        editor.dragKind = "item"
        editor.dragId = "wifi"
        editor.dragPoint = Qt.point(150, from.y)
        editor.updateDrag()
      }
      later.start()
    }
  }
  Timer { id: later; interval: 400; onTriggered: { win.shot("editor-" + win.rawScenario); quit.start() } }
  Timer { id: quit; interval: 300; onTriggered: Qt.quit() }
}
