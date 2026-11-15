import QtQuick
import qs.Commons
import "Palette.js" as P

// One of Omarchy's bar widgets, as a round button in the open notch's row.
//
// The widget runs unchanged (same code, same updates): this hands it the bar
// surface (`host`, the notch's Bar.qml) the way the stock bar does. For the
// common ones (Wi-Fi, Bluetooth, volume, battery, displays, Claude, agents)
// the notch draws its own icon from live state, and the widget sits invisible
// on top of it filling the button, so a click anywhere on the button still
// reaches the widget and opens its usual panel.
Item {
  id: root

  required property var modelData   // the layout entry: { id, ...settings }
  property var host: null
  property string screenName: ""
  property var window: null
  // The notch's own buttons register, so shortcuts find them; a corner's
  // hidden copy (there only to open its panel from the corner) doesn't.
  property bool register: true
  // Widgets to leave out of the row (their items show in a corner).
  property var hiddenIds: []
  // Bare: placed on the closed bar (a corner or the notch) by the editor, so
  // no round button behind it, and only as big as it is.
  property bool bare: false

  readonly property string widgetId: Util.canonicalWidgetId(String(modelData && modelData.id || ""))
  readonly property var registryComponent: {
    var registry = host ? host.barWidgetRegistry : null
    var widgets = registry ? registry.widgets : null
    return widgets && widgets[widgetId] ? widgets[widgetId].component : null
  }
  readonly property alias item: loader.item

  // Which of the notch's own icons stands in for the widget's.
  readonly property string icon: ({
    "omarchy.network": "wifi",
    "omarchy.bluetooth": "bluetooth",
    "omarchy.audio": "volume",
    "omarchy.power": "battery",
    "omarchy.monitor": "display",
    "mike.claude-sessions": "claude",
    "omarchy.agents": "usage"
  })[widgetId] || ""
  readonly property bool custom: icon !== "" && !!host && !!host.status
  readonly property var st: host && host.status ? host.status : ({})

  // A widget that hides itself (no updates waiting, nothing to indicate)
  // takes no room. Its own `visible` is read, so this item stays visible.
  readonly property bool hiddenHere: (hiddenIds || []).indexOf(widgetId) !== -1
  readonly property bool shown: !hiddenHere
    && !!loader.item && loader.item.visible && (custom || loader.item.implicitWidth > 0)
  readonly property real chipWidth: bare
    ? (custom ? (icon === "battery" ? ((st.battery || {}).charging ? 36 : 28) : 20) : Math.ceil(loader.width))
    : (custom ? (icon === "battery" ? ((st.battery || {}).charging ? 56 : 48) : 32) : Math.max(32, Math.ceil(loader.width) + 12))

  width: shown ? chipWidth + (bare ? 0 : 6) : 0
  height: bare ? Math.max(22, custom ? 22 : Math.ceil(loader.height)) : 32
  anchors.verticalCenter: parent ? parent.verticalCenter : undefined

  Rectangle {
    width: root.chipWidth
    height: 32
    radius: 16
    visible: root.shown && !root.bare
    color: hover.hovered ? Theme.cardHover : Theme.card
    scale: hover.hovered ? 1.04 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  // The notch's own icon, drawn under the invisible widget.
  Item {
    visible: root.shown && root.custom
    width: root.chipWidth
    height: root.bare ? root.height : 32

    WifiIcon {
      visible: root.icon === "wifi" && (root.st.wifi || {}).kind !== "ethernet"
      anchors.centerIn: parent
      size: 16
      connected: (root.st.wifi || {}).kind === "wifi"
      strength: (root.st.wifi || {}).strength || 0
    }
    Text {
      visible: root.icon === "wifi" && (root.st.wifi || {}).kind === "ethernet"
      anchors.centerIn: parent
      text: String.fromCodePoint(0xF0200)
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.glyphs
      font.pixelSize: 15
    }
    BluetoothIcon {
      visible: root.icon === "bluetooth"
      anchors.centerIn: parent
      size: 16
      enabled_: !!(root.st.bluetooth || {}).enabled
      connected: !!(root.st.bluetooth || {}).connected
    }
    VolumeIcon {
      visible: root.icon === "volume"
      anchors.centerIn: parent
      size: 17
      level: (root.st.volume || {}).level || 0
      muted: !!(root.st.volume || {}).muted
    }
    BatteryIcon {
      visible: root.icon === "battery"
      anchors.centerIn: parent
      size: 26
      present: !!(root.st.battery || {}).present
      level: (root.st.battery || {}).level || 0
      charging: !!(root.st.battery || {}).charging
    }
    DisplayIcon {
      visible: root.icon === "display"
      anchors.centerIn: parent
      size: 15
    }
    AgentMark {
      visible: root.icon === "claude"
      anchors.centerIn: parent
      size: 17
      agent: (root.st.claude || {}).agent || "claude"
      working: ((root.st.claude || {}).working || 0) > 0
      needs: ((root.st.claude || {}).needs || 0) > 0
      motion: root.host ? root.host.motion : 1
    }
    UsageDial {
      visible: root.icon === "usage"
      anchors.centerIn: parent
      size: 15
      ready: !!(root.st.usage || {}).ready
      percent: (root.st.usage || {}).session || 0
    }
  }

  Loader {
    id: loader
    // A widget with a stand-in icon fills the button, invisibly; the rest
    // keep their own size and look.
    width: root.custom ? root.chipWidth : implicitWidth
    height: root.custom ? (root.bare ? root.height : 32) : implicitHeight
    x: root.custom || root.bare ? 0 : (root.chipWidth - width) / 2
    anchors.verticalCenter: parent.verticalCenter
    // Left out of the row: there, but invisible and out of the pointer's way.
    opacity: root.custom || root.hiddenHere ? 0 : 1
    enabled: !root.hiddenHere
    active: root.registryComponent !== null
    sourceComponent: root.registryComponent
    onLoaded: { root.inject(); Qt.callLater(root.inject) }
  }

  HoverHandler { id: hover }

  function inject() {
    var target = loader.item
    if (!target || !host) return
    if ("fixedEdge" in target) target.fixedEdge = "center"
    if ("bar" in target) target.bar = host
    if ("moduleName" in target) target.moduleName = widgetId
    if ("settings" in target) target.settings = host.entrySettings(modelData)
  }
  onModelDataChanged: inject()
  Component.onCompleted: if (host && register) host.registerHost(root)
  Component.onDestruction: if (host && register) host.unregisterHost(root)
}
