import QtQuick
import QtQuick.Window
import qs.Commons as Commons
import "../look/dock"

// Renders notch-look's dock pieces off screen, a dock on each edge of a
// made-up screen, with an open app, the app in use and a hovered name:
//   QT_QPA_PLATFORM=offscreen qml6 -I tests/mock tests/DockHarness.qml -- <outdir> dark|light
// tests/mock stands in for Omarchy's qs.Commons (colours, fonts, motion).
Window {
  id: win
  width: 980
  height: 640
  visible: true
  color: "#808080"

  readonly property var args: Qt.application.arguments
  readonly property string outDir: args.length > 1 ? args[args.length - 2] : "/tmp"
  readonly property bool light: args.length > 0 && args[args.length - 1] === "light"
  Component.onCompleted: {
    if (light) {
      Commons.Color.popups.background = Qt.rgba(0.937, 0.945, 0.961, 0.86)   // Catppuccin Latte
      Commons.Color.popups.text = "#4c4f69"
      Commons.Color.bar.text = "#4c4f69"
    }
    shot.start()
  }

  readonly property int iconSize: 40
  readonly property int iconInset: 9
  readonly property int slotSize: iconSize + 2 * iconInset
  // name, colour, open, in use, hovered
  readonly property var apps: [
    ["Files", "#9aa0a6", false, false, false],
    ["Google Chrome", "#4285f4", true, true, true],
    ["Terminal", "#2e3440", true, false, false],
    ["Calculator", "#3b4252", false, false, false],
    ["Telegram", "#2aabee", true, false, false],
  ]

  // A busy, bright wallpaper: the dock has to hold its own on it.
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: win.light ? "#bcd3f2" : "#3a2f5b" }
      GradientStop { position: 0.5; color: win.light ? "#f2d7e6" : "#c46b6b" }
      GradientStop { position: 1; color: win.light ? "#fbe7cf" : "#f2a65a" }
    }
  }
  Repeater {
    model: 14
    delegate: Rectangle {
      x: (index * 137) % win.width
      y: (index * 89) % win.height
      width: 60 + (index % 4) * 30
      height: width
      radius: width / 2
      color: index % 2 ? "#33ffffff" : "#26000000"
    }
  }

  component Dock: Item {
    id: dock
    property string edge: "bottom"
    readonly property bool vertical: edge === "left" || edge === "right"
    width: vertical ? win.slotSize : win.slotSize * (win.apps.length + 1)
    height: vertical ? win.slotSize * (win.apps.length + 1) : win.slotSize

    DockGlass { edge: dock.edge }

    Grid {
      columns: dock.vertical ? 1 : win.apps.length + 1

      // The all-apps button.
      Item {
        width: win.slotSize
        height: win.slotSize
        Grid {
          anchors.centerIn: parent
          columns: 3
          spacing: 4
          Repeater {
            model: 9
            delegate: Rectangle { width: 9; height: 9; radius: 2; color: Commons.Color.bar.text }
          }
        }
        DockSeparator { vertical: dock.vertical; slotSize: win.slotSize; length: Math.round(win.iconSize * 0.6) }
      }

      Repeater {
        model: win.apps
        delegate: Item {
          required property var modelData
          width: win.slotSize
          height: win.slotSize
          Rectangle {
            x: win.iconInset
            y: win.iconInset
            width: win.iconSize
            height: win.iconSize
            radius: 10
            color: modelData[1]
            scale: modelData[4] ? 1.12 : 1
            transformOrigin: dock.edge === "bottom" ? Item.Bottom : dock.edge === "top" ? Item.Top
              : dock.edge === "left" ? Item.Left : Item.Right
          }
          DockDot {
            running: modelData[2]
            focused: modelData[3]
            edge: dock.edge
            slotSize: win.slotSize
            iconInset: win.iconInset
          }
          DockLabel {
            text: modelData[0]
            shown: modelData[4]
            edge: dock.edge
            slotSize: win.slotSize
          }
        }
      }
    }
  }

  Dock { edge: "bottom"; x: Math.round((win.width - width) / 2); y: win.height - height }
  Dock { edge: "top"; x: Math.round((win.width - width) / 2); y: 0 }
  Dock { edge: "left"; x: 0; y: Math.round((win.height - height) / 2) }
  Dock { edge: "right"; x: win.width - width; y: Math.round((win.height - height) / 2) }

  // Long enough for the dots, labels and springs to settle.
  Timer {
    id: shot
    interval: 900
    onTriggered: win.contentItem.grabToImage(function(result) {
      result.saveToFile(win.outDir + "/dock-" + (win.light ? "light" : "dark") + ".png")
      Qt.quit()
    })
  }
}
