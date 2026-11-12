import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// A screen on a stand: the displays panel.
Item {
  id: root

  property color color: Theme.text
  property real size: 16

  width: size
  height: size * 0.82

  Rectangle {
    width: root.size
    height: root.size * 0.6
    radius: root.size * 0.12
    color: "transparent"
    border.color: root.color
    border.width: Math.max(1.2, root.size * 0.1)
  }
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.size * 0.68
    width: root.size * 0.44
    height: Math.max(1.4, root.size * 0.1)
    radius: height / 2
    color: root.color
  }
}
