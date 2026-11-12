import QtQuick
import "Palette.js" as P

// One icon in the side notch's strip. A soft circle shows behind it while
// it's hovered or its tab is out. Click and scroll are passed on.
Item {
  id: root

  property int glyph: 0
  property color tint: Theme.text
  property bool lit: false
  property bool blocked: false     // the press was a drag of the strip, not a click

  signal tapped()
  signal scrolled(real step)

  Rectangle {
    anchors.centerIn: parent
    width: 34
    height: 34
    radius: 17
    color: root.lit || hover.hovered ? Theme.card : "transparent"
    scale: root.lit || hover.hovered ? 1 : 0.92
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
  }
  Text {
    anchors.centerIn: parent
    text: root.glyph ? String.fromCodePoint(root.glyph) : ""
    textFormat: Text.PlainText
    color: root.tint
    font.family: P.glyphs
    font.pixelSize: 17
    scale: tap.pressed ? 0.9 : 1
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { id: tap; onTapped: if (!root.blocked) root.tapped() }
  WheelHandler {
    onWheel: function(event) {
      var d = event.angleDelta.y || event.angleDelta.x
      if (d !== 0) root.scrolled(d > 0 ? 0.05 : -0.05)
    }
  }
}
