import QtQuick
import "Palette.js" as P

// A round switch for one mode: filled with the mode's colour while it's on.
Item {
  id: root

  property bool on: false
  property color tint: Theme.blue
  property int glyph: 0
  property string label: ""
  property real size: 44
  property bool blocked: false     // the press was a drag, not a click

  signal toggled()
  readonly property bool hovered: hover.hovered

  width: size
  height: size

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: root.on ? root.tint : (root.hovered ? Theme.cardHover : Theme.card)
    scale: press.pressed ? 0.92 : 1
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    Text {
      anchors.centerIn: parent
      text: root.glyph ? String.fromCodePoint(root.glyph) : ""
      textFormat: Text.PlainText
      color: root.on ? Theme.contrastOn(root.tint) : Theme.secondary
      font.family: P.glyphs
      font.pixelSize: root.size * 0.42
      Behavior on color { ColorAnimation { duration: 140 } }
    }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { id: press; onTapped: if (!root.blocked) root.toggled() }
}
