import QtQuick
import "Palette.js" as P

// Four level bars that move while music plays and lie flat when it stops,
// so the notch says "playing" without words.
//
// They step, a few times a second on Motion's slow beat, rather than
// animating every frame: each step repaints the bar's window (and Hyprland
// re-blurs it), so a level meter that jumps is what keeps playing music from
// keeping the whole bar busy. With Motion at Light or Off they stand still,
// at a playing shape.
Row {
  id: root

  property bool playing: false
  property real motion: 1
  property color color: Theme.green

  spacing: 2
  height: 14

  // The still shape, and the levels the bars are at now.
  readonly property var restLevels: [0.55, 0.9, 0.7, 0.45]
  property var levels: restLevels

  readonly property bool stepping: root.playing && Motion.ambient && root.motion > 0 && root.visible
  onSteppingChanged: if (!stepping) root.levels = root.restLevels
  Connections {
    target: Motion
    enabled: root.stepping
    function onTickChanged() {
      root.levels = [0.25 + Math.random() * 0.75, 0.25 + Math.random() * 0.75,
                     0.25 + Math.random() * 0.75, 0.25 + Math.random() * 0.75]
    }
  }

  Repeater {
    model: 4
    Rectangle {
      required property int index
      width: 2.5
      radius: 1.25
      color: root.color
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      height: Math.max(3, root.height * (root.playing ? root.levels[index] : 0.2))
    }
  }
}
