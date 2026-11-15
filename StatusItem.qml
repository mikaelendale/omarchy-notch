import QtQuick
import "Palette.js" as P

// One item of the top bar, drawn small for the closed notch and the corners:
// the agents' mark, the time, the date, what's playing, Wi-Fi, Bluetooth, the
// battery, the volume or the network speed. Layout.js lists them.
//
// Pure QtQuick: the bar feeds it data, and the tests and the editor draw it
// with made-up or live data alike.
Item {
  id: root

  property string itemId: ""
  property var status: ({})
  property var media: ({ available: false })
  property date now: new Date()
  property string clockFormat: "h:mm AP"
  property real motion: 1
  // The agents item: the session that matters most, and how many wait on you.
  property var lead: ({ agent: "claude", state: "idle" })
  property int needsCount: 0
  // In a corner, music shows its title too and stays while paused; in the
  // notch it's the cover and moving bars, while it plays.
  property bool wide: false
  // The editor shows music even when nothing is playing.
  property bool always: false

  // A workspace dot was clicked.
  signal workspaceRequested(int id)

  readonly property var privacyState: status && status.privacy ? status.privacy : ({})
  readonly property bool privacyOn: !!(privacyState.mic || privacyState.camera || privacyState.screen)

  readonly property bool mediaAvailable: !!(media && media.available)
  readonly property bool mediaPlaying: mediaAvailable && !!media.playing
  // Whether there's anything to draw right now (music comes and goes; a
  // machine without a battery has none).
  readonly property bool present: {
    if (always) return true
    if (itemId === "media") return wide ? mediaAvailable : mediaPlaying
    if (itemId === "battery") return !!(status && status.battery && status.battery.present)
    if (itemId === "privacy") return privacyOn
    if (itemId === "workspaces") return !!(status && status.workspaces && status.workspaces.length > 0)
    return itemId !== ""
  }

  implicitWidth: present && loader.item ? loader.item.implicitWidth : 0
  implicitHeight: 22
  width: implicitWidth
  height: implicitHeight
  visible: implicitWidth > 0

  function rate(bytes) {
    var b = Math.max(0, Number(bytes) || 0)
    if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB/s"
    if (b >= 1e6) return (b / 1e6).toFixed(b >= 1e7 ? 0 : 1) + " MB/s"
    return Math.round(b / 1e3) + " KB/s"
  }

  Loader {
    id: loader
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: ({
      agents: agentsItem, clock: clockItem, date: dateItem, media: mediaItem,
      wifi: wifiItem, bluetooth: bluetoothItem, battery: batteryItem,
      volume: volumeItem, speed: speedItem, workspaces: workspacesItem, privacy: privacyItem
    })[root.itemId] || null
  }

  // Claude's mark (or the agent at work), cycling colours while one works,
  // yellow with "needs you" while one waits on you.
  Component {
    id: agentsItem
    Row {
      spacing: 7
      height: 22
      AgentMark {
        anchors.verticalCenter: parent.verticalCenter
        size: 18
        agent: root.lead && root.lead.agent ? root.lead.agent : "claude"
        working: !!root.lead && (root.lead.state === "working" || root.lead.state === "watching")
        needs: !!root.lead && root.lead.state === "needs"
        motion: root.motion
      }
      Text {
        visible: root.needsCount > 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.needsCount === 1 ? "needs you" : root.needsCount + " need you"
        textFormat: Text.PlainText
        color: Theme.yellow
        font.family: P.sans
        font.pixelSize: 12
        font.weight: Font.DemiBold
      }
    }
  }

  Component {
    id: clockItem
    Text {
      height: 22
      verticalAlignment: Text.AlignVCenter
      text: Qt.formatTime(root.now, root.clockFormat)
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 13
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
    }
  }

  Component {
    id: dateItem
    Text {
      height: 22
      verticalAlignment: Text.AlignVCenter
      text: Qt.formatDate(root.now, "ddd d MMM")
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 13
      font.weight: Font.DemiBold
    }
  }

  // The cover and moving bars; in a corner, the title between them. Paused,
  // the bars lie flat and the title dims.
  Component {
    id: mediaItem
    Row {
      spacing: 8
      height: 22
      CoverArt {
        anchors.verticalCenter: parent.verticalCenter
        size: root.wide ? 20 : 18
        radius: 5
        source: root.mediaAvailable && root.media.artUrl ? root.media.artUrl : ""
      }
      Text {
        visible: root.wide
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 168)
        text: root.mediaAvailable ? (root.media.title || root.media.identity || "Playing") : "Music"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.mediaPlaying || !root.mediaAvailable ? Theme.text : Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
        font.weight: Font.DemiBold
        Behavior on color { ColorAnimation { duration: 160 * root.motion } }
      }
      EqBars {
        anchors.verticalCenter: parent.verticalCenter
        playing: root.mediaPlaying
        motion: root.motion
        color: root.mediaPlaying ? Theme.green : Theme.tertiary
      }
    }
  }

  // Wi-Fi, or the wired glyph while on a cable.
  Component {
    id: wifiItem
    Item {
      readonly property var wifi: root.status && root.status.wifi ? root.status.wifi : ({ kind: "none" })
      implicitWidth: wifi.kind === "ethernet" ? wired.implicitWidth : icon.width
      height: 22
      WifiIcon {
        id: icon
        visible: parent.wifi.kind !== "ethernet"
        anchors.verticalCenter: parent.verticalCenter
        size: 15
        connected: parent.wifi.kind === "wifi"
        strength: parent.wifi.strength || 0
      }
      Text {
        id: wired
        visible: parent.wifi.kind === "ethernet"
        anchors.verticalCenter: parent.verticalCenter
        text: String.fromCodePoint(0xF0200)
        textFormat: Text.PlainText
        color: Theme.text
        font.family: P.glyphs
        font.pixelSize: 14
      }
    }
  }

  Component {
    id: bluetoothItem
    Item {
      readonly property var bt: root.status && root.status.bluetooth ? root.status.bluetooth : ({ enabled: false })
      implicitWidth: icon.width
      height: 22
      BluetoothIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        size: 14
        enabled_: !!parent.bt.enabled
        connected: !!parent.bt.connected
      }
    }
  }

  Component {
    id: batteryItem
    Item {
      readonly property var battery: root.status && root.status.battery ? root.status.battery : ({ present: false })
      implicitWidth: icon.width
      height: 22
      BatteryIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        size: 25
        level: root.always && !parent.battery.present ? 0.8 : (parent.battery.level || 0)
        charging: !!parent.battery.charging
      }
    }
  }

  Component {
    id: volumeItem
    Item {
      readonly property var vol: root.status && root.status.volume ? root.status.volume : ({ level: 0.5, muted: false })
      implicitWidth: icon.width
      height: 22
      VolumeIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        size: 15
        level: parent.vol.level || 0
        muted: !!parent.vol.muted
      }
    }
  }

  // This monitor's workspaces as dots: the one you're on a short bar, the
  // ones with windows full, the empty ones faint. Click one to go there.
  Component {
    id: workspacesItem
    Row {
      readonly property var dots: root.status && root.status.workspaces && root.status.workspaces.length
        ? root.status.workspaces
        : (root.always ? [{ id: 1, active: true, occupied: true }, { id: 2, occupied: true }, { id: 3 }, { id: 4 }, { id: 5 }] : [])
      spacing: 5
      height: 22
      Repeater {
        model: parent.dots
        Item {
          required property var modelData
          width: modelData.active ? 16 : 7
          height: 22
          Behavior on width { NumberAnimation { duration: 160 * root.motion; easing.type: Easing.OutCubic } }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 7
            radius: 3.5
            color: parent.modelData.active || parent.modelData.occupied ? Theme.text : Theme.tertiary
            opacity: parent.modelData.active ? 1 : (parent.modelData.occupied ? 0.72 : 1)
          }
          TapHandler { onTapped: root.workspaceRequested(parent.modelData.id) }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
      }
    }
  }

  // Privacy dots: orange while an app uses the microphone, green the camera,
  // red while the screen is being recorded.
  Component {
    id: privacyItem
    Row {
      readonly property var st: root.always && !root.privacyOn ? ({ mic: true, camera: true }) : root.privacyState
      spacing: 5
      height: 22
      Repeater {
        model: [
          { on: !!parent.st.mic, color: Theme.orange },
          { on: !!parent.st.camera, color: Theme.green },
          { on: !!parent.st.screen, color: Theme.red }
        ]
        Rectangle {
          required property var modelData
          visible: modelData.on
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          width: 8
          height: 8
          radius: 4
          color: modelData.color
        }
      }
    }
  }

  // How fast data is coming in right now.
  Component {
    id: speedItem
    Text {
      readonly property var net: root.status && root.status.net ? root.status.net : ({ down: 0 })
      height: 22
      verticalAlignment: Text.AlignVCenter
      text: "↓ " + root.rate(net.down)
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 12
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
    }
  }
}
