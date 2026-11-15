import QtQuick
import "Palette.js" as P

// One item of a corner, opened: its icon, its name and what it's up to (the
// network you're on and how fast it's going, how long the battery lasts,
// which headphones are connected...). Clicking the row opens Omarchy's own
// panel for it; the Wi-Fi row also runs a speed test, and the volume row is a
// slider.
Item {
  id: root

  property string itemId: ""
  property var status: ({})
  property date now: new Date()
  property real motion: 1
  property var lead: ({ agent: "claude", state: "idle" })
  property var counts: ({})

  // open (the item's panel), speedtest, mute, volume (value), workspace (id).
  signal requested(string action, var value)

  width: 280
  height: 46

  readonly property var wifi: status && status.wifi ? status.wifi : ({ kind: "none" })
  readonly property var bt: status && status.bluetooth ? status.bluetooth : ({ enabled: false })
  readonly property var battery: status && status.battery ? status.battery : ({ present: false })
  readonly property var vol: status && status.volume ? status.volume : ({ level: 0, muted: false })
  readonly property var net: status && status.net ? status.net : ({ down: 0, up: 0 })
  readonly property var dots: status && status.workspaces ? status.workspaces : []
  readonly property var priv: status && status.privacy ? status.privacy : ({})
  readonly property bool clickable: ["wifi", "bluetooth", "battery", "speed", "agents"].indexOf(itemId) !== -1

  function rate(bytes) {
    var b = Math.max(0, Number(bytes) || 0)
    if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB/s"
    if (b >= 1e6) return (b / 1e6).toFixed(b >= 1e7 ? 0 : 1) + " MB/s"
    return Math.round(b / 1e3) + " KB/s"
  }
  function duration(seconds) {
    var m = Math.round(Math.max(0, Number(seconds) || 0) / 60)
    if (m < 60) return m + " min"
    var h = Math.floor(m / 60)
    var r = m % 60
    return h + " h" + (r > 0 ? " " + r + " min" : "")
  }

  readonly property string title: ({
    agents: "Agents", clock: "Time", date: "Date", wifi: wifi.kind === "ethernet" ? "Ethernet" : "Wi-Fi",
    bluetooth: "Bluetooth", battery: "Battery", volume: "Volume", speed: "Network speed",
    workspaces: "Workspaces", privacy: "In use"
  })[itemId] || ""

  readonly property string value: {
    if (itemId === "wifi") {
      var where = wifi.kind === "wifi" ? (wifi.name || "Connected")
        : wifi.kind === "ethernet" ? "Connected"
        : (wifi.enabled === false ? "Off" : "Not connected")
      return wifi.kind === "none" ? where : where + "  ·  ↓ " + rate(net.down)
    }
    if (itemId === "bluetooth") {
      if (!bt.enabled) return "Off"
      return bt.connected ? (bt.device || "Connected") : "On"
    }
    if (itemId === "battery") {
      if (!battery.present) return "No battery"
      var pct = Math.round((battery.level || 0) * 100) + "%"
      if (battery.full) return pct + "  ·  Fully charged"
      if (battery.charging) return pct + (battery.timeToFull > 0 ? "  ·  Full in " + duration(battery.timeToFull) : "  ·  Charging")
      return pct + (battery.timeToEmpty > 0 ? "  ·  " + duration(battery.timeToEmpty) + " left" : "")
    }
    if (itemId === "speed") return "↓ " + rate(net.down) + "    ↑ " + rate(net.up)
    if (itemId === "agents") {
      var working = (counts.working || 0) + (counts.watching || 0)
      var needs = counts.needs || 0
      var parts = []
      if (needs > 0) parts.push(needs === 1 ? "1 needs you" : needs + " need you")
      if (working > 0) parts.push(working + " at work")
      return parts.length ? parts.join("  ·  ") : "All quiet"
    }
    if (itemId === "clock" || itemId === "date") return Qt.formatDate(now, "dddd d MMMM")
    if (itemId === "privacy") {
      var used = []
      if (priv.mic) used.push("Microphone" + (priv.micApps ? " (" + priv.micApps + ")" : ""))
      if (priv.camera) used.push("Camera" + (priv.cameraApp ? " (" + priv.cameraApp + ")" : ""))
      if (priv.screen) used.push("Screen recording")
      return used.length ? used.join("  ·  ") : "Nothing"
    }
    return ""
  }

  Rectangle {
    anchors.fill: parent
    radius: 14
    color: root.clickable && rowHover.hovered ? Theme.cardHover : Theme.card
    Behavior on color { ColorAnimation { duration: 90 * root.motion } }
  }
  HoverHandler { id: rowHover; cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
  TapHandler {
    enabled: root.clickable
    // The speed test button has its own tap; don't open the panel as well.
    onTapped: function(point) {
      var q = testButton.mapFromItem(root, point.position.x, point.position.y)
      if (testButton.visible && q.x >= 0 && q.y >= 0 && q.x <= testButton.width && q.y <= testButton.height) return
      root.requested(root.itemId === "speed" ? "speedtest" : "open", null)
    }
  }

  // The item's own icon, a size up.
  Item {
    id: iconBox
    x: 10
    width: 30
    height: parent.height
    StatusItem {
      anchors.centerIn: parent
      itemId: ["clock", "date", "speed", "workspaces"].indexOf(root.itemId) !== -1 ? "" : root.itemId
      status: root.status
      lead: root.lead
      motion: root.motion
      always: true
      scale: root.itemId === "battery" ? 0.92 : 1.15
    }
    Text {
      visible: ["clock", "date", "speed", "workspaces"].indexOf(root.itemId) !== -1
      anchors.centerIn: parent
      text: String.fromCodePoint(root.itemId === "speed" ? 0xF04C5 : (root.itemId === "clock" ? 0xF0954
        : (root.itemId === "workspaces" ? 0xF0570 : 0xF00ED)))
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.glyphs
      font.pixelSize: 17
    }
    // Volume: the icon mutes and unmutes.
    TapHandler {
      enabled: root.itemId === "volume"
      onTapped: root.requested("mute", null)
    }
  }

  Column {
    anchors.left: iconBox.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    visible: root.itemId !== "volume" && root.itemId !== "workspaces"
    Text {
      width: parent.width
      text: root.title
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 13
      font.weight: Font.DemiBold
    }
    Text {
      width: parent.width
      text: root.value
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Theme.secondary
      font.family: P.sans
      font.pixelSize: 11
      font.features: { "tnum": 1 }
    }
  }

  // Volume: a slider in place of the words.
  HSlider {
    visible: root.itemId === "volume"
    anchors.left: iconBox.right
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    height: 22
    value: root.vol.level || 0
    dimmed: !!root.vol.muted
    onMoved: function(value) { root.requested("volume", value) }
  }

  // Workspaces: a numbered button each; click to go, scroll to step along.
  Row {
    id: wsRow
    visible: root.itemId === "workspaces"
    anchors.left: iconBox.right
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4
    Repeater {
      model: root.itemId === "workspaces" ? root.dots : []
      Rectangle {
        required property var modelData
        width: 26
        height: 26
        radius: 13
        color: modelData.active ? Theme.text : (wsHover.hovered ? Theme.cardHover : "transparent")
        border.width: modelData.active ? 0 : 1
        border.color: modelData.occupied ? Theme.secondary : Theme.hairline
        Text {
          anchors.centerIn: parent
          text: String(parent.modelData.slot)
          textFormat: Text.PlainText
          color: parent.modelData.active ? Theme.onText : (parent.modelData.occupied ? Theme.text : Theme.tertiary)
          font.family: P.sans
          font.pixelSize: 12
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
        }
        HoverHandler { id: wsHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.requested("workspace", parent.modelData.id) }
      }
    }
  }

  // Wi-Fi: run Omarchy's speed test.
  Item {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    width: root.itemId === "wifi" ? testButton.width : 0
    height: 26
    Rectangle {
      id: testButton
      visible: root.itemId === "wifi"
      anchors.verticalCenter: parent.verticalCenter
      width: testText.implicitWidth + 20
      height: 26
      radius: 13
      color: testHover.hovered ? Theme.text : Theme.cardHover
      Behavior on color { ColorAnimation { duration: 90 * root.motion } }
      Text {
        id: testText
        anchors.centerIn: parent
        text: "Speed test"
        textFormat: Text.PlainText
        color: testHover.hovered ? Theme.onText : Theme.text
        font.family: P.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
      }
      HoverHandler { id: testHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.requested("speedtest", null) }
    }
  }
}
