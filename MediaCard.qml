import QtQuick
import "Palette.js" as P

// What's playing: cover, title, artist, how far in, and the three controls,
// on the same card as the others.
Rectangle {
  id: root

  property var media: ({ available: false })
  property real motion: 1

  signal requested(string action)

  readonly property bool available: !!(media && media.available)
  readonly property bool playing: available && !!media.playing
  readonly property real length: available ? Number(media.length || 0) : 0
  readonly property real position: available ? Math.min(Number(media.position || 0), length || Infinity) : 0

  radius: 22
  color: Theme.card

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  Item {
    anchors.fill: parent
    anchors.margins: 14

    CoverArt {
      id: art
      size: 62
      radius: 13
      source: root.available && root.media.artUrl ? root.media.artUrl : ""
      // Click the cover to go to the player's window.
      HoverHandler { enabled: root.available; cursorShape: Qt.PointingHandCursor }
      TapHandler { enabled: root.available; onTapped: root.requested("raise") }
    }

    Column {
      anchors.left: art.right
      anchors.leftMargin: 12
      anchors.right: bars.left
      anchors.rightMargin: 8
      anchors.verticalCenter: art.verticalCenter
      spacing: 3

      Text {
        width: parent.width
        text: root.available ? (root.media.title || "Unknown title") : "Nothing playing"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.available ? Theme.text : Theme.secondary
        font.family: P.sans
        font.pixelSize: 15
        font.weight: Font.DemiBold
      }
      Text {
        width: parent.width
        visible: text !== ""
        text: root.available ? (root.media.artist || root.media.identity || "") : "Music shows up here"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
      }
    }

    EqBars {
      id: bars
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: 4
      visible: root.available
      playing: root.playing
      motion: root.motion
      color: Theme.green
    }

    // Progress.
    Item {
      id: progress
      visible: root.available && root.length > 0
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: art.bottom
      anchors.topMargin: 12
      height: 14

      Text {
        id: elapsed
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.clock(root.position)
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 10
        font.features: { "tnum": 1 }
      }
      Rectangle {
        id: track
        anchors.left: elapsed.right
        anchors.leftMargin: 8
        anchors.right: remaining.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.tertiary
        Rectangle {
          height: parent.height
          radius: 2
          width: root.length > 0 ? parent.width * Math.min(1, root.position / root.length) : 0
          color: Theme.text
          Behavior on width { NumberAnimation { duration: 900 * root.motion; easing.type: Easing.Linear } }
        }
      }
      Text {
        id: remaining
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "-" + root.clock(root.length - root.position)
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 10
        font.features: { "tnum": 1 }
      }
    }

    // Controls.
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      spacing: 26
      opacity: root.available ? 1 : 0.35
      enabled: root.available

      Repeater {
        model: [
          { action: "previous", glyph: 0xF04AE, size: 22 },
          { action: "toggle", glyph: root.playing ? 0xF03E4 : 0xF040A, size: 28 },
          { action: "next", glyph: 0xF04AD, size: 22 }
        ]
        Item {
          id: control
          required property var modelData
          width: 30
          height: 30
          Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(control.modelData.glyph)
            textFormat: Text.PlainText
            color: Theme.text
            opacity: hover.hovered ? 1 : 0.88
            font.family: P.glyphs
            font.pixelSize: control.modelData.size
            scale: press.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
          }
          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
          TapHandler { id: press; onTapped: root.requested(control.modelData.action) }
        }
      }
    }
  }
}
