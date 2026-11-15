import QtQuick
import "Palette.js" as P

// The music corner, opened: the cover, the title, a seek bar you can drag,
// and the controls the player supports (shuffle, previous, play or pause,
// next, repeat, and its speed when it has more than one).
//
// media: { available, playing, title, artist, identity, artUrl, position,
//          length, canSeek, canNext, canPrevious, canRaise, shuffleSupported,
//          shuffle, loopSupported, loop ("none" | "track" | "playlist"),
//          rateSupported, rate, minRate, maxRate }
// requested(action, value): toggle, next, previous, seek (seconds), shuffle,
// loop, rate, raise, switchPlayer.
//
// With more than one player going (Spotify and a YouTube tab, say), a pill
// names the next one; click it to switch which one this controls.
Item {
  id: root

  property var media: ({ available: false })
  property real motion: 1

  signal requested(string action, var value)

  readonly property bool available: !!(media && media.available)
  readonly property bool playing: available && !!media.playing
  readonly property real length: available ? Number(media.length || 0) : 0
  readonly property real position: available ? Math.min(Number(media.position || 0), length || Infinity) : 0

  implicitWidth: 312
  implicitHeight: 124

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var r = s % 60
    return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (r < 10 ? "0" : "") + r
  }

  // ---- what's playing
  CoverArt {
    id: art
    size: 52
    radius: 12
    source: root.available && root.media.artUrl ? root.media.artUrl : ""
    // Click the cover (or the title beside it) to go to the player's window.
    HoverHandler { enabled: root.available; cursorShape: Qt.PointingHandCursor }
    TapHandler { objectName: "coverTap"; enabled: root.available; onTapped: root.requested("raise", null) }
  }

  Column {
    id: words
    objectName: "playerWords"
    anchors.left: art.right
    anchors.leftMargin: 12
    anchors.right: bars.left
    anchors.rightMargin: 10
    anchors.verticalCenter: art.verticalCenter
    spacing: 2

    HoverHandler { enabled: root.available; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      enabled: root.available
      onTapped: function(point) {
        var q = switchPill.mapFromItem(words, point.position.x, point.position.y)
        if (switchPill.visible && q.x >= 0 && q.y >= 0 && q.x <= switchPill.width && q.y <= switchPill.height) return
        root.requested("raise", null)
      }
    }

    Text {
      width: parent.width
      text: root.available ? (root.media.title || "Unknown title") : "Nothing playing"
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 14
      font.weight: Font.DemiBold
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: root.available ? (root.media.artist || "") : ""
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Theme.secondary
      font.family: P.sans
      font.pixelSize: 12
    }
    // The app, and with another player going, a pill to switch to it.
    Row {
      width: parent.width
      height: Math.max(identityText.implicitHeight, switchPill.visible ? 22 : 0)
      spacing: 6
      visible: identityText.text !== "" || switchPill.visible
      Text {
        id: identityText
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - (switchPill.visible ? switchPill.width + 6 : 0))
        text: root.available ? (root.media.identity || "") : ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.tertiary
        font.family: P.sans
        font.pixelSize: 11
      }
      // Another player: switch to it.
      Rectangle {
        id: switchPill
        objectName: "switchPlayer"
        readonly property var choices: root.media && root.media.players ? root.media.players : []
        readonly property string nextName: {
          if (choices.length < 2) return ""
          var at = 0
          for (var i = 0; i < choices.length; i++) if (choices[i].key === root.media.playerKey) at = i
          return choices[(at + 1) % choices.length].name
        }
        visible: nextName !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(96, switchRow.implicitWidth + 16)
        height: 22
        radius: 11
        color: switchHover.hovered ? Theme.cardHover : Theme.card
        clip: true
        Row {
          id: switchRow
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF04E1)
            textFormat: Text.PlainText
            color: Theme.secondary
            font.family: P.glyphs
            font.pixelSize: 12
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 64)
            elide: Text.ElideRight
            text: switchPill.nextName
            textFormat: Text.PlainText
            color: Theme.text
            font.family: P.sans
            font.pixelSize: 11
            font.weight: Font.DemiBold
          }
        }
        HoverHandler { id: switchHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.requested("switchPlayer", null) }
      }

    }
  }

  EqBars {
    id: bars
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 6
    playing: root.playing
    motion: root.motion
    color: root.playing ? Theme.green : Theme.tertiary
  }

  // ---- how far in; drag or click to jump
  Item {
    id: seek
    anchors.left: parent.left
    anchors.right: parent.right
    y: art.height + 12
    height: 16
    visible: root.length > 0
    readonly property bool seekable: !!(root.media && root.media.canSeek)
    // While dragging, the bar follows the pointer, and the jump happens on release.
    property real dragging: -1
    readonly property real shown: dragging >= 0 ? dragging : (root.length > 0 ? Math.min(1, root.position / root.length) : 0)
    readonly property bool lit: seekHover.hovered || dragging >= 0

    Text {
      id: elapsed
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: root.clock(seek.shown * root.length)
      textFormat: Text.PlainText
      color: Theme.secondary
      font.family: P.sans
      font.pixelSize: 10
      font.features: { "tnum": 1 }
    }
    Text {
      id: remaining
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "-" + root.clock(root.length - seek.shown * root.length)
      textFormat: Text.PlainText
      color: Theme.secondary
      font.family: P.sans
      font.pixelSize: 10
      font.features: { "tnum": 1 }
    }
    Item {
      id: track
      objectName: "seekTrack"
      anchors.left: elapsed.right
      anchors.leftMargin: 9
      anchors.right: remaining.left
      anchors.rightMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      height: 16

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: seek.lit && seek.seekable ? 6 : 4
        radius: height / 2
        color: Theme.tertiary
        Behavior on height { NumberAnimation { duration: 90 * root.motion; easing.type: Easing.OutCubic } }
        Rectangle {
          height: parent.height
          radius: height / 2
          width: parent.width * seek.shown
          color: Theme.text
          Behavior on width { enabled: seek.dragging < 0; NumberAnimation { duration: 900 * root.motion; easing.type: Easing.Linear } }
        }
      }
      // The knob shows while the pointer is on the bar.
      Rectangle {
        visible: seek.seekable
        width: 12
        height: 12
        radius: 6
        x: track.width * seek.shown - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        opacity: seek.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 * root.motion } }
      }

      HoverHandler { id: seekHover; enabled: seek.seekable; cursorShape: Qt.PointingHandCursor }
      DragHandler {
        enabled: seek.seekable
        target: null
        yAxis.enabled: false
        onActiveChanged: {
          if (active) return
          if (seek.dragging >= 0) root.requested("seek", seek.dragging * root.length)
          seek.dragging = -1
        }
        onCentroidChanged: if (active) seek.dragging = Math.max(0, Math.min(1, centroid.position.x / track.width))
      }
      TapHandler {
        enabled: seek.seekable
        onTapped: function(point) { root.requested("seek", Math.max(0, Math.min(1, point.position.x / track.width)) * root.length) }
      }
    }
  }

  // ---- controls
  Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 34

    Row {
      anchors.centerIn: parent
      spacing: 18

      Control {
        visible: !!(root.media && root.media.shuffleSupported)
        glyph: root.media && root.media.shuffle ? 0xF049D : 0xF049E
        size: 17
        on: !!(root.media && root.media.shuffle)
        onTapped: root.requested("shuffle", !root.media.shuffle)
      }
      Control {
        glyph: 0xF04AE
        size: 22
        enabled: !!(root.media && root.media.canPrevious)
        onTapped: root.requested("previous", null)
      }
      Control {
        glyph: root.playing ? 0xF03E4 : 0xF040A
        size: 28
        onTapped: root.requested("toggle", null)
      }
      Control {
        glyph: 0xF04AD
        size: 22
        enabled: !!(root.media && root.media.canNext)
        onTapped: root.requested("next", null)
      }
      Control {
        readonly property string loop: root.media && root.media.loop ? root.media.loop : "none"
        visible: !!(root.media && root.media.loopSupported)
        glyph: loop === "track" ? 0xF0458 : (loop === "playlist" ? 0xF0456 : 0xF0457)
        size: 17
        on: loop !== "none"
        onTapped: root.requested("loop", loop === "none" ? "playlist" : (loop === "playlist" ? "track" : "none"))
      }
    }

    // The player's speed, for players that have more than one (podcasts,
    // videos): click to step through them.
    Rectangle {
      readonly property real rate: root.media && root.media.rate ? Number(root.media.rate) : 1
      visible: !!(root.media && root.media.rateSupported)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: rateText.implicitWidth + 16
      height: 22
      radius: 11
      color: rateHover.hovered ? Theme.cardHover : Theme.card
      Text {
        id: rateText
        anchors.centerIn: parent
        text: (Math.round(parent.rate * 100) / 100) + "×"
        textFormat: Text.PlainText
        color: Theme.text
        font.family: P.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
      }
      HoverHandler { id: rateHover; cursorShape: Qt.PointingHandCursor }
      TapHandler {
        onTapped: {
          var steps = [1, 1.25, 1.5, 2, 0.75]
          var lo = Number(root.media.minRate || 1), hi = Number(root.media.maxRate || 1)
          var now = parent.rate
          var i = 0
          while (i < steps.length && Math.abs(steps[i] - now) > 0.01) i++
          for (var k = 1; k <= steps.length; k++) {
            var next = steps[(i + k) % steps.length]
            if (next >= lo - 0.001 && next <= hi + 0.001) { root.requested("rate", next); return }
          }
        }
      }
    }
  }

  component Control: Item {
    id: control
    property int glyph: 0
    property real size: 22
    property bool on: false
    signal tapped()
    width: Math.max(26, size + 6)
    height: 30
    opacity: enabled ? 1 : 0.35
    Text {
      anchors.centerIn: parent
      text: String.fromCodePoint(control.glyph)
      textFormat: Text.PlainText
      // Shuffle and repeat: full strength while on, soft while off.
      color: control.on || control.size > 18 ? Theme.text : Theme.secondary
      opacity: controlHover.hovered ? 1 : 0.9
      font.family: P.glyphs
      font.pixelSize: control.size
      scale: controlTap.pressed ? 0.88 : 1
      Behavior on scale { NumberAnimation { duration: 90 } }
    }
    Rectangle {
      visible: control.on
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 1
      width: 4
      height: 4
      radius: 2
      color: Theme.text
    }
    HoverHandler { id: controlHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: controlTap; onTapped: control.tapped() }
  }
}
