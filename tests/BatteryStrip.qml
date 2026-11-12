import QtQuick
import QtQuick.Window
import ".."

// Every battery level the number has to read at:
//   QT_QPA_PLATFORM=offscreen qml6 tests/BatteryStrip.qml -- <outdir> dark|light
Window {
  id: win
  width: 520
  height: 50
  visible: true
  color: Theme.dark ? "#1f2335" : "#eff1f5"
  readonly property var args: Qt.application.arguments
  readonly property string outDir: args.length > 1 ? args[args.length - 2] : "/tmp"
  readonly property bool light: args.length > 0 && args[args.length - 1] === "light"
  Component.onCompleted: if (light) Theme.apply(({ mode: "light", accent: "#1e66f5", background: "#eff1f5", foreground: "#4c4f69" }))
  Column {
    anchors.centerIn: parent
    spacing: 14
    Repeater {
      model: 1
      delegate: Rectangle {
        width: 500
        height: 30
        radius: 8
        color: Theme.bodySolid
        Row {
          anchors.centerIn: parent
          spacing: 14
          Repeater {
            model: [0.04, 0.15, 0.3, 0.44, 0.5, 0.56, 0.7, 0.9, 1.0]
            delegate: BatteryIcon { required property var modelData; level: modelData; size: 32 }
          }
        }
      }
    }
  }
  Timer {
    interval: 400; running: true
    onTriggered: win.contentItem.grabToImage(function(r) { r.saveToFile(win.outDir + "/battery-" + (win.light ? "light" : "dark") + ".png"); Qt.quit() })
  }
}
