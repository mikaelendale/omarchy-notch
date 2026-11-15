import QtQuick
import "Palette.js" as P

// A corner of the top edge: a short frosted pill tucked into the top-left or
// top-right corner of the screen, beside the notch. It shows its items small
// (music on the left, Wi-Fi, Bluetooth and the battery on the right, by
// default; the editor moves them), and opens downward on hover: music into a
// player, everything else into a row each with the details.
//
// It only shows while it has something to show: a corner holding only music
// appears when something plays and stays, paused, until the player goes.
//
// Pure QtQuick: the bar plugin feeds it data, and the tests render it off
// screen with made-up data.
Item {
  id: root

  // ---- inputs
  property string side: "left"          // "left" | "right"
  property var items: []                 // item ids, in order (Layout.js)
  property var status: ({})
  property var media: ({ available: false })
  property date now: new Date()
  property string clockFormat: "h:mm AP"
  property real motion: 1
  property var lead: ({ agent: "claude", state: "idle" })
  property var counts: ({})
  readonly property int needsCount: counts && counts.needs ? counts.needs : 0
  property bool forceOpen: false        // tests
  property bool hoverEnabled: true      // tests: the off-screen pointer sits in a corner
  property bool seeThroughWhenIdle: false
  property real idleOpacity: 0.42
  // Hidden altogether: in full-screen mode, and while an app is fullscreen
  // (Super+F), only the notch shows.
  property bool suppressed: false
  // One of Omarchy's panels is open from this corner: stay shut, so the
  // panel hangs right under it.
  property bool holdClosed: false
  // Floating: a pill of its own, `inset` in from the top and side edges,
  // instead of tucked into the corner.
  property bool floating: false
  readonly property real inset: floating ? 8 : 0
  // Unified: the bar draws one strip across the top; this corner's own body
  // only shows when it opens, hanging from that strip. While the strip keeps
  // a gap from the screen's side, the corner sits that much further in
  // (extraX, from the bar), and slides out with the strip as it stretches.
  property bool unified: false
  property real extraX: 0
  // Bar widgets placed here, and every running agent (see StatusItem).
  property var widgetFactory: null
  property var sessions: []
  property bool allAgents: false
  // The open notch reaches over this corner: step aside until it closes.
  property bool covered: false

  // Where the bar puts Omarchy's widgets for this corner's panels (Wi-Fi,
  // Bluetooth, battery, sound), so a panel opens from the corner itself.
  readonly property alias panelSlot: panelSlotItem

  signal mediaRequested(string action, var value)
  // A detail row was clicked: open (the item's panel), speedtest, mute, volume.
  signal itemRequested(string itemId, string action, var value)
  signal editRequested()
  // A workspace dot or number was clicked.
  signal workspaceRequested(int id)
  // A scroll: kind "tracks" (over the music), "workspaces" (over the dots) or
  // "volume" (anywhere else); steps up are positive.
  signal wheelRequested(string kind, int steps)

  readonly property bool mirrored: side === "right"

  // ---- what's showing
  readonly property bool mediaAvailable: !!(media && media.available)
  readonly property var shownItems: (items || []).filter(function(id) {
    if (String(id).indexOf("w:") === 0) return !!root.widgetFactory
    if (id === "media") return root.mediaAvailable
    if (id === "battery") return !!(root.status && root.status.battery && root.status.battery.present)
    if (id === "privacy") {
      var pv = root.status && root.status.privacy ? root.status.privacy : ({})
      return !!(pv.mic || pv.camera || pv.screen)
    }
    if (id === "workspaces") return !!(root.status && root.status.workspaces && root.status.workspaces.length > 0)
    return true
  })
  readonly property bool shown: !suppressed && shownItems.length > 0
  readonly property bool hasMedia: shownItems.indexOf("media") !== -1
  // Placed widgets have no details of their own: they're clicked where they are.
  readonly property var detailItems: shownItems.filter(function(id) { return id !== "media" && String(id).indexOf("w:") !== 0 })
  readonly property bool canOpen: hasMedia || detailItems.length > 0

  // ---- geometry
  readonly property real collapsedHeight: 34
  readonly property real flare: floating ? 0 : 12
  readonly property real edgePad: 16      // from the screen's side edge
  readonly property real innerPad: 16     // toward the middle of the screen
  readonly property real collapsedTarget: Math.max(collapsedHeight + 12, closedRow.implicitWidth + edgePad + innerPad)
  property real collapsedWidth: collapsedTarget
  Behavior on collapsedWidth { enabled: root.motion > 0; NumberAnimation { duration: Motion.close; easing.type: Easing.OutCubic } }

  readonly property real openPad: 14
  readonly property real expandedWidth: hasMedia ? 344 : 312
  readonly property real expandedHeight: openPad + 4 + openColumn.implicitHeight + openPad

  // ---- motion: one number for being there at all, one for open
  property real presence: shown ? 1 : 0
  Behavior on presence { enabled: root.motion > 0; NumberAnimation { duration: Motion.open; easing.type: Easing.OutCubic } }

  property bool hoverOpen: false
  readonly property bool open: shown && canOpen && !holdClosed && (forceOpen || hoverOpen)
  property real progress: open ? 1 : 0
  Behavior on progress { enabled: root.motion > 0; NumberAnimation { duration: root.open ? Motion.open : Motion.close; easing.type: Easing.OutCubic } }

  function mix(a, b, t) { return a + (b - a) * t }
  function clamp01(v) { return Math.max(0, Math.min(1, v)) }

  readonly property real bodyW: mix(collapsedWidth, expandedWidth, progress) * presence
  readonly property real bodyH: mix(collapsedHeight, expandedHeight, progress) * presence
  readonly property real bodyR: mix(collapsedHeight / 2, 26, progress)
  readonly property real closedOpacity: clamp01(1 - progress / 0.25) * clamp01((presence - 0.6) / 0.4)
  readonly property real openOpacity: clamp01((progress - 0.5) / 0.4)

  // Big enough for the open corner, so the window never resizes.
  implicitWidth: Math.max(expandedWidth, collapsedTarget) + flare + inset + extraX
  implicitHeight: expandedHeight + flare + inset

  readonly property bool hovered: hover.hovered
  readonly property bool active: hovered || open
  opacity: covered ? 0 : (active || !seeThroughWhenIdle ? 1 : idleOpacity)
  enabled: !covered
  Behavior on opacity { NumberAnimation { duration: (root.active ? 110 : 240) * root.motion; easing.type: Easing.OutCubic } }

  // ---- hover: a short dwell to open, a short grace to close
  Timer { id: openTimer; interval: 60; onTriggered: root.hoverOpen = true }
  Timer { id: closeTimer; interval: 180; onTriggered: if (!hover.hovered) root.hoverOpen = false }
  // Over a placed widget the corner stays shut, so the widget can be used.
  readonly property bool wantsOpen: hover.hovered && (open || closedItemAt(hover.point.position.x).indexOf("w:") !== 0)
  onWantsOpenChanged: {
    if (wantsOpen) { closeTimer.stop(); openTimer.restart() }
    else { openTimer.stop(); closeTimer.restart() }
  }
  onShownChanged: if (!shown) hoverOpen = false

  // What's under the pointer (in the body's coordinates), for a scroll.
  property string wheelKind: ""
  property real wheelSum: 0
  property double lastSkip: 0
  function kindAt(x, y) {
    if (open) {
      var p = openColumn.mapFromItem(hit, x, y)
      var child = openColumn.childAt(p.x, p.y)
      if (child && child.objectName === "player") return "tracks"
      if (child && child.itemId === "workspaces") return "workspaces"
      return "volume"
    }
    var id = closedItemAt(x)
    if (id === "media") return "tracks"
    if (id === "workspaces") return "workspaces"
    if (id.indexOf("w:") === 0) return ""
    return "volume"
  }
  // The closed row's item at x (in the body's coordinates), or "".
  function closedItemAt(x) {
    var q = closedRow.mapFromItem(hit, x, 0)
    var item = closedRow.childAt(q.x, closedRow.height / 2)
    return item && item.itemId ? item.itemId : ""
  }
  onHoldClosedChanged: if (holdClosed) { openTimer.stop(); hoverOpen = false }

  // Invisible, over the closed row: Omarchy's widgets sit here, so their
  // panels open under the corner. They never take the pointer.
  Item {
    id: panelSlotItem
    x: root.mirrored ? root.width - root.inset - root.extraX - root.edgePad - width : root.inset + root.extraX + root.edgePad
    y: root.inset
    width: Math.max(32, closedRow.width)
    height: root.collapsedHeight
    opacity: 0
    enabled: false
  }

  EarShape {
    // Unified: the bar draws this, as part of its own outline.
    visible: !root.unified
    x: root.mirrored ? root.width - width - root.inset - root.extraX : root.inset + root.extraX
    y: root.unified ? root.collapsedHeight : root.inset
    floating: root.floating
    mirrored: root.mirrored
    bodyWidth: root.bodyW
    bodyHeight: root.unified ? Math.max(0, root.bodyH - root.collapsedHeight) : root.bodyH
    radius: root.bodyR
    flare: root.flare * root.presence
  }

  Item {
    id: hit
    x: root.mirrored ? root.width - width - root.inset - root.extraX : root.inset + root.extraX
    y: root.inset
    width: root.bodyW
    height: root.bodyH
    clip: true

    HoverHandler { id: hover; enabled: root.hoverEnabled }
    // Right-click: edit what the bar shows.
    TapHandler {
      acceptedButtons: Qt.RightButton
      onTapped: root.editRequested()
    }
    // A tap on the closed corner, on its music: go to the window that's
    // playing. (Open, the player's cover and title do the same.)
    TapHandler {
      enabled: root.hasMedia && !root.open
      onTapped: function(point) {
        var id = root.closedItemAt(point.position.x)
        if (id === "media" || id === "") root.mediaRequested("raise", null)
      }
    }

    // Scrolling: one step per wheel notch (a touchpad adds its small moves up
    // to one); tracks wait a moment between skips.
    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x
        var kind = root.kindAt(point.position.x, point.position.y)
        if (kind === "") return
        if (kind !== root.wheelKind) { root.wheelKind = kind; root.wheelSum = 0 }
        root.wheelSum += delta
        var steps = root.wheelSum > 0 ? Math.floor(root.wheelSum / 120) : Math.ceil(root.wheelSum / 120)
        if (steps === 0) return
        root.wheelSum -= steps * 120
        if (kind === "tracks") {
          var now = Date.now()
          if (now - root.lastSkip < 450) return
          root.lastSkip = now
          steps = steps > 0 ? 1 : -1
        }
        root.wheelRequested(kind, steps)
      }
    }

    // ---------------------------------------------------------- closed
    Row {
      id: closedRow
      x: root.mirrored ? parent.width - width - root.edgePad : root.edgePad
      y: (root.collapsedHeight - height) / 2
      height: 22
      spacing: 11
      layoutDirection: Qt.LeftToRight
      opacity: root.closedOpacity
      visible: opacity > 0

      Repeater {
        model: root.shownItems
        StatusItem {
          required property string modelData
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          itemId: modelData
          wide: true
          status: root.status
          media: root.media
          now: root.now
          clockFormat: root.clockFormat
          motion: root.motion
          lead: root.lead
          needsCount: root.needsCount
          widgetFactory: root.widgetFactory
          sessions: root.sessions
          allAgents: root.allAgents
          onWorkspaceRequested: function(id) { root.workspaceRequested(id) }
        }
      }
    }

    // ------------------------------------------------------------ open
    Item {
      id: openContent
      x: root.mirrored ? parent.width - width : 0
      width: root.expandedWidth
      height: root.expandedHeight
      opacity: root.openOpacity
      visible: opacity > 0
      enabled: root.open
      // Grows with the body from the screen's corner, by whichever of its
      // width and height lags, so nothing is cut off mid-morph.
      scale: root.expandedWidth > 0 && root.expandedHeight > 0
        ? Math.max(0.01, Math.min(root.bodyW / root.expandedWidth, root.bodyH / root.expandedHeight)) : 1
      transformOrigin: root.mirrored ? Item.TopRight : Item.TopLeft

      Column {
        id: openColumn
        x: root.openPad
        y: root.openPad + 4
        width: root.expandedWidth - 2 * root.openPad
        spacing: 6

        MiniPlayer {
          objectName: "player"
          visible: root.hasMedia
          width: parent.width
          height: visible ? implicitHeight : 0
          media: root.media
          motion: root.motion
          onRequested: function(action, value) { root.mediaRequested(action, value) }
        }
        // A little air between the player and the rows below it.
        Item { width: 1; height: root.hasMedia && root.detailItems.length > 0 ? 6 : 0; visible: height > 0 }
        Repeater {
          model: root.detailItems
          DetailRow {
            required property string modelData
            width: openColumn.width
            itemId: modelData
            status: root.status
            now: root.now
            motion: root.motion
            lead: root.lead
            counts: root.counts
            onRequested: function(action, value) {
              if (action === "workspace") root.workspaceRequested(value)
              else root.itemRequested(modelData, action, value)
            }
          }
        }
      }
    }
  }
}
