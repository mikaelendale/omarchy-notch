import QtQuick

// A corner pill's body: a slab tucked into a top corner of the screen. It
// flares into the top edge on its inner side and into the side edge below
// it, so it reads as the screen's frame thickening in the corner, the way
// the notch flares into the top edge.
//
//   (0,0) ──────────────╮_ flare (into the top edge)
//   │      body         │
//   │                  ╭╯
//   │_ ────────────────╯
//   ╱  flare (into the side edge)
//
// Drawn for the top-left corner; `mirrored` draws the top-right one. The item
// is bodyWidth + flare wide and bodyHeight + flare tall. Floating, it's a
// pill of its own: every corner rounded, no flares.
//
// Built from a plain rounded rectangle and two fixed flares (Flare.qml), so
// opening a corner only resizes a rectangle and moves the flares.
Item {
  id: root

  property real bodyWidth: 120
  property real bodyHeight: 34
  property real radius: 17
  property real flare: 12
  property bool mirrored: false
  property color color: Theme.body
  property color topColor: Theme.bodyTop
  property color edgeColor: Theme.edge
  property bool floating: false

  readonly property real f: floating ? 0 : Math.max(0, Math.min(flare, bodyWidth / 2, bodyHeight / 2))
  readonly property real r: floating ? Math.max(0, Math.min(radius, bodyHeight / 2, bodyWidth / 2))
    : Math.max(0, Math.min(radius, bodyHeight - f, bodyWidth - f))

  width: bodyWidth + f
  height: bodyHeight + f

  // Where the body starts: against the screen's side edge.
  readonly property real bodyX: mirrored ? f : 0

  Rectangle {
    id: body
    x: root.bodyX
    width: root.bodyWidth
    height: root.bodyHeight
    visible: width > 0.5 && height > 0.5
    topLeftRadius: root.floating ? root.r : 0
    topRightRadius: root.floating ? root.r : 0
    bottomLeftRadius: root.floating || root.mirrored ? root.r : 0
    bottomRightRadius: root.floating || !root.mirrored ? root.r : 0
    gradient: Gradient {
      GradientStop { position: 0; color: root.topColor }
      GradientStop { position: 1; color: root.color }
    }
    border.width: root.floating ? 1 : 0
    border.color: root.edgeColor
  }

  // Attached: the rim down the inner side (below the top flare) and along
  // the bottom (clear of the side flare).
  Item {
    visible: !root.floating && body.visible
    x: root.mirrored ? root.f : root.f
    y: root.f
    width: Math.max(0, root.bodyWidth - root.f)
    height: Math.max(0, root.bodyHeight - root.f)
    clip: true
    Rectangle {
      x: root.mirrored ? 0 : -root.f
      y: -root.f
      width: root.bodyWidth
      height: root.bodyHeight
      color: "transparent"
      border.width: 1
      border.color: root.edgeColor
      bottomLeftRadius: root.mirrored ? root.r : 0
      bottomRightRadius: root.mirrored ? 0 : root.r
    }
  }

  // Into the top edge, on the inner side.
  Flare {
    visible: root.f > 0.5 && body.visible
    x: root.mirrored ? 0 : root.bodyWidth
    size: root.f
    mirrored: !root.mirrored
    color: root.topColor
    edgeColor: root.edgeColor
  }
  // Into the side edge, under the body.
  Flare {
    visible: root.f > 0.5 && body.visible
    x: root.mirrored ? root.width - root.f : 0
    y: root.bodyHeight
    size: root.f
    mirrored: !root.mirrored
    color: root.color
    edgeColor: root.edgeColor
  }
}
