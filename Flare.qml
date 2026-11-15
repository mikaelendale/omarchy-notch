import QtQuick
import QtQuick.Shapes

// The small curve where the notch (or a corner, or the unified bar) meets
// the edge it hangs from: a square with a quarter circle taken out, filled
// on the side that touches both edges, with the rim along the curve.
//
// It's always the same size, so it's traced once; when the notch opens it's
// only moved, never redrawn, which is what keeps opening cheap. (The bodies
// themselves are plain rounded rectangles.)
//
// By default the filled side is the top-right of the square: it touches the
// top edge and, on its right, the side of what hangs down (the notch's left
// flare). `mirrored` fills the top-left instead (the notch's right flare).
Item {
  id: root

  property real size: 12
  property bool mirrored: false
  property color color: Theme.body
  property color edgeColor: Theme.edge

  width: size
  height: size

  function px(x) { return mirrored ? size - x : x }

  Shape {
    anchors.fill: parent
    visible: root.size > 0.5
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: -1
      strokeColor: "transparent"
      fillColor: root.color
      startX: root.px(root.size)
      startY: 0
      PathLine { x: root.px(root.size); y: root.size }
      PathArc {
        x: root.px(0); y: 0
        radiusX: root.size; radiusY: root.size
        direction: root.mirrored ? PathArc.Clockwise : PathArc.Counterclockwise
      }
    }
    // The rim, along the curve only.
    ShapePath {
      fillColor: "transparent"
      strokeWidth: 1
      strokeColor: root.edgeColor
      startX: root.px(0)
      startY: 0
      PathArc {
        x: root.px(root.size); y: root.size
        radiusX: root.size; radiusY: root.size
        direction: root.mirrored ? PathArc.Counterclockwise : PathArc.Clockwise
      }
    }
  }
}
