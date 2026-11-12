import QtQuick
import QtQuick.Window
import ".."

// Renders the notch off screen with made-up data and saves frames:
//   QT_QPA_PLATFORM=offscreen qml6 tests/Harness.qml -- <outdir> [scenario]
// Scenarios: open, idle, needs, toast, art (cover-tinted music card), steps, motion.
Window {
  id: win
  width: 1100
  height: 300
  visible: true
  color: "#d9d7d2"

  readonly property var args: Qt.application.arguments
  readonly property string outDir: args.length > 1 ? args[args.length - 2] : "/tmp"
  // A "-light" suffix draws it with a light theme (Catppuccin Latte).
  readonly property string rawScenario: args.length > 0 ? args[args.length - 1] : "motion"
  readonly property bool light: rawScenario.indexOf("-light") !== -1
  readonly property string scenario: rawScenario.replace("-light", "")
  Component.onCompleted: if (light) Theme.apply(({ mode: "light", accent: "#1e66f5", background: "#eff1f5", foreground: "#4c4f69", red: "#d20f39", yellow: "#df8e1d", green: "#40a02b", cyan: "#179299", blue: "#1e66f5", magenta: "#ea76cb", orange: "#fe640b" }))

  // A soft backdrop, so the black reads the way it will on a wallpaper.
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: win.light ? "#c9d6ea" : "#6b4a78" }
      GradientStop { position: 0.55; color: win.light ? "#e8dcef" : "#c56a6f" }
      GradientStop { position: 1; color: win.light ? "#f6e3d3" : "#e8a46a" }
    }
  }

  Notch {
    id: notch
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    now: new Date(2026, 10, 12, 14, 41)
    status: ({ wifi: { kind: "wifi", strength: 0.8 }, battery: { present: true, level: 0.82, charging: false } })
    alert: win.scenario === "toast" ? ({ title: "Claude needs you", detail: "Super shift C shortcut needs permission", session: null }) : null
    media: win.scenario === "idle" ? ({ available: false }) : ({
      available: true, playing: true, title: "Glow", artist: "Echo", identity: "Spotify",
      artUrl: win.scenario === "art" ? "file:///usr/share/omarchy/themes/tokyo-night/preview.png" : "", position: 80, length: 215
    })
    claude: win.scenario === "idle" ? ({ sessions: [], counts: {} }) : ({
      counts: { needs: win.scenario === "needs" ? 1 : 0, working: 1, done: 1 },
      sessions: [
        { label: "Super shift C shortcut for conversations window", state: win.scenario === "needs" ? "needs" : "working" },
        { label: "Google Drive installation", state: "done" },
        { label: "RAVN landing copy pass", state: "idle" }
      ]
    })

    Component.onCompleted: {
      // Stand-ins for the round buttons the bar lends the open notch: the
      // Omarchy menu, Omarchy's widgets, and tray apps.
      function chip(glyph, parent) {
        Qt.createQmlObject('import QtQuick; import ".."; Item { width: 38; height: 32; Rectangle { width: 32; height: 32; radius: 16; color: Theme.card; Text { anchors.centerIn: parent; color: Theme.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; text: String.fromCodePoint(' + glyph + ') } } }', parent)
      }
      chip(0xF08C7, notch.menuSlot)
      var status = [0xF0F65, 0xF0E9F, 0xF00AF, 0xF05A9, 0xF057E, 0xF0379, 0xF0079, 0xF0590, 0xF0337]
      for (var i = 0; i < status.length; i++) chip(status[i], notch.statusSlot)
      var tray = [0xF0E3D, 0xF069B, 0xF02D6]
      for (var j = 0; j < tray.length; j++) chip(tray[j], notch.traySlot)
    }
  }

  property int frame: 0
  function shot(name) {
    win.contentItem.grabToImage(function(result) { result.saveToFile(win.outDir + "/" + name + ".png") })
  }
  function pad(n) { return (n < 10 ? "0" : "") + n }

  Timer {
    id: frames
    interval: 30
    repeat: true
    property int count: 0
    property string prefix: "open"
    onTriggered: {
      win.shot(prefix + "-" + win.pad(count))
      count++
      if (count > 14) { stop(); done.start() }
    }
  }
  Timer {
    id: done
    interval: 200
    onTriggered: {
      if (frames.prefix === "open" && win.scenario === "motion") {
        win.shot("open-final")
        frames.prefix = "close"
        frames.count = 0
        notch.forceOpen = false
        frames.start()
      } else {
        win.shot(frames.prefix + "-final")
        quitTimer.start()
      }
    }
  }
  Timer { id: quitTimer; interval: 300; onTriggered: Qt.quit() }

  Timer {
    interval: 600
    running: true
    onTriggered: {
      win.shot("closed-" + win.rawScenario)
      if (win.scenario === "steps") {
        notch.motion = 0
        stepper.start()
      } else if (win.scenario === "motion") {
        notch.forceOpen = true
        frames.start()
      } else if (win.scenario === "toast") {
        openShot.start()
      } else if (win.scenario === "open" || win.scenario === "idle" || win.scenario === "art") {
        notch.forceOpen = true
        openShot.start()
      } else {
        quitTimer.start()
      }
    }
  }
  // Every tenth of the way from closed to open: each frame of the morph is a
  // function of progress alone, so this is every frame there is to see.
  Timer {
    id: stepper
    interval: 120
    repeat: true
    property int step: 0
    onTriggered: {
      if (step > 10) { stop(); quitTimer.start(); return }
      notch.progress = step / 10
      Qt.callLater(function() { win.shot("step-" + win.pad(stepper.step - 1)) })
      step++
    }
  }
  Timer { id: openShot; interval: 700; onTriggered: { win.shot("open-" + win.rawScenario); quitTimer.start() } }
}
