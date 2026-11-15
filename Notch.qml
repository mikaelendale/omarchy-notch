import QtQuick
import "Palette.js" as P

// The top notch: one black slab at the top centre of the screen.
//
// Closed, it shows the items the layout gives it (by default the agents' mark
// and the time; the corners beside it hold music, Wi-Fi and the battery); it
// grows wider for what's live (an agent waiting on you) the way a phone's
// island does. Hovered, it opens downward into the full bar: the Omarchy menu,
// the clock, and one fixed-width, scrollable row of round buttons (tray apps
// and Omarchy's own widgets, lent by the bar plugin through traySlot and
// statusSlot), with cards for music, today and Claude below.
//
// Pure QtQuick, no Quickshell: the bar plugin feeds it data, and the tests
// render it off screen with made-up data.
Item {
  id: root

  // ---- inputs
  property bool forceOpen: false      // tests, and `omarchy-shell mike.notch toggle`
  property bool hold: false           // a panel or tray menu is open: stay open
  property real motion: 1             // 0 when Omarchy's animations are off
  property date now: new Date()
  property string clockFormat: "h:mm AP"
  property var media: ({ available: false })
  property var claude: ({ sessions: [], counts: ({}) })
  // Wi-Fi and battery for the closed notch: { wifi: { kind, strength,
  // connected }, battery: { present, level, charging } }.
  property var status: ({})
  // A Claude session waiting on you: { title, detail, session }, or null. The
  // notch grows into a toast for it, like a phone's incoming-call island.
  property var alert: null

  // What the closed notch shows, in order (Layout.js); the corners show the rest.
  property var items: ["agents", "clock"]
  // The open notch's cards, in order: system, media, today, agents.
  property var cards: ["system", "today", "agents"]
  // The machine, for the system card (SystemCard.qml).
  property var system: ({ ready: false })
  // Notifications you've had, newest first, for the notifications card.
  property var notifications: []

  // Where the bar plugin puts the menu, tray apps and Omarchy's widgets.
  readonly property alias menuSlot: menuSlotItem
  readonly property alias traySlot: traySlotItem
  readonly property alias statusSlot: statusSlotItem

  signal mediaRequested(string action)
  signal sessionRequested(var session)
  signal conversationsRequested()
  signal alertDismissed()
  // Right-click: edit what the bar shows.
  signal editRequested()
  signal notificationsCleared()
  signal notificationsShowAll()
  // A workspace was picked (a dot, or a number in the open notch).
  signal workspaceRequested(int id)

  // ---- geometry
  readonly property real collapsedHeight: 34
  // Attached (the default) hangs from the top edge and flares into it;
  // floating is a pill of its own, a little below the edge (Bar.qml places it).
  property bool floating: false
  readonly property real flare: floating ? 0 : 12
  // Unified: the bar draws one strip across the top; the notch's own body
  // only shows below it, as it opens.
  property bool unified: false
  // Bar widgets placed in the closed notch, and every running agent.
  property var widgetFactory: null
  property bool allAgents: false
  readonly property alias closedRowItem: collapsedRow
  // More cards need more room, and a long row of buttons more again; never
  // more than the screen has (maxExpandedWidth, from the bar).
  property real maxExpandedWidth: 1800
  readonly property real topRowNeeds: 36 + topRow.leftUsed + 14 + clockLabel.implicitWidth + 16 + stripRow.implicitWidth
  // Room for the cards: Today keeps 190, the others want about 260 each.
  readonly property real cardsNeed: 28 + (cards.indexOf("today") !== -1 ? 190 : 0)
    + cards.filter(function(c) { return c !== "today" }).length * 260 + Math.max(0, cards.length - 1) * 10
  readonly property real expandedWidth: Math.min(maxExpandedWidth, Math.max(840, cardsNeed, topRowNeeds))
  readonly property real expandedHeight: 222

  property bool hoverOpen: false
  readonly property bool alertActive: !!alert
  // While a toast shows, hovering doesn't open the bar, so its button can be clicked.
  readonly property bool open: forceOpen || hold || (hoverOpen && !alertActive)
  readonly property bool hovered: hover.hovered

  // In full-screen mode windows run under the notch, so while nothing's going
  // on it's see-through and whatever is beneath shows; it turns solid the
  // moment it's hovered or opened, shows a toast or a notification, or an
  // agent needs you.
  property bool notificationsShowing: false
  // Only in full-screen mode, where windows run under it, does it fade when
  // idle; with a strip of its own it stays solid glass.
  property bool seeThroughWhenIdle: true
  property real idleOpacity: 0.42
  readonly property bool active: hovered || open || alertActive || needsCount > 0 || notificationsShowing
  opacity: active || !seeThroughWhenIdle ? 1 : idleOpacity
  Behavior on opacity { NumberAnimation { duration: (root.active ? 110 : 240) * root.motion; easing.type: Easing.OutCubic } }

  // One number drives the whole morph, 0 closed to 1 open, so the slab's size,
  // its corners and the two layers of content can never drift apart.
  property real progress: open ? 1 : 0
  // iOS-style: a stiff, critically damped spring: most of the way in about a
  // tenth of a second, settled in a quarter, no bounce.
  Behavior on progress { enabled: root.motion > 0; SpringAnimation { spring: 9.0; damping: 0.8; epsilon: 0.001 } }

  // The closed width follows what's live, easing as an activity comes or goes.
  readonly property real collapsedTarget: Math.max(132, collapsedRow.implicitWidth + 36)
  property real collapsedWidth: collapsedTarget
  Behavior on collapsedWidth { enabled: root.motion > 0; SpringAnimation { spring: 9.0; damping: 0.8; epsilon: 0.001 } }

  function mix(a, b, t) { return a + (b - a) * t }
  function clamp01(v) { return Math.max(0, Math.min(1, v)) }

  // The toast's own 0..1, blended in before the open bar's.
  readonly property real alertWidth: 440
  readonly property real alertHeight: 74
  property real alertProgress: alertActive ? 1 : 0
  Behavior on alertProgress { enabled: root.motion > 0; SpringAnimation { spring: 9.0; damping: 0.8; epsilon: 0.001 } }

  readonly property real baseW: mix(collapsedWidth, alertWidth, alertProgress)
  readonly property real baseH: mix(collapsedHeight, alertHeight, alertProgress)
  readonly property real baseR: mix(collapsedHeight / 2, 30, alertProgress)
  readonly property real bodyW: mix(baseW, expandedWidth, progress)
  readonly property real bodyH: mix(baseH, expandedHeight, progress)
  readonly property real bodyR: mix(baseR, 30, progress)
  // Closed content is gone by a quarter of the way; open content arrives in
  // the last stretch, so no two layers ever show at once.
  readonly property real closedOpacity: clamp01(1 - Math.max(progress, alertProgress) / 0.25)
  readonly property real alertOpacity: clamp01((alertProgress - 0.55) / 0.45) * clamp01(1 - progress / 0.25)
  readonly property real openOpacity: clamp01((progress - 0.5) / 0.4)

  // The item is as big as the open notch so the slab can grow inside it
  // without the window resizing; only the slab takes the pointer (hitArea).
  implicitWidth: expandedWidth + 2 * flare
  implicitHeight: expandedHeight
  readonly property alias hitArea: hit

  // ---- live activity, closed
  readonly property var counts: claude && claude.counts ? claude.counts : ({})
  readonly property int needsCount: (counts.needs || 0)
  readonly property int workingCount: (counts.working || 0) + (counts.watching || 0)
  // Every coding agent's sessions (Claude, Codex, OpenCode...). The closed
  // notch shows the one that matters most: one waiting on you, else one at
  // work, else your default agent.
  property string defaultAgent: "claude"
  readonly property var sessionList: claude && claude.sessions ? claude.sessions : []
  readonly property var lead: {
    var list = sessionList
    for (var i = 0; i < list.length; i++) if (list[i].state === "needs") return list[i]
    for (var j = 0; j < list.length; j++) if (list[j].state === "working" || list[j].state === "watching") return list[j]
    return { agent: defaultAgent, state: "idle" }
  }
  readonly property bool playing: !!(media && media.available && media.playing)

  // ---- hover: a short dwell to open, a short grace to close
  Timer {
    id: openTimer
    interval: 50
    onTriggered: root.hoverOpen = true
  }
  Timer {
    id: closeTimer
    interval: 180
    onTriggered: if (!hover.hovered) root.hoverOpen = false
  }
  // A panel or menu just closed (clicking its button again, Esc...). While it
  // was up its window covered the notch, so hover can't be trusted yet: stay
  // open and only close if the pointer isn't back on the notch shortly.
  onHoldChanged: if (!hold) { openTimer.stop(); closeTimer.stop(); hoverOpen = true; releaseTimer.restart() }
  Timer {
    id: releaseTimer
    interval: 650
    onTriggered: if (!hover.hovered) root.hoverOpen = false
  }
  // Over a placed widget the notch stays shut, so the widget can be used.
  function closedItemAt(x) {
    var q = collapsedRow.mapFromItem(hit, x, 0)
    var item = collapsedRow.childAt(q.x, collapsedRow.height / 2)
    return item && item.itemId ? item.itemId : ""
  }
  readonly property bool wantsOpen: hovered && (open || closedItemAt(hover.point.position.x).indexOf("w:") !== 0)
  onWantsOpenChanged: {
    if (wantsOpen) { closeTimer.stop(); releaseTimer.stop(); openTimer.restart() }
    else { openTimer.stop(); closeTimer.restart() }
  }

  NotchShape {
    id: shape
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.unified ? root.collapsedHeight : 0
    visible: bodyHeight > 0.5
    bodyWidth: root.bodyW
    bodyHeight: root.unified ? Math.max(0, root.bodyH - root.collapsedHeight) : root.bodyH
    radius: root.bodyR
    flare: root.flare
    floating: root.floating
    color: Theme.body
  }

  Item {
    id: hit
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.bodyW
    height: root.bodyH
    clip: true

    HoverHandler { id: hover }
    TapHandler {
      enabled: !root.open && !root.alertActive
      onTapped: function(point) {
        // A click on a placed widget is the widget's.
        if (root.closedItemAt(point.position.x).indexOf("w:") === 0) return
        closeTimer.stop()
        root.hoverOpen = true
      }
    }
    TapHandler {
      acceptedButtons: Qt.RightButton
      onTapped: root.editRequested()
    }

    // ---------------------------------------------------------- closed
    // The items the layout puts in the notch (Layout.js; by default the
    // agents' mark and the time), drawn small.
    Row {
      id: collapsedRow
      anchors.horizontalCenter: parent.horizontalCenter
      y: (root.collapsedHeight - height) / 2
      height: 22
      spacing: 10
      opacity: root.closedOpacity
      visible: opacity > 0

      Repeater {
        model: root.items
        StatusItem {
          required property string modelData
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          itemId: modelData
          status: root.status
          media: root.media
          now: root.now
          clockFormat: root.clockFormat
          motion: root.motion
          lead: root.lead
          needsCount: root.needsCount
          widgetFactory: root.widgetFactory
          sessions: root.sessionList
          allAgents: root.allAgents
          onWorkspaceRequested: function(id) { root.workspaceRequested(id) }
        }
      }
    }

    // ----------------------------------------------------------- toast
    Item {
      id: toast
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.alertWidth
      height: root.alertHeight
      opacity: root.alertOpacity
      visible: opacity > 0
      enabled: root.alertActive && !root.open

      AgentMark {
        x: 22
        anchors.verticalCenter: parent.verticalCenter
        size: 30
        agent: root.alert && root.alert.session && root.alert.session.agent ? root.alert.session.agent : "claude"
        needs: true
        motion: root.motion
      }
      Column {
        x: 66
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 66 - openButton.width - 34
        spacing: 2
        Text {
          width: parent.width
          text: root.alert ? (root.alert.title || "Claude needs you") : ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }
        Text {
          width: parent.width
          text: root.alert ? (root.alert.detail || "") : ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Theme.secondary
          font.family: P.sans
          font.pixelSize: 12
        }
      }
      Rectangle {
        id: openButton
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 74
        height: 34
        radius: 17
        color: Theme.text
        opacity: openHover.hovered ? 1 : 0.9
        scale: openTap.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }
        Text {
          anchors.centerIn: parent
          text: "Open"
          textFormat: Text.PlainText
          color: Theme.onText
          font.family: P.sans
          font.pixelSize: 13
          font.weight: Font.DemiBold
        }
        HoverHandler { id: openHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          id: openTap
          onTapped: {
            if (root.alert && root.alert.session) root.sessionRequested(root.alert.session)
            root.alertDismissed()
          }
        }
      }
    }

    // ------------------------------------------------------------ open
    Item {
      id: expanded
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.expandedWidth
      height: root.expandedHeight
      // The content grows with the slab rather than being uncovered by it, so
      // nothing is ever cut off at the edges mid-morph.
      opacity: root.openOpacity
      scale: root.bodyW / root.expandedWidth
      transformOrigin: Item.Top
      visible: opacity > 0
      enabled: root.open

      // Top row: the menu, the clock, and the row of buttons. Nothing
      // scrolls: the buttons fill in from the right, and when the right half
      // can't hold them the clock moves beside the menu and they carry on
      // into the left half. (The notch widens if even that isn't enough.)
      Item {
        id: topRow
        x: 18
        width: parent.width - 36
        height: 44

        readonly property real rightHalf: width / 2 - clockLabel.implicitWidth / 2 - 16
        readonly property bool clockCentered: stripRow.implicitWidth <= rightHalf

        Row {
          id: menuSlotItem
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6
        }

        // The workspaces, numbered, while their dots are in the notch: the
        // open notch covers the dots, so here's where to pick one.
        Row {
          id: wsSwitcher
          readonly property var dots: root.items.indexOf("workspaces") !== -1 && root.status && root.status.workspaces
            ? root.status.workspaces : []
          visible: dots.length > 0
          x: menuSlotItem.width + (menuSlotItem.width > 0 ? 10 : 0)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Repeater {
            model: wsSwitcher.dots
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
              TapHandler { onTapped: root.workspaceRequested(parent.modelData.id) }
            }
          }
        }
        readonly property real leftUsed: wsSwitcher.visible ? wsSwitcher.x + wsSwitcher.width : menuSlotItem.width

        Text {
          id: clockLabel
          x: topRow.clockCentered && Math.round((topRow.width - implicitWidth) / 2) > topRow.leftUsed + 14
            ? Math.round((topRow.width - implicitWidth) / 2)
            : topRow.leftUsed + (topRow.leftUsed > 0 ? 14 : 0)
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatTime(root.now, root.clockFormat)
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 14
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
        }

        Item {
          id: strip
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, Math.min(stripRow.implicitWidth, topRow.width - (clockLabel.x + clockLabel.implicitWidth + 16)))
          height: 34
          // Only ever cuts anything on a screen too narrow for the widest notch.
          clip: true

          Row {
            id: stripRow
            anchors.right: parent.right
            height: parent.height
            spacing: 6
            Row {
              id: statusSlotItem
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6
            }
            Row {
              id: traySlotItem
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6
            }
          }
        }
      }

      // Cards, as the layout lists them (by default the machine, today and the
      // agents; the music lives in its corner). Today keeps its size; the
      // others share the rest of the row.
      Row {
        id: cardRow
        x: 14
        y: topRow.height + 4
        spacing: 10
        readonly property real cardHeight: root.expandedHeight - y - 14
        readonly property real rowWidth: root.expandedWidth - 28
        readonly property int flexible: root.cards.filter(function(c) { return c !== "today" }).length
        readonly property real todayWidth: root.cards.indexOf("today") !== -1 ? (flexible > 0 ? 190 : rowWidth) : 0
        readonly property real flexWidth: flexible > 0
          ? (rowWidth - todayWidth - spacing * Math.max(0, root.cards.length - 1)) / flexible : 0

        Repeater {
          model: root.cards
          Loader {
            required property string modelData
            width: modelData === "today" ? cardRow.todayWidth : cardRow.flexWidth
            height: cardRow.cardHeight
            sourceComponent: ({ system: systemCard, notifications: notificationsCard, media: mediaCard, today: todayCard, agents: agentsCard })[modelData] || null
          }
        }
      }
    }
  }

  Component {
    id: systemCard
    SystemCard {
      system: root.system
      motion: root.motion
    }
  }
  Component {
    id: notificationsCard
    NotificationsCard {
      notifications: root.notifications
      now: root.now
      motion: root.motion
      onCleared: root.notificationsCleared()
      onShowAll: root.notificationsShowAll()
    }
  }
  Component {
    id: mediaCard
    MediaCard {
      media: root.media
      motion: root.motion
      onRequested: function(action) { root.mediaRequested(action) }
    }
  }
  Component {
    id: todayCard
    TodayCard { now: root.now }
  }
  Component {
    id: agentsCard
    ClaudeCard {
      defaultAgent: root.defaultAgent
      claude: root.claude
      motion: root.motion
      onSessionRequested: function(session) { root.sessionRequested(session) }
      onConversationsRequested: root.conversationsRequested()
    }
  }
}
