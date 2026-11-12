import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// A concave corner piece: fills the corner of its square that two black
// shapes meet in, curving away from the opposite corner, so the join reads as
// one shape poured from the other instead of two boxes touching.
//
// corner: which corner is filled. "bottomRight" (the default drawing), then
// rotated for "bottomLeft", "topLeft" and "topRight".
Item {
  id: root

  property real size: 8
  property string corner: "bottomRight"
  property color color: Theme.body

  width: size
  height: size
  rotation: corner === "bottomLeft" ? 90 : corner === "topLeft" ? 180 : corner === "topRight" ? 270 : 0

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: root.color
      strokeWidth: -1
      strokeColor: "transparent"
      startX: root.size
      startY: root.size
      PathLine { x: root.size; y: 0 }
      PathArc {
        x: 0; y: root.size
        radiusX: root.size; radiusY: root.size
        direction: PathArc.Clockwise
      }
      PathLine { x: root.size; y: root.size }
    }
  }
}
