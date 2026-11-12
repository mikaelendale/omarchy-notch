import QtQuick
import "Palette.js" as P

// Four level bars that move while music plays and lie flat when it stops,
// so the notch says "playing" without words.
Row {
  id: root

  property bool playing: false
  property real motion: 1
  property color color: Theme.green

  spacing: 2
  height: 14

  Repeater {
    model: 4
    Rectangle {
      id: bar
      required property int index
      property real level: 0.2
      width: 2.5
      radius: 1.25
      color: root.color
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      height: Math.max(3, root.height * (root.playing ? level : 0.2))
      Behavior on height { NumberAnimation { duration: 150 * root.motion; easing.type: Easing.OutCubic } }

      Timer {
        running: root.playing && root.motion > 0 && root.visible
        repeat: true
        interval: 150 + bar.index * 23
        onTriggered: bar.level = 0.25 + Math.random() * 0.75
      }
    }
  }
}
