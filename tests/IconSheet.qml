import QtQuick
import QtQuick.Window
import ".."

// Every status icon in its states, on the notch's black, for looking at:
//   QT_QPA_PLATFORM=offscreen qml6 tests/IconSheet.qml -- <outdir> icons
Window {
  id: win
  width: 760
  height: 220
  visible: true
  color: "black"
  readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 2]

  Rectangle { anchors.fill: parent; color: "#000000" }
  Column {
    x: 20; y: 16; spacing: 22
    Row {
      spacing: 26
      WifiIcon { strength: 1 }
      WifiIcon { strength: 0.5 }
      WifiIcon { strength: 0.2 }
      WifiIcon { connected: false }
      BluetoothIcon { connected: true }
      BluetoothIcon { enabled_: true }
      BluetoothIcon { enabled_: false }
      VolumeIcon { level: 0.9 }
      VolumeIcon { level: 0.5 }
      VolumeIcon { level: 0.2 }
      VolumeIcon { muted: true }
      DisplayIcon {}
      UsageDial { percent: 0.14 }
      UsageDial { percent: 0.81 }
    }
    Row {
      spacing: 26
      BatteryIcon { level: 0.82 }
      BatteryIcon { level: 0.45; charging: true }
      BatteryIcon { level: 0.12 }
      ClaudeLogo { size: 18 }
      ClaudeLogo { size: 18; working: true }
      ClaudeLogo { size: 18; needs: true }
      ClaudeLogo { size: 30 }
      ClaudeLogo { size: 30; working: true }
      ClaudeLogo { size: 30; needs: true }
      ClaudeLogo { size: 30; reveal: 0.35 }
      ClaudeLogo { size: 30; reveal: 0.7 }
    }
    Row {
      spacing: 26
      WifiIcon { size: 22; strength: 1 }
      BatteryIcon { size: 32; level: 0.82 }
      BluetoothIcon { size: 22; connected: true }
      VolumeIcon { size: 22; level: 0.7 }
      ClaudeLogo { size: 44 }
    }
  }
  Timer {
    interval: 900; running: true
    onTriggered: win.contentItem.grabToImage(function(r) { r.saveToFile(win.outDir + "/icons.png"); Qt.quit() })
  }
}
