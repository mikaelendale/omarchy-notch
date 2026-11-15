import QtQuick

// The unified bar: one long slab hanging from the top edge, flaring into it
// at both ends like the notch, with a gap from either side of the screen.
// When anything on it opens (the notch or a corner) it stretches out to the
// screen's edges and what opens grows down out of it.
//
// Built from plain rectangles that sit side by side and never overlap (the
// bar, and below it each opening), with fixed flares (Flare.qml) where they
// meet: so there's no seam and no second layer of glass, and stretching or
// opening only resizes rectangles and moves flares, nothing is re-traced on
// each frame.
//
// expand: 0 (a gap at either side) to 1 (edge to edge); the bar animates it.
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

  // The bar runs from L to R; its end flares reach `flare` beyond.
  readonly property real reach: mix(gap + flare, 0, expand)
  readonly property real barL: reach
  readonly property real barR: screenWidth - reach
  readonly property real endRadius: Math.max(0, Math.min(mix(barHeight / 2, 0, expand), barHeight - flare))

  readonly property real ld: Math.max(0, leftDrop.height || 0)
  readonly property real cd: Math.max(0, centerDrop.height || 0)
  readonly property real rd: Math.max(0, rightDrop.height || 0)
  readonly property real lw: Math.max(0, leftDrop.width || 0)
  readonly property real cw: Math.max(0, centerDrop.width || 0)
  readonly property real rw: Math.max(0, rightDrop.width || 0)

  width: screenWidth
  height: barHeight + Math.max(ld, cd, rd)

  // ---- the bar
  Rectangle {
    x: root.barL
    width: Math.max(0, root.barR - root.barL)
    height: root.barHeight
    // Its bottom corners round off, except where an opening carries on down.
    bottomLeftRadius: root.ld > 0.5 ? 0 : root.endRadius
    bottomRightRadius: root.rd > 0.5 ? 0 : root.endRadius
    gradient: Gradient {
      GradientStop { position: 0; color: root.topColor }
      GradientStop { position: 1; color: root.color }
    }
  }
  // Its ends, flaring into the top edge (off screen once it's edge to edge).
  Flare {
    x: root.barL - root.flare
    size: root.flare
    color: root.topColor
    edgeColor: root.edgeColor
  }
  Flare {
    x: root.barR
    size: root.flare
    mirrored: true
    color: root.topColor
    edgeColor: root.edgeColor
  }

  // ---- what hangs below it
  // (An inline component can't see `root`, so it's handed what it needs.)
  component Drop: Item {
    id: drop
    property real dropWidth: 0
    property real dropHeight: 0
    property bool flushLeft: false     // against the bar's left end: no flare there
    property bool flushRight: false
    property real dropTop: 34
    property real flareSize: 12
    property real radiusMax: 26
    property color fill: "black"
    property color edge: "transparent"
    readonly property real fl: Math.min(flareSize, dropHeight)
    readonly property real r: Math.max(0, Math.min(radiusMax, dropHeight, dropWidth / 2))
    visible: dropHeight > 0.5 && dropWidth > 1
    y: dropTop
    width: dropWidth
    height: dropHeight
    Rectangle {
      anchors.fill: parent
      color: drop.fill
      bottomLeftRadius: drop.r
      bottomRightRadius: drop.r
    }
    Flare {
      visible: !drop.flushLeft && drop.fl > 0.5
      x: -drop.fl
      size: drop.fl
      color: drop.fill
      edgeColor: drop.edge
    }
    Flare {
      visible: !drop.flushRight && drop.fl > 0.5
      x: drop.dropWidth
      size: drop.fl
      mirrored: true
      color: drop.fill
      edgeColor: drop.edge
    }
  }

  Drop {
    x: root.barL
    dropWidth: root.lw
    dropTop: root.barHeight
    flareSize: root.flare
    radiusMax: root.dropRadius
    fill: root.color
    edge: root.edgeColor
    dropHeight: root.ld
    flushLeft: true
  }
  Drop {
    x: (root.screenWidth - root.cw) / 2
    dropWidth: root.cw
    dropTop: root.barHeight
    flareSize: root.flare
    radiusMax: root.dropRadius
    fill: root.color
    edge: root.edgeColor
    dropHeight: root.cd
  }
  Drop {
    x: root.barR - root.rw
    dropWidth: root.rw
    dropTop: root.barHeight
    flareSize: root.flare
    radiusMax: root.dropRadius
    fill: root.color
    edge: root.edgeColor
    dropHeight: root.rd
    flushRight: true
  }
}
