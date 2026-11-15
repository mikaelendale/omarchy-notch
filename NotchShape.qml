import QtQuick
import QtQuick.Shapes

// The notch's body: a black slab hanging from the top edge of the screen.
// Where it meets the edge it flares out in two concave curves, so it reads
// as part of the screen's frame rather than a card floating under it.
//
//   (0,0) ─────────────────────────────────────── (W+2F, 0)
//      ╲_ flare                             flare _╱
//        │                                       │
//        ╰──────────────── body ─────────────────╯
//
// bodyWidth/bodyHeight are the slab without its flares; the item is
// bodyWidth + 2*flare wide.
Item {
  id: root

  property real bodyWidth: 200
  property real bodyHeight: 34
  property real radius: 17
  property real flare: 12
  property color color: Theme.body          // frost
  property color topColor: Theme.bodyTop    // a little light at the top edge
  property color edgeColor: Theme.edge
  // A pill of its own, below the edge: every corner rounded, no flares.
  property bool floating: false

  readonly property real r: floating ? Math.max(0, Math.min(radius, bodyHeight / 2, bodyWidth / 2))
    : Math.max(0, Math.min(radius, bodyHeight - flare, bodyWidth / 2))
  readonly property real f: floating ? 0 : flare

  width: bodyWidth + 2 * flare
  height: bodyHeight

  Shape {
    anchors.fill: parent
    visible: root.floating
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
      startX: root.r
      startY: 0
      PathLine { x: root.bodyWidth - root.r; y: 0 }
      PathArc { x: root.bodyWidth; y: root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
      PathLine { x: root.bodyWidth; y: root.bodyHeight - root.r }
      PathArc { x: root.bodyWidth - root.r; y: root.bodyHeight; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
      PathLine { x: root.r; y: root.bodyHeight }
      PathArc { x: 0; y: root.bodyHeight - root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
      PathLine { x: 0; y: root.r }
      PathArc { x: root.r; y: 0; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
    }
  }

  Shape {
    anchors.fill: parent
    visible: !root.floating
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

      startX: 0
      startY: 0

      // Along the screen edge.
      PathLine { x: root.bodyWidth + 2 * root.f; y: 0 }
      // Right flare, curving down into the slab's side.
      PathArc {
        x: root.bodyWidth + root.f; y: root.f
        radiusX: root.f; radiusY: root.f
        direction: PathArc.Counterclockwise
      }
      PathLine { x: root.bodyWidth + root.f; y: root.bodyHeight - root.r }
      // Bottom-right corner.
      PathArc {
        x: root.bodyWidth + root.f - root.r; y: root.bodyHeight
        radiusX: root.r; radiusY: root.r
        direction: PathArc.Clockwise
      }
      PathLine { x: root.f + root.r; y: root.bodyHeight }
      // Bottom-left corner.
      PathArc {
        x: root.f; y: root.bodyHeight - root.r
        radiusX: root.r; radiusY: root.r
        direction: PathArc.Clockwise
      }
      PathLine { x: root.f; y: root.f }
      // Left flare, back up to the screen edge.
      PathArc {
        x: 0; y: 0
        radiusX: root.f; radiusY: root.f
        direction: PathArc.Counterclockwise
      }
    }
  }
}
