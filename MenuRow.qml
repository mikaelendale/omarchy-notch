import QtQuick
import "Palette.js" as P

// A row in a tray app's menu: its label, a check if it's ticked, an arrow if
// it opens a submenu. Underscores (keyboard-accelerator marks) are dropped.
Rectangle {
  id: row

  property string label: ""
  property bool checked: false
  property bool more: false
  signal activated()

  height: 30
  radius: 8
  color: rowHover.hovered && row.enabled ? Theme.cardHover : "transparent"
  Behavior on color { ColorAnimation { duration: 100 } }

  Text {
    x: 10
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width - 20 - (row.more ? 14 : 0)
    text: (row.checked ? "✓  " : "") + row.label.replace(/_/g, "")
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: row.enabled ? Theme.text : Theme.tertiary
    font.family: P.sans
    font.pixelSize: 13
  }
  Text {
    visible: row.more
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: "›"
    textFormat: Text.PlainText
    color: Theme.secondary
    font.family: P.sans
    font.pixelSize: 14
  }
  HoverHandler { id: rowHover; cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
  TapHandler { enabled: row.enabled; onTapped: row.activated() }
}
