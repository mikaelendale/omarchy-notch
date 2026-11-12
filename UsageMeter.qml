import QtQuick
import "Palette.js" as P

// A plan limit as a thin bar: its name, how much is used, and a fill that
// turns orange past 75% and red past 90%.
Column {
  id: root

  property string label: ""
  property real percent: 0     // 0..1

  readonly property color tint: percent >= 0.9 ? Theme.red : (percent >= 0.75 ? Theme.orange : Theme.green)

  width: 88
  spacing: 5

  Item {
    width: parent.width
    height: 13
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      textFormat: Text.PlainText
      color: Theme.secondary
      font.family: P.sans
      font.pixelSize: 10
      font.weight: Font.Medium
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(Math.max(0, root.percent) * 100) + "%"
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
    }
  }
  Rectangle {
    width: parent.width
    height: 4
    radius: 2
    color: Theme.hairline
    Rectangle {
      height: parent.height
      radius: 2
      width: Math.max(4, Math.min(1, root.percent) * parent.width)
      color: root.tint
    }
  }
}
