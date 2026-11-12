import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// The battery, drawn like a phone's: a rounded body that fills to the charge
// level with the percentage inside. Green while charging, red when low.
Item {
  id: root

  property real level: 1           // 0..1
  property bool charging: false
  property bool present: true
  property bool showNumber: true
  property real size: 25           // width; height follows

  // The bolt sits after the battery while charging, inside this item's width.
  width: size + (charging ? boltW + size * 0.08 : 0)
  height: Math.round(size * 0.48)

  readonly property real bodyW: size - size * 0.1
  readonly property real boltW: size * 0.3
  readonly property real boltH: height * 1.15
  readonly property color fill: charging ? Theme.green : (level <= 0.2 ? Theme.red : Theme.text)
  readonly property color shell: Theme.dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.18)

  // Body.
  Rectangle {
    id: body
    width: root.bodyW
    height: root.height
    radius: height * 0.32
    color: root.shell
    clip: true

    Rectangle {
      id: fillBar
      height: parent.height
      width: Math.max(parent.radius, parent.width * Math.max(0, Math.min(1, root.level)))
      radius: parent.radius
      color: root.fill
    }
    // The number, drawn twice and cut where the fill ends: the part over the
    // fill in a colour that reads on it, the rest in the text colour. At 44%
    // the "4" over the fill and the "4" past it would otherwise lose one of
    // them, whichever colour the number had.
    Item {
      visible: root.showNumber && root.present
      anchors.fill: parent
      Item {
        x: fillBar.width
        width: Math.max(0, parent.width - fillBar.width)
        height: parent.height
        clip: true
        BatteryNumber { x: -parent.x; width: body.width; height: body.height; level: root.level; color: Theme.text }
      }
      Item {
        width: fillBar.width
        height: parent.height
        clip: true
        BatteryNumber { width: body.width; height: body.height; level: root.level; color: Theme.contrastOn(root.fill) }
      }
    }
  }
  component BatteryNumber: Text {
    property real level: 1
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: Math.round(Math.max(0, Math.min(1, level)) * 100)
    textFormat: Text.PlainText
    font.family: P.sans
    font.pixelSize: Math.round(height * 0.82)
    font.weight: Font.Bold
    font.features: { "tnum": 1 }
  }
  // Terminal nub.
  Rectangle {
    x: root.bodyW + root.size * 0.025
    anchors.verticalCenter: body.verticalCenter
    width: root.size * 0.06
    height: root.height * 0.38
    radius: width / 2
    color: root.shell
  }
  // A bolt beside it while charging.
  Shape {
    visible: root.charging
    x: root.size + root.size * 0.06
    anchors.verticalCenter: body.verticalCenter
    width: root.size * 0.3
    height: root.height * 1.15
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Theme.green
      strokeWidth: -1
      strokeColor: "transparent"
      startX: root.boltW * 0.62; startY: 0
      PathLine { x: 0; y: root.boltH * 0.58 }
      PathLine { x: root.boltW * 0.45; y: root.boltH * 0.58 }
      PathLine { x: root.boltW * 0.36; y: root.boltH }
      PathLine { x: root.boltW; y: root.boltH * 0.4 }
      PathLine { x: root.boltW * 0.55; y: root.boltH * 0.4 }
      PathLine { x: root.boltW * 0.62; y: 0 }
    }
  }
}
