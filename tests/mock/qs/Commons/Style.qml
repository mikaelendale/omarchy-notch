pragma Singleton
import QtQuick

// Stands in for Omarchy's qs.Commons.Style in the off-screen dock tests.
QtObject {
  property real fontScale: 1
  property bool reduceMotion: false
  function duration(ms) { return ms }
  property QtObject font: QtObject {
    property string family: "Adwaita Sans"
    property int body: 12
  }
}
