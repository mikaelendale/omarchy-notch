import QtQuick
import QtQuick.Shapes

// The unified bar: one long slab hanging from the top edge, flaring into it
// at both ends like the notch, with a gap from either side of the screen.
// When anything on it opens (the notch or a corner) it stretches out to the
// screen's edges and what opens grows down out of it.
//
// It's all one outline (the bar and whatever hangs from it), so where an open
// corner or the notch meets the bar there's no seam and no second layer of
// glass: each opening flares into the bar's underside the way the notch
// flares into the screen's edge.
//
// expand: 0 (a gap at either side) to 1 (edge to edge); the bar springs it.
// leftDrop, centerDrop, rightDrop: { width, height } of what hangs below the
// bar (height 0 when shut). The left and right ones sit flush with the bar's
// ends; the centre one is centred.
Item {
  id: root

  property real screenWidth: 1920
  property real gap: 10
  property real flare: 12
  property real barHeight: 34
  property real expand: 0
  property var leftDrop: ({ width: 0, height: 0 })
  property var centerDrop: ({ width: 0, height: 0 })
  property var rightDrop: ({ width: 0, height: 0 })
  property real dropRadius: 26
  property color color: Theme.body
  property color topColor: Theme.bodyTop
  property color edgeColor: Theme.edge

  function mix(a, b, t) { return a + (b - a) * t }

  // The body runs from L to R; the end flares reach `flare` beyond.
  readonly property real reach: mix(gap + flare, 0, expand)
  readonly property real dropMax: Math.max(leftDrop.height || 0, centerDrop.height || 0, rightDrop.height || 0)

  width: screenWidth
  height: barHeight + dropMax

  function n(v) { return Math.round(v * 100) / 100 }

  // One drop hanging from the bar's underside, walked right to left: from
  // where its right flare leaves the bar to where its left flare rejoins it.
  // xr, xl: its right and left sides; d: how far it hangs; outerRight /
  // outerLeft: that side is the bar's end (no flare there, it runs straight
  // down from the end).
  function drop(xr, xl, d, outerRight, outerLeft) {
    var H = barHeight
    var fl = Math.min(flare, d)
    var r = Math.max(0, Math.min(dropRadius, d - (outerRight || outerLeft ? 0 : fl), (xr - xl) / 2))
    var p = ""
    if (!outerRight) p += " L " + n(xr + fl) + " " + n(H) + " A " + n(fl) + " " + n(fl) + " 0 0 0 " + n(xr) + " " + n(H + fl)
    p += " L " + n(xr) + " " + n(H + d - r)
    p += " A " + n(r) + " " + n(r) + " 0 0 1 " + n(xr - r) + " " + n(H + d)
    p += " L " + n(xl + r) + " " + n(H + d)
    p += " A " + n(r) + " " + n(r) + " 0 0 1 " + n(xl) + " " + n(H + d - r)
    if (!outerLeft) p += " L " + n(xl) + " " + n(H + fl) + " A " + n(fl) + " " + n(fl) + " 0 0 0 " + n(xl - fl) + " " + n(H)
    return p
  }

  readonly property string outline: {
    var W = screenWidth, H = barHeight, f = flare
    var L = reach, R = W - reach
    // The bar's own bottom corners round off while it has a gap at its ends.
    var rs = Math.max(0, Math.min(mix(H / 2, 0, expand), H - f))
    var ld = Math.max(0, leftDrop.height || 0), cd = Math.max(0, centerDrop.height || 0), rd = Math.max(0, rightDrop.height || 0)
    var lw = Math.max(0, leftDrop.width || 0), cw = Math.max(0, centerDrop.width || 0), rw = Math.max(0, rightDrop.width || 0)
    var p = "M " + n(L - f) + " 0 L " + n(R + f) + " 0"
    // The right end: flare down from the top edge.
    p += " A " + n(f) + " " + n(f) + " 0 0 0 " + n(R) + " " + n(f)
    if (rd > 0.5 && rw > 1) p += drop(R, R - rw, rd, true, false)
    else p += " L " + n(R) + " " + n(H - rs) + " A " + n(rs) + " " + n(rs) + " 0 0 1 " + n(R - rs) + " " + n(H)
    // The middle.
    if (cd > 0.5 && cw > 1) p += drop(W / 2 + cw / 2, W / 2 - cw / 2, cd, false, false)
    // The left end.
    if (ld > 0.5 && lw > 1) p += drop(L + lw, L, ld, false, true)
    else p += " L " + n(L + rs) + " " + n(H) + " A " + n(rs) + " " + n(rs) + " 0 0 1 " + n(L) + " " + n(H - rs)
    p += " L " + n(L) + " " + n(f) + " A " + n(f) + " " + n(f) + " 0 0 0 " + n(L - f) + " 0 Z"
    return p
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 1
      strokeColor: root.edgeColor
      fillGradient: LinearGradient {
        x1: 0; y1: 0
        x2: 0; y2: Math.max(root.barHeight, root.height)
        GradientStop { position: 0; color: root.topColor }
        GradientStop { position: Math.min(1, root.barHeight / Math.max(root.barHeight, root.height)); color: root.color }
        GradientStop { position: 1; color: root.color }
      }
      PathSvg { path: root.outline }
    }
  }
}
