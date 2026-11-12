pragma Singleton
import QtQuick

// Stands in for Omarchy's qs.Commons.Color in the off-screen dock tests:
// Everforest's panel colours with notch-look's frosted alpha.
QtObject {
  property QtObject popups: QtObject {
    property color background: Qt.rgba(0.176, 0.208, 0.231, 0.86)
    property color text: "#d3c6aa"
  }
  property QtObject bar: QtObject { property color text: "#d3c6aa" }
  property color accent: "#a7c080"
}
