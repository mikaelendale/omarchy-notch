import QtQuick
import QtQuick.Effects
import "Palette.js" as P

// A rounded square of cover art, or a quiet placeholder when there is none.
Item {
  id: root

  property real size: 64
  property real radius: 12
  property string source: ""

  width: size
  height: size

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    visible: image.status !== Image.Ready
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.cardHover }
      GradientStop { position: 1; color: Theme.card }
    }
    Text {
      anchors.centerIn: parent
      text: String.fromCodePoint(0xF075A)   // music note
      textFormat: Text.PlainText
      color: Theme.secondary
      font.family: P.glyphs
      font.pixelSize: root.size * 0.42
    }
  }

  Image {
    id: image
    anchors.fill: parent
    source: root.source
    sourceSize.width: root.size * 2
    sourceSize.height: root.size * 2
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    visible: false
  }
  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    visible: false
    layer.enabled: true
  }
  MultiEffect {
    anchors.fill: parent
    visible: image.status === Image.Ready
    source: image
    maskEnabled: true
    maskSource: mask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }
}
