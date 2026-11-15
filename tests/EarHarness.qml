import QtQuick
import QtQuick.Window
import ".."

// Renders the top edge off screen: the notch with a corner on each side, with
// made-up data, and saves a frame:
//   QT_QPA_PLATFORM=offscreen qml6 tests/EarHarness.qml -- <outdir> [scenario]
// Scenarios: closed, paused, quiet (nothing playing), left (the player open),
// right (the details open), everything (every item on the bar, both corners
// full), steps (the left corner opening, a tenth at a time). A "-light"
// suffix draws it in a light theme.
Window {
  id: win
  width: 1440
  height: 360
  visible: true
  color: "#d9d7d2"

  readonly property var args: Qt.application.arguments
  readonly property string outDir: args.length > 1 ? args[args.length - 2] : "/tmp"
  readonly property string rawScenario: args.length > 0 ? args[args.length - 1] : "closed"
  readonly property bool light: rawScenario.indexOf("-light") !== -1
  readonly property string scenario: rawScenario.replace("-light", "").replace("float-", "").replace("unified-", "")
  // A "float-" prefix draws the floating look (a pill below the edge), a
  // "unified-" prefix the unified one (one strip across the top).
  readonly property bool floating: rawScenario.indexOf("float-") === 0
  readonly property bool unified: rawScenario.indexOf("unified-") === 0
  Component.onCompleted: if (light) Theme.apply(({ mode: "light", accent: "#1e66f5", background: "#eff1f5", foreground: "#4c4f69" }))

  readonly property var layout: scenario === "everything"
    ? ({ left: ["media", "agents", "date"], center: ["clock"], right: ["speed", "volume", "wifi", "bluetooth", "battery"] })
    : ({ left: ["workspaces", "media"], center: ["agents", "clock", "privacy"], right: ["wifi", "bluetooth", "battery"] })

  readonly property var status: ({
    wifi: { kind: "wifi", strength: 0.8, name: "Studio 5G" },
    bluetooth: { enabled: true, connected: true, device: "AirPods Pro" },
    battery: { present: true, level: 0.82, charging: false, timeToEmpty: 3 * 3600 + 25 * 60 },
    volume: { level: 0.6, muted: false },
    net: { down: 2340000, up: 118000 },
    workspaces: [{ id: 1, slot: 1, occupied: true }, { id: 2, slot: 2, active: true, occupied: true }, { id: 3, slot: 3, occupied: true }, { id: 4, slot: 4 }, { id: 5, slot: 5 }],
    privacy: { mic: true, micApps: "Google Meet", camera: false, screen: true }
  })
  readonly property var media: scenario === "quiet" ? ({ available: false }) : ({
    available: true, playing: scenario !== "paused",
    title: "Which One (Performance Video)", artist: "JYT", identity: "YouTube Music",
    artUrl: "", position: 127, length: 194,
    canSeek: true, canNext: true, canPrevious: true, canRaise: true,
    shuffleSupported: true, shuffle: false, loopSupported: true, loop: "playlist",
    rateSupported: false, rate: 1,
    players: [{ key: "a", name: "YouTube Music" }, { key: "b", name: "Spotify" }], playerKey: "a"
  })
  readonly property var counts: ({ needs: 0, working: 1 })
  readonly property var lead: ({ agent: "claude", state: "working" })

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: win.light ? "#c9d6ea" : "#3b4a6b" }
      GradientStop { position: 0.55; color: win.light ? "#e8dcef" : "#7a5a78" }
      GradientStop { position: 1; color: win.light ? "#f6e3d3" : "#c08a6a" }
    }
  }

  // The unified strip, stretching as a corner opens (Bar.qml does this on screen).
  readonly property real stripT: win.unified ? Math.max(left.progress, right.progress, centre.progress) : 0
  UnifiedStrip {
    visible: win.unified
    screenWidth: win.width
    expand: win.stripT
    leftDrop: ({ width: left.bodyW, height: left.bodyH - 34 })
    centerDrop: ({ width: centre.bodyW, height: centre.bodyH - 34 })
    rightDrop: ({ width: right.bodyW, height: right.bodyH - 34 })
  }

  Ear {
    id: left
    unified: win.unified
    extraX: win.unified ? 22 * (1 - win.stripT) : 0
    x: 0
    floating: win.floating
    side: "left"
    items: win.layout.left
    status: win.status
    media: win.media
    now: new Date(2026, 10, 15, 18, 41)
    counts: win.counts
    lead: win.lead
    forceOpen: win.scenario === "left"
    hoverEnabled: false
  }

  Notch {
    id: centre
    anchors.horizontalCenter: parent.horizontalCenter
    forceOpen: win.scenario === "notch"
    y: win.floating ? 8 : 0
    floating: win.floating
    unified: win.unified
    items: win.layout.center
    seeThroughWhenIdle: false
    status: win.status
    media: win.media
    now: new Date(2026, 10, 15, 18, 41)
    claude: ({ sessions: [{ label: "Notch corners", state: "working", agent: "claude" }], counts: win.counts })
  }

  Ear {
    id: right
    x: win.width - width
    floating: win.floating
    unified: win.unified
    extraX: win.unified ? 22 * (1 - win.stripT) : 0
    side: "right"
    items: win.layout.right
    status: win.status
    media: win.media
    now: new Date(2026, 10, 15, 18, 41)
    counts: win.counts
    lead: win.lead
    forceOpen: win.scenario === "right" || win.scenario === "everything"
    hoverEnabled: false
  }

  function shot(name) {
    win.contentItem.grabToImage(function(result) { result.saveToFile(win.outDir + "/" + name + ".png") })
  }

  property int step: 0
  Timer {
    id: stepper
    interval: 120
    repeat: true
    onTriggered: {
      left.progress = win.step / 10
      win.shot("ears-step-" + (win.step < 10 ? "0" : "") + win.step)
      win.step++
      if (win.step > 10) { stop(); quit.start() }
    }
  }
  Timer {
    interval: 700
    running: true
    onTriggered: {
      if (win.scenario === "steps") { left.motion = 0; stepper.start(); return }
      win.shot("ears-" + win.rawScenario)
      quit.start()
    }
  }
  Timer { id: quit; interval: 300; onTriggered: Qt.quit() }
}
