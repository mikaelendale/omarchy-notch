import QtQuick
import QtQuick.Shapes

// The side notch's body: a black slab growing out of the right screen edge,
// flaring into the edge above and below with concave curves (the top notch's
// shape, turned on its side). Mirror it for the left edge.
//
//            flare ╲ │ (screen edge)
//   ╭──────────────╯ │
//   │     body       │
//   ╰──────────────╮ │
//            flare ╱ │
//
// The item is bodyWidth wide and bodyHeight + 2*flare tall; the edge is its
// right side.
Item {
  id: root

  property real bodyWidth: 12
  property real bodyHeight: 64
  property real radius: 6
  property real flare: 12
  property color color: Theme.body          // frost
  property color topColor: Theme.bodyTop    // a little light at the top edge
  property color edgeColor: Theme.edge
  property bool mirrored: false   // true: grows out of the left edge

  readonly property real f: Math.min(flare, bodyWidth)
  readonly property real r: Math.max(0, Math.min(radius, bodyWidth - f, bodyHeight / 2))

  width: bodyWidth
  height: bodyHeight + 2 * f

  // The left-edge version is drawn mirrored point by point rather than with
  // a negative scale: the curve renderer fills the wrong side of a flipped path.
  function px(x) { return mirrored ? bodyWidth - x : x }
  readonly property int cw: mirrored ? PathArc.Counterclockwise : PathArc.Clockwise
  readonly property int ccw: mirrored ? PathArc.Clockwise : PathArc.Counterclockwise

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 1
      strokeColor: root.edgeColor
      fillGradient: LinearGradient {
        x1: 0; y1: 0
        x2: 0; y2: root.height
        GradientStop { position: 0; color: root.topColor }
        GradientStop { position: 1; color: root.color }
      }

      startX: root.px(root.bodyWidth)
      startY: 0

      // Top flare, from the edge into the slab's top side.
      PathArc {
        x: root.px(root.bodyWidth - root.f); y: root.f
        radiusX: root.f; radiusY: root.f
        direction: root.cw
      }
      PathLine { x: root.px(root.r); y: root.f }
      // Top-left corner.
      PathArc {
        x: root.px(0); y: root.f + root.r
        radiusX: root.r; radiusY: root.r
        direction: root.ccw
      }
      PathLine { x: root.px(0); y: root.f + root.bodyHeight - root.r }
      // Bottom-left corner.
      PathArc {
        x: root.px(root.r); y: root.f + root.bodyHeight
        radiusX: root.r; radiusY: root.r
        direction: root.ccw
      }
      PathLine { x: root.px(root.bodyWidth - root.f); y: root.f + root.bodyHeight }
      // Bottom flare, back out to the edge.
      PathArc {
        x: root.px(root.bodyWidth); y: root.bodyHeight + 2 * root.f
        radiusX: root.f; radiusY: root.f
        direction: root.cw
      }
      PathLine { x: root.px(root.bodyWidth); y: 0 }
    }
  }
}
