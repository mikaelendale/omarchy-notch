import QtQuick
import "Palette.js" as P

// The side notch: a slim black strip of icons growing out of the left or
// right screen edge.
//
//   ━   grip: drag the strip up and down the edge, or across to the other edge
//   ⏻   Modes: hover to open the switches downward (Do not disturb, Stay
//       awake, Night light, Mute, window layout); hover a switch for its name
//   🔊  Volume: hover to slide out a slider; click to mute; scroll to nudge
//   ☀   Brightness: the same
//   ◔   Usage: how much of the Claude plan is used
//
// Everything opens on hover and closes when the pointer leaves. Pure QtQuick:
// Bar.qml owns the data and the window, and builds the window's input mask
// from stripTop, bodyH and flyGeom.
Item {
  id: root

  // ---- inputs
  property string edge: "right"
  property real motion: 1
  property var modes: ({ dnd: false, awake: false, nightlight: false, muted: false, layout: "dwindle" })
  property real volume: 0.5
  property real brightness: 0.5
  property bool brightnessAvailable: true
  property var usage: ({ ready: false })
  property bool fullscreen: false       // a fullscreen app is up: hide until hovered
  property real roomBelow: 10000        // px free under the strip (from Bar.qml)

  signal modeRequested(string mode)
  signal volumeRequested(real value)
  signal brightnessRequested(real value)
  signal muteRequested()
  signal dragged(real dx, real dy)       // live, since the press
  signal dropped(real dx, real dy)

  readonly property bool onLeft: edge === "left"
  readonly property bool towardLeft: !onLeft    // which way the tabs slide out

  // ---- geometry
  readonly property real stripW: 46
  readonly property real flare: 12
  readonly property real rowH: 42
  readonly property real modeRowH: 38
  readonly property real gripH: 18
  readonly property real padTop: 6
  readonly property real padBottom: 14
  readonly property real flyMax: 236
  // Tabs meet the strip edge to edge (no tuck): frost layered on frost
  // would show a darker band.
  readonly property real overlap: 0

  readonly property var modeList: [
    { key: "dnd", name: "Do not disturb", tint: Theme.purple, glyph: 0xF0F65 },
    { key: "awake", name: "Stay awake", tint: Theme.yellow, glyph: 0xF0176 },
    { key: "nightlight", name: "Night light", tint: Theme.orange, glyph: 0xF1A4C },
    { key: "mute", name: "Mute", tint: Theme.red, glyph: 0xF0581 },
    { key: "layout", name: "Window layout", tint: Theme.blue, glyph: 0xF056E },
    { key: "screen", name: "Full screen", tint: Theme.teal, glyph: 0xF0293 }
  ]
  function modeOn(key) {
    if (key === "dnd") return !!modes.dnd
    if (key === "awake") return !!modes.awake
    if (key === "nightlight") return !!modes.nightlight
    if (key === "mute") return !!modes.muted
    if (key === "layout") return String(modes.layout || "dwindle") !== "dwindle"
    if (key === "screen") return modes.screen !== false
    return false
  }
  function modeState(key) {
    if (key === "layout") {
      var l = String(modes.layout || "dwindle")
      return l === "floating" ? "Floating" : (l === "scrolling" ? "Scrolling" : "Tiled")
    }
    return modeOn(key) ? "On" : "Off"
  }
  function layoutGlyph() {
    var l = String(modes.layout || "dwindle")
    return l === "floating" ? 0xF05B2 : (l === "scrolling" ? 0xF10AB : 0xF056E)
  }

  // ---- state
  property string active: ""            // the tab that's out: volume, brightness, usage, mode:<key>
  property bool dragging: false
  // Set while dragging and a moment after, so the release at the end of a
  // drag that started on an icon doesn't count as a click on it.
  property bool justDragged: false
  Timer { id: dragSettle; interval: 160; onTriggered: root.justDragged = false }
  property bool modesOpen: false
  property real modesAmount: modesOpen ? 1 : 0
  Behavior on modesAmount { enabled: root.motion > 0; SpringAnimation { spring: 11.0; damping: 0.85; epsilon: 0.001 } }

  // In use: under the pointer, being dragged, or something's open. Out of
  // use, the strip fades back to a ghost (and to nothing over a fullscreen
  // app), and comes forward the moment the pointer reaches it.
  readonly property bool engaged: rootHover.hovered || dragging || active !== "" || modesOpen
  opacity: engaged ? 1 : (fullscreen ? 0 : 0.32)
  Behavior on opacity { NumberAnimation { duration: (root.engaged ? 110 : 240) * root.motion; easing.type: Easing.OutCubic } }
  HoverHandler { id: rootHover }
  // For `omarchy-shell mike.notch sideState`: what the strip thinks is going on.
  function debugState() {
    return JSON.stringify({ active: active, modesOpen: modesOpen, modesUp: modesUp, modesAmount: modesAmount,
      engaged: engaged, rootHovered: rootHover.hovered, modesHovered: modesHover.hovered,
      gripHovered: gripHover.hovered, pointer: [Math.round(rootHover.point.position.x), Math.round(rootHover.point.position.y)],
      dragging: dragging, justDragged: justDragged, y: y, height: height })
  }

  readonly property real modesListH: modeList.length * modeRowH + 4
  readonly property int rows: brightnessAvailable ? 4 : 3
  // Modes drops down over the rows beneath it rather than pushing them, so
  // nothing moves under the pointer; the strip only grows by however much
  // the list reaches past its own bottom.
  readonly property real restBodyH: padTop + gripH + rowH * rows + padBottom
  // How much longer the strip gets with Modes down over the rows.
  readonly property real modesOverhang: Math.max(0, padTop + gripH + rowH + modesListH + padBottom - restBodyH)
  // Near the bottom of the screen there's no room for that, so Modes opens
  // upward instead: the list sits above its icon, the strip grows up, and
  // Bar.qml holds its bottom still so the icon stays under the pointer.
  // Decided as it opens, and kept until it's shut, so it never flips mid-way.
  property bool modesUp: false
  onModesOpenChanged: if (modesOpen) modesUp = roomBelow < modesOverhang + 4
  readonly property real bodyH: modesUp
    ? restBodyH + modesAmount * modesListH
    : Math.max(restBodyH, padTop + gripH + rowH + modesAmount * modesListH + padBottom)
  // Its height with Modes closed. Bar.qml places the strip by this, so
  // opening Modes grows it downward instead of shifting it under the pointer.
  readonly property real restHeight: restBodyH + 2 * flare

  // Rows, top to bottom (in this item's coordinates).
  readonly property real gripY: flare + padTop
  readonly property real modesY: gripY + gripH + (modesUp ? modesAmount * modesListH : 0)
  readonly property real modesListY: modesUp ? gripY + gripH : modesY + rowH
  readonly property real volumeY: modesY + rowH
  readonly property real brightnessY: volumeY + rowH
  readonly property real usageY: brightnessY + (brightnessAvailable ? rowH : 0)

  readonly property real stripX: onLeft ? 0 : width - stripW
  readonly property real stripInnerX: onLeft ? stripW : width - stripW
  function flyX(w) { return towardLeft ? stripInnerX + overlap - w : stripInnerX - overlap }

  implicitWidth: stripW + flyMax
  implicitHeight: bodyH + 2 * flare

  // ---- input mask for the window: the strip, and the tab that's out. Bar.qml
  // reads these numbers (relative to this item) and sets its Region from them.
  readonly property real stripTop: flare
  readonly property real flyAreaX: flyGeom.w > 0 ? flyX(flyGeom.w) : 0
  readonly property var flyGeom: {
    if (active === "volume") return { y: volumeY + (rowH - 36) / 2, w: 228, h: 36 }
    if (active === "brightness") return { y: brightnessY + (rowH - 36) / 2, w: 228, h: 36 }
    if (active === "usage") return { y: usageY + (rowH - 36) / 2, w: 214, h: 36 }
    if (active.indexOf("mode:") === 0) {
      for (var i = 0; i < modeList.length; i++)
        if ("mode:" + modeList[i].key === active) return { y: modesListY + i * modeRowH + (modeRowH - 30) / 2, w: 176, h: 30 }
    }
    return { y: 0, w: 0, h: 0 }
  }
  Item {
    id: flyMask
    x: root.flyGeom.w > 0 ? root.flyX(root.flyGeom.w) : 0
    y: root.flyGeom.y
    width: root.flyGeom.w
    height: root.flyGeom.h
  }

  // ---- the strip
  SideNotchShape {
    x: root.stripX
    y: 0
    bodyWidth: root.stripW
    bodyHeight: root.bodyH
    radius: 18
    flare: root.flare
    mirrored: root.onLeft
    color: Theme.body
    // No border: a tab sliding out would show it as a seam, cutting the tab
    // off from the strip it grows out of.
    edgeColor: "transparent"
  }

  Item {
    id: stripHit
    x: root.stripX
    y: root.flare
    width: root.stripW
    height: root.bodyH

    // Qt zeroes a drag's translation before it reports the release, so the
    // last distance seen during the drag is the one handed to `dropped`.
    DragHandler {
      id: dragger
      target: null
      property real lastDx: 0
      property real lastDy: 0
      onActiveChanged: {
        if (active) {
          lastDx = 0; lastDy = 0
          root.dragging = true; root.justDragged = true
          root.active = ""; root.modesOpen = false
        } else {
          root.dragging = false
          root.dropped(lastDx, lastDy)
          dragSettle.restart()
        }
      }
      onActiveTranslationChanged: {
        if (!active) return
        lastDx = activeTranslation.x
        lastDy = activeTranslation.y
        root.dragged(lastDx, lastDy)
      }
    }
  }

  // Grip.
  Item {
    x: root.stripX
    y: root.gripY
    width: root.stripW
    height: root.gripH
    Rectangle {
      anchors.centerIn: parent
      width: 18
      height: 3
      radius: 1.5
      color: gripHover.hovered || root.dragging ? Theme.secondary : Theme.tertiary
    }
    HoverHandler { id: gripHover; cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
  }

  // ---- Modes: the icon, and the switches that open downward under it
  Item {
    id: modesGroup
    x: 0
    y: root.modesUp ? root.modesListY : root.modesY
    z: 10                 // over the rows it drops down across
    width: root.width
    height: root.rowH + root.modesAmount * root.modesListH
    readonly property real iconY: root.modesUp ? root.modesAmount * root.modesListH : 0
    readonly property real listY: root.modesUp ? 0 : root.rowH

    HoverHandler { id: modesHover }
    Timer { id: modesOpenTimer; interval: 25; onTriggered: if (!root.dragging) { root.modesOpen = true; if (root.active.indexOf("mode:") !== 0) root.active = "" } }
    Timer { id: modesCloseTimer; interval: 160; onTriggered: root.modesOpen = false }
    Connections {
      target: modesHover
      function onHoveredChanged() {
        if (modesHover.hovered) { modesCloseTimer.stop(); modesOpenTimer.restart() }
        else { modesOpenTimer.stop(); modesCloseTimer.restart() }
      }
    }

    StripIcon {
      x: root.stripX
      y: modesGroup.iconY
      width: root.stripW
      height: root.rowH
      glyph: 0xF0521
      lit: root.modesOpen
      tint: {
        for (var i = 0; i < root.modeList.length; i++)
          if (root.modeOn(root.modeList[i].key)) return root.modeList[i].tint
        return Theme.text
      }
      blocked: root.justDragged
      onTapped: root.modesOpen = !root.modesOpen
    }

    // The switches.
    Repeater {
      model: root.modeList
      Item {
        id: modeRow
        required property var modelData
        required property int index
        x: 0
        y: modesGroup.listY + 2 + index * root.modeRowH
        width: root.width
        height: root.modeRowH
        // Each switch shows as the list opens past it.
        opacity: Math.max(0, Math.min(1, (root.modesAmount * root.modesListH - index * root.modeRowH) / root.modeRowH))
        visible: opacity > 0

        HoverGroup { anchors.fill: parent; name: "mode:" + modeRow.modelData.key; host: root }

        ModeButton {
          x: root.stripX + (root.stripW - size) / 2
          anchors.verticalCenter: parent.verticalCenter
          size: 30
          on: root.modeOn(modeRow.modelData.key)
          tint: modeRow.modelData.tint
          glyph: modeRow.modelData.key === "layout" ? root.layoutGlyph()
            : (modeRow.modelData.key === "mute" && !root.modes.muted ? 0xF057E : modeRow.modelData.glyph)
          label: modeRow.modelData.name
          blocked: root.justDragged
          onToggled: root.modeRequested(modeRow.modelData.key)
        }

        Flyout {
          z: -1
          towardLeft: root.towardLeft
          open: root.active === "mode:" + modeRow.modelData.key
          motion: root.motion
          flyWidth: 176
          flyHeight: 30
          overlap: root.overlap
          x: root.flyX(width)
          anchors.verticalCenter: parent.verticalCenter
          Row {
            anchors.verticalCenter: parent.verticalCenter
            x: root.towardLeft ? 12 : 10
            spacing: 8
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modeRow.modelData.name
              textFormat: Text.PlainText
              color: Theme.text
              font.family: P.sans
              font.pixelSize: 12
              font.weight: Font.DemiBold
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.modeState(modeRow.modelData.key)
              textFormat: Text.PlainText
              color: root.modeOn(modeRow.modelData.key) ? modeRow.modelData.tint : Theme.secondary
              font.family: P.sans
              font.pixelSize: 12
              font.weight: Font.Medium
            }
          }
        }
      }
    }
  }

  // ---- Volume
  HoverGroup {
    id: volumeGroup
    // Hidden while Modes drops down over this row.
    opacity: root.modesUp ? 1 : 1 - root.modesAmount
    x: 0
    y: root.volumeY
    width: root.width
    height: root.rowH
    name: "volume"
    host: root

    StripIcon {
      x: root.stripX
      width: root.stripW
      height: root.rowH
      glyph: root.modes.muted ? 0xF0581 : 0xF057E
      tint: root.modes.muted ? Theme.red : Theme.text
      lit: root.active === "volume"
      blocked: root.justDragged
      onTapped: root.muteRequested()
      onScrolled: function(step) { root.volumeRequested(Math.max(0, Math.min(1, root.volume + step))) }
    }
    Flyout {
      z: -1   // under the icon it slides out from
      towardLeft: root.towardLeft
      open: root.active === "volume"
      motion: root.motion
      flyWidth: 228
      flyHeight: 36
      overlap: root.overlap
      x: root.flyX(width)
      anchors.verticalCenter: parent.verticalCenter
      Row {
        anchors.centerIn: parent
        spacing: 10
        HSlider {
          anchors.verticalCenter: parent.verticalCenter
          width: 150
          value: root.volume
          dimmed: !!root.modes.muted
          glyph: root.modes.muted ? 0xF0581 : 0xF057E
          onMoved: function(v) { root.volumeRequested(v) }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: 34
          text: Math.round(root.volume * 100) + "%"
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 12
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
        }
      }
    }
  }

  // ---- Brightness
  HoverGroup {
    id: brightnessGroup
    // Hidden while Modes drops down over this row.
    opacity: root.modesUp ? 1 : 1 - root.modesAmount
    visible: root.brightnessAvailable
    x: 0
    y: root.brightnessY
    width: root.width
    height: root.rowH
    name: "brightness"
    host: root

    StripIcon {
      x: root.stripX
      width: root.stripW
      height: root.rowH
      glyph: 0xF05A8
      tint: Theme.text
      lit: root.active === "brightness"
      onScrolled: function(step) { root.brightnessRequested(Math.max(0.01, Math.min(1, root.brightness + step))) }
    }
    Flyout {
      z: -1   // under the icon it slides out from
      towardLeft: root.towardLeft
      open: root.active === "brightness"
      motion: root.motion
      flyWidth: 228
      flyHeight: 36
      overlap: root.overlap
      x: root.flyX(width)
      anchors.verticalCenter: parent.verticalCenter
      Row {
        anchors.centerIn: parent
        spacing: 10
        HSlider {
          anchors.verticalCenter: parent.verticalCenter
          width: 150
          value: root.brightness
          glyph: 0xF05A8
          onMoved: function(v) { root.brightnessRequested(Math.max(0.01, v)) }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: 34
          text: Math.round(root.brightness * 100) + "%"
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 12
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
        }
      }
    }
  }

  // ---- Usage
  HoverGroup {
    id: usageGroup
    // Hidden while Modes drops down over this row.
    opacity: root.modesUp ? 1 : 1 - root.modesAmount
    x: 0
    y: root.usageY
    width: root.width
    height: root.rowH
    name: "usage"
    host: root

    readonly property real worst: root.usage && root.usage.ready ? Math.max(root.usage.session || 0, root.usage.weekly || 0) : -1

    StripIcon {
      x: root.stripX
      width: root.stripW
      height: root.rowH
      glyph: 0xF029A
      tint: usageGroup.worst < 0 ? Theme.secondary : (usageGroup.worst >= 0.9 ? Theme.red : (usageGroup.worst >= 0.75 ? Theme.orange : Theme.green))
      lit: root.active === "usage"
    }
    Flyout {
      z: -1   // under the icon it slides out from
      towardLeft: root.towardLeft
      open: root.active === "usage"
      motion: root.motion
      flyWidth: 214
      flyHeight: 36
      overlap: root.overlap
      x: root.flyX(width)
      anchors.verticalCenter: parent.verticalCenter
      Row {
        anchors.centerIn: parent
        spacing: 14
        visible: !!(root.usage && root.usage.ready)
        UsageMeter { label: "5-hour"; percent: root.usage && root.usage.ready ? root.usage.session : 0 }
        UsageMeter { label: "This week"; percent: root.usage && root.usage.ready ? root.usage.weekly : 0 }
      }
      Text {
        anchors.centerIn: parent
        visible: !(root.usage && root.usage.ready)
        text: "No usage yet"
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
      }
    }
  }
}
