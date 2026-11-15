import QtQuick
import QtQuick.Shapes

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
// Drawn for the top-left corner; `mirrored` draws the top-right one, point by
// point (the curve renderer fills the wrong side of a negatively scaled path).
// The item is bodyWidth + flare wide and bodyHeight + flare tall.
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
  // A pill of its own, set in from the corner: every corner rounded, no flares.
  property bool floating: false

  readonly property real f: floating ? 0 : Math.max(0, Math.min(flare, bodyWidth / 2, bodyHeight / 2))
  readonly property real r: floating ? Math.max(0, Math.min(radius, bodyHeight / 2, bodyWidth / 2))
    : Math.max(0, Math.min(radius, bodyHeight - f, bodyWidth - f))
  readonly property real w: bodyWidth + f

  width: w
  height: bodyHeight + f

  function px(x) { return mirrored ? root.w - x : x }
  readonly property int cw: mirrored ? PathArc.Counterclockwise : PathArc.Clockwise
  readonly property int ccw: mirrored ? PathArc.Clockwise : PathArc.Counterclockwise

  Shape {
    anchors.fill: parent
    visible: root.floating && root.bodyWidth > 0.5 && root.bodyHeight > 0.5
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
    visible: !root.floating && root.bodyWidth > 0.5 && root.bodyHeight > 0.5
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

      startX: root.px(0)
      startY: 0
      // Along the top edge, past the body to the start of its flare.
      PathLine { x: root.px(root.bodyWidth + root.f); y: 0 }
      // The flare, curving down into the body's inner side.
      PathArc {
        x: root.px(root.bodyWidth); y: root.f
        radiusX: root.f; radiusY: root.f
        direction: root.ccw
      }
      PathLine { x: root.px(root.bodyWidth); y: root.bodyHeight - root.r }
      // The one rounded corner, away from the screen's corner.
      PathArc {
        x: root.px(root.bodyWidth - root.r); y: root.bodyHeight
        radiusX: root.r; radiusY: root.r
        direction: root.cw
      }
      PathLine { x: root.px(root.f); y: root.bodyHeight }
      // The flare into the side edge, below the body.
      PathArc {
        x: root.px(0); y: root.bodyHeight + root.f
        radiusX: root.f; radiusY: root.f
        direction: root.ccw
      }
      PathLine { x: root.px(0); y: 0 }
    }
  }
}
