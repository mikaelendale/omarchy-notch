import QtQuick
import "Palette.js" as P

// A rounded track that fills from the left, with the glyph riding on it.
// Drag, click or scroll to set the level.
Item {
  id: root

  property real value: 0.5          // 0..1
  property int glyph: 0
  property bool dimmed: false

  signal moved(real value)

  width: 140
  height: 24

  function setFrom(x) { root.moved(Math.max(0, Math.min(1, x / width))) }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Theme.card
    clip: true
    Rectangle {
      height: parent.height
      width: Math.max(parent.height, Math.min(1, Math.max(0, root.value)) * parent.width)
      radius: height / 2
      color: root.dimmed ? Theme.tertiary : Theme.text
      Behavior on width { NumberAnimation { duration: drag.active ? 0 : 90; easing.type: Easing.OutCubic } }
    }
    Text {
      x: 7
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph ? String.fromCodePoint(root.glyph) : ""
      textFormat: Text.PlainText
      color: root.dimmed ? Theme.secondary : Theme.onText
      font.family: P.glyphs
      font.pixelSize: 13
    }
  }

  DragHandler {
    id: drag
    target: null
    yAxis.enabled: false
    onCentroidChanged: if (active) root.setFrom(centroid.position.x)
  }
  TapHandler { onTapped: function(point) { root.setFrom(point.position.x) } }
  WheelHandler {
    onWheel: function(event) {
      var step = (event.angleDelta.y || event.angleDelta.x) > 0 ? 0.05 : -0.05
      root.moved(Math.max(0, Math.min(1, root.value + step)))
    }
  }
  HoverHandler { cursorShape: Qt.PointingHandCursor }
}
