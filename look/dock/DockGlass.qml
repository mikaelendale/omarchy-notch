import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

// notch-look: the dock's body, in the notch's language. It sits flush on the
// screen edge and flares into it in two concave curves, like the notch hanging
// from the top edge, so the two read as a pair. Frosted: the theme's own panel
// colour over Hyprland's blur, a little light along the top, and a soft rim
// (light on dark themes, dark on light ones).
//
// A child of the dock's body (the row of icons), it draws itself around it:
// `padding` past the first and last icon, the flares past that, and a couple
// of pixels beyond the screen edge, so no outline shows along the edge.
Item {
  id: root

  property string edge: "bottom"      // the screen edge the dock is on
  property real padding: 6
  property real flare: 12
  property real radius: 18
  readonly property real overhang: 2

  readonly property color base: Commons.Color.popups.background
  readonly property bool dark: 0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b < 0.5
  readonly property color sheen: Qt.tint(base, Qt.rgba(1, 1, 1, dark ? 0.06 : 0.34))
  readonly property color rim: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.09)

  readonly property bool vertical: edge === "left" || edge === "right"
  // Along the edge (with the padding, without the flares), and in from it.
  readonly property real along: (vertical ? parent.height : parent.width) + 2 * padding
  readonly property real depth: vertical ? parent.width : parent.height
  readonly property real f: Math.max(0, Math.min(flare, depth / 2))
  readonly property real r: Math.max(0, Math.min(radius, depth - f, along / 2))
  readonly property real span: along + 2 * f
  readonly property real thick: depth + overhang

  x: vertical ? (edge === "left" ? -overhang : 0) : -(padding + f)
  y: vertical ? -(padding + f) : (edge === "top" ? -overhang : 0)
  width: vertical ? thick : span
  height: vertical ? span : thick
  z: -1

  // A point given along the edge (u) and in from the dock's free side (w: 0
  // there, `depth` at the screen edge), in this item's coordinates.
  function at(u, w) {
    if (edge === "top") return (u) + " " + (thick - w)
    if (edge === "left") return (thick - w) + " " + (u)
    if (edge === "right") return (w) + " " + (u)
    return (u) + " " + (w)
  }

  // Drawn as if on the bottom edge, then turned to whichever edge it's on.
  // Quarter circles as cubic curves (k is the usual 0.5523).
  readonly property string outline: {
    var k = 0.5523, S = span, D = depth, F = f, R = r, O = overhang
    return "M " + at(0, D)
      + " C " + at(k * F, D) + " " + at(F, D - F + k * F) + " " + at(F, D - F)
      + " L " + at(F, R)
      + " C " + at(F, R - k * R) + " " + at(F + R - k * R, 0) + " " + at(F + R, 0)
      + " L " + at(S - F - R, 0)
      + " C " + at(S - F - R + k * R, 0) + " " + at(S - F, R - k * R) + " " + at(S - F, R)
      + " L " + at(S - F, D - F)
      + " C " + at(S - F, D - F + k * F) + " " + at(S - k * F, D) + " " + at(S, D)
      + " L " + at(S, D + O)
      + " L " + at(0, D + O)
      + " Z"
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 1
      strokeColor: root.rim
      fillGradient: LinearGradient {
        x1: 0; y1: 0
        x2: 0; y2: root.height
        GradientStop { position: 0; color: root.sheen }
        GradientStop { position: 1; color: root.base }
      }
      PathSvg { path: root.outline }
    }
  }
}
