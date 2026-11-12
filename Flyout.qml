import QtQuick
import "Palette.js" as P

// A black tab that slides sideways out of the side notch's strip, joined to
// it with concave fillets. Its content is revealed from the strip outward.
//
// Put it so its strip-side end tucks `overlap` px under the strip:
//   towardLeft (strip on the right edge): x = stripInnerX + overlap - width
//   otherwise (strip on the left edge):   x = stripInnerX - overlap
Item {
  id: root

  property bool open: false
  property bool towardLeft: true
  property real flyWidth: 200
  property real flyHeight: 36
  property real overlap: 12
  property real radius: flyHeight / 2
  property real motion: 1
  default property alias content: inner.data

  property real amount: open ? 1 : 0
  Behavior on amount { enabled: root.motion > 0; SpringAnimation { spring: 11.0; damping: 0.85; epsilon: 0.002 } }

  width: Math.max(overlap, flyWidth * amount)
  height: flyHeight
  visible: amount > 0.01

  Rectangle {
    anchors.fill: parent
    color: Theme.body
    topLeftRadius: root.towardLeft ? root.radius : 0
    bottomLeftRadius: root.towardLeft ? root.radius : 0
    topRightRadius: root.towardLeft ? 0 : root.radius
    bottomRightRadius: root.towardLeft ? 0 : root.radius
  }

  // Where it meets the strip, above and below.
  Fillet {
    size: 8
    x: root.towardLeft ? root.width - root.overlap - size : root.overlap
    y: -size
    corner: root.towardLeft ? "bottomRight" : "bottomLeft"
    opacity: Math.min(1, root.amount * 3)
  }
  Fillet {
    size: 8
    x: root.towardLeft ? root.width - root.overlap - size : root.overlap
    y: root.height
    corner: root.towardLeft ? "topRight" : "topLeft"
    opacity: Math.min(1, root.amount * 3)
  }

  // The content, fixed size, revealed from the strip side as the tab grows.
  Item {
    anchors.fill: parent
    anchors.leftMargin: root.towardLeft ? 0 : root.overlap
    anchors.rightMargin: root.towardLeft ? root.overlap : 0
    clip: true
    Item {
      id: inner
      width: root.flyWidth - root.overlap
      height: root.flyHeight
      x: (root.towardLeft ? parent.width - width : 0) + (root.towardLeft ? -1 : 1) * 6 * (1 - root.amount)
      opacity: Math.max(0, Math.min(1, (root.amount - 0.3) / 0.6))
    }
  }
}
