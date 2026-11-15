import QtQuick

// The notch's body: a slab hanging from the top edge of the screen. Where it
// meets the edge it flares out in two concave curves, so it reads as part of
// the screen's frame rather than a card floating under it.
//
//   (0,0) ─────────────────────────────────────── (W+2F, 0)
//      ╲_ flare                             flare _╱
//        │                                       │
//        ╰──────────────── body ─────────────────╯
//
// bodyWidth/bodyHeight are the slab without its flares; the item is
// bodyWidth + 2*flare wide. Floating, it's a pill of its own: every corner
// rounded, no flares.
//
// Built from a plain rounded rectangle and two fixed flares (Flare.qml), so
// opening and closing the notch only resizes a rectangle and moves the
// flares: nothing is re-traced on each frame.
Item {
  id: root

  property real bodyWidth: 200
  property real bodyHeight: 34
  property real radius: 17
  property real flare: 12
  property color color: Theme.body          // frost
  property color topColor: Theme.bodyTop    // a little light at the top edge
  property color edgeColor: Theme.edge
  property bool floating: false

  readonly property real f: floating ? 0 : flare
  readonly property real r: floating ? Math.max(0, Math.min(radius, bodyHeight / 2, bodyWidth / 2))
    : Math.max(0, Math.min(radius, bodyHeight - f, bodyWidth / 2))

  width: bodyWidth + 2 * f
  height: bodyHeight

  Rectangle {
    id: body
    x: root.f
    width: root.bodyWidth
    height: root.bodyHeight
    visible: width > 0.5 && height > 0.5
    topLeftRadius: root.floating ? root.r : 0
    topRightRadius: root.floating ? root.r : 0
    bottomLeftRadius: root.r
    bottomRightRadius: root.r
    gradient: Gradient {
      GradientStop { position: 0; color: root.topColor }
      GradientStop { position: 1; color: root.color }
    }
    border.width: root.floating ? 1 : 0
    border.color: root.edgeColor
  }

  // Attached: the rim down the sides (below the flares) and along the bottom.
  Item {
    visible: !root.floating && body.visible
    x: root.f
    y: root.f
    width: root.bodyWidth
    height: Math.max(0, root.bodyHeight - root.f)
    clip: true
    Rectangle {
      y: -root.f
      width: root.bodyWidth
      height: root.bodyHeight
      color: "transparent"
      border.width: 1
      border.color: root.edgeColor
      bottomLeftRadius: root.r
      bottomRightRadius: root.r
    }
  }

  Flare {
    visible: root.f > 0.5 && body.visible
    size: root.f
    color: root.topColor
    edgeColor: root.edgeColor
  }
  Flare {
    visible: root.f > 0.5 && body.visible
    x: root.f + root.bodyWidth
    size: root.f
    mirrored: true
    color: root.topColor
    edgeColor: root.edgeColor
  }
}
