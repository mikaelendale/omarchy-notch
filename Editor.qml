import QtQuick
import "Layout.js" as Layout
import "Palette.js" as P

// The top bar's editor: what the two corners and the closed notch show, the
// open notch's cards and the order of its buttons, and how it all looks
// (frosted or solid, full screen or not). Drag an item where you want it, or
// click it and then click where it goes; changes apply as they land.
// Right-click the notch or a corner to open it, or run `notch-look edit`.
//
// Pure QtQuick: the bar hosts it in a window, and the tests render it off
// screen with made-up data.
Item {
  id: root

  property var layout: Layout.defaults()
  // The open notch's buttons (Omarchy's widgets), in order: [{ id, name }].
  property var buttons: []
  property string glass: "frosted"          // "frosted" | "solid"
  property bool floating: false              // the notch and corners float below the edge
  // Every screen ([{ id, name }]), and the one the corners show on ("" = all).
  property var screens: []
  property string cornerScreen: ""
  property bool fullScreen: false
  // For the items' live icons.
  property var status: ({})
  property var media: ({ available: false })
  property date now: new Date()
  property string clockFormat: "h:mm AP"
  property var lead: ({ agent: "claude", state: "idle" })
  property real motion: 1

  signal edited(var layout)
  // A button moved to `index` in the row (counted without it).
  signal buttonMoved(string id, int index)
  signal glassRequested(string glass)
  signal floatingRequested(bool on)
  signal cornerScreenRequested(string name)
  signal fullScreenRequested(bool on)
  signal closeRequested()

  width: 920
  height: card.height

  function log(text) { console.log("mike.notch editor: " + text) }

  // ---- moving things: by dragging, or by clicking one and then a place
  property string dragId: ""
  property string dragKind: ""             // "item" | "card" | "button"
  property point dragPoint: Qt.point(0, 0)
  property var preview: null                // the layout as it would drop
  property int buttonIndex: -1              // where a button would drop
  property string targetZone: ""
  property string pickedId: ""
  property string pickedKind: ""

  readonly property var base: Layout.normalize(layout)
  readonly property var shown: (dragKind === "item" || dragKind === "card") && preview ? preview : base
  readonly property var unused: Layout.unused(shown)
  readonly property var unusedCards: Layout.unusedCards(shown)
  readonly property var shownButtons: {
    var list = (buttons || []).slice()
    if (dragKind !== "button" || buttonIndex < 0) return list
    var from = -1
    for (var i = 0; i < list.length; i++) if (list[i].id === dragId) from = i
    if (from < 0) return list
    var item = list.splice(from, 1)[0]
    list.splice(Math.min(buttonIndex, list.length), 0, item)
    return list
  }

  // Every chip on screen, for finding the one under the pointer.
  function chips() {
    var out = []
    var reps = [leftChips, centerChips, rightChips, moreChips, cardChips, moreCardChips, buttonChips]
    for (var r = 0; r < reps.length; r++)
      for (var i = 0; i < reps[r].count; i++) {
        var c = reps[r].itemAt(i)
        if (c) out.push(c)
      }
    return out
  }
  function chipAt(p) {
    var list = chips()
    for (var i = 0; i < list.length; i++) {
      var c = list[i]
      var q = c.mapFromItem(root, p.x, p.y)
      if (q.x >= 0 && q.y >= 0 && q.x <= c.width && q.y <= c.height) return c
    }
    return null
  }
  function inside(item, p, margin) {
    if (!item || !item.visible) return false
    var q = item.mapFromItem(root, p.x, p.y)
    return q.x >= -margin && q.y >= -margin && q.x <= item.width + margin && q.y <= item.height + margin
  }
  // The place under the pointer for a thing of this kind.
  function zoneAt(kind, p) {
    if (kind === "item") {
      if (inside(leftZone, p, 14)) return "left"
      if (inside(rightZone, p, 14)) return "right"
      if (inside(centerZone, p, 14)) return "center"
      if (inside(moreZone, p, 8)) return "more"
    } else if (kind === "card") {
      if (inside(cardZone, p, 14)) return "cards"
      if (inside(moreCardZone, p, 14)) return "moreCards"
    } else if (kind === "button") {
      if (inside(buttonZone, p, 24)) return "buttons"
    }
    return ""
  }
  // How many of the place's other chips come before the pointer, reading
  // left to right, row by row.
  function indexIn(repeater, p, skip) {
    var n = 0
    for (var i = 0; i < repeater.count; i++) {
      var c = repeater.itemAt(i)
      if (!c || c.chipId === skip) continue
      var q = c.mapToItem(root, c.width / 2, c.height / 2)
      if (p.y > q.y + c.height / 2 || (Math.abs(p.y - q.y) <= c.height / 2 && p.x > q.x)) n++
    }
    return n
  }
  // The layout with `id` put where the pointer is; null if that's no place
  // for it.
  function placed(kind, id, p) {
    var zone = zoneAt(kind, p)
    if (kind === "item") {
      if (zone === "left" || zone === "center" || zone === "right") {
        var rep = zone === "left" ? leftChips : zone === "center" ? centerChips : rightChips
        return Layout.moved(base, id, zone, indexIn(rep, p, id))
      }
      if (zone === "more") return Layout.moved(base, id, "", 0)
    } else if (kind === "card") {
      if (zone === "cards") return Layout.movedCard(base, id, indexIn(cardChips, p, id))
      if (zone === "moreCards") return Layout.movedCard(base, id, -1)
    }
    return null
  }
  function updateDrag() {
    var p = dragPoint
    targetZone = zoneAt(dragKind, p)
    if (dragKind === "item" || dragKind === "card") preview = placed(dragKind, dragId, p) || base
    else if (dragKind === "button") buttonIndex = targetZone ? indexIn(buttonChips, p, dragId) : -1
  }
  function buttonFrom(id) {
    for (var i = 0; i < buttons.length; i++) if (buttons[i].id === id) return i
    return -1
  }
  function commitButton(id, index) {
    var from = buttonFrom(id)
    if (from >= 0 && index >= 0 && from !== index) {
      log("button " + id + " to " + index)
      root.buttonMoved(id, index)
    }
  }
  function endDrag() {
    if ((dragKind === "item" || dragKind === "card") && preview && !Layout.same(preview, layout)) {
      log("dropped " + dragId + " in " + targetZone)
      root.edited(preview)
    } else if (dragKind === "button" && buttonIndex >= 0) {
      commitButton(dragId, buttonIndex)
    } else {
      log("dropped " + dragId + " where it was")
    }
    dragId = ""
    dragKind = ""
    preview = null
    buttonIndex = -1
    targetZone = ""
  }
  function pick(chip) {
    pickedId = chip ? chip.chipId : ""
    pickedKind = chip ? chip.kind : ""
    if (chip) log("picked " + chip.kind + " " + chip.chipId)
  }
  // A click (no drag): pick a thing up, or put the picked one where it lands.
  function clicked(p, chip) {
    if (pickedId) {
      if (chip && chip.chipId === pickedId && chip.kind === pickedKind) { pick(null); return }
      if (pickedKind === "button") {
        if (zoneAt("button", p)) { commitButton(pickedId, indexIn(buttonChips, p, pickedId)); pick(null); return }
      } else {
        var next = placed(pickedKind, pickedId, p)
        if (next) {
          if (!Layout.same(next, layout)) { log("moved " + pickedId + " to " + zoneAt(pickedKind, p)); root.edited(next) }
          pick(null)
          return
        }
      }
    }
    pick(chip)
  }

  // ---- the keyboard: the arrows move a ring from chip to chip; Enter picks
  // the ringed one up; picked up, the arrows move it along (across places at
  // the ends), Down takes it off, Up puts it back; Enter or Esc puts it down.
  property string focusKey: ""
  function keyOf(c) { return c ? c.kind + ":" + c.chipId : "" }
  function chipFor(key) {
    var list = chips()
    for (var i = 0; i < list.length; i++) if (keyOf(list[i]) === key) return list[i]
    return null
  }
  function stepFocus(delta) {
    var list = chips()
    if (list.length === 0) return
    var at = -1
    for (var i = 0; i < list.length; i++) if (keyOf(list[i]) === focusKey) at = i
    var next = at < 0 ? 0 : Math.max(0, Math.min(list.length - 1, at + delta))
    focusKey = keyOf(list[next])
  }
  function zoneOf(id) {
    var zs = ["left", "center", "right"]
    for (var z = 0; z < zs.length; z++) if (base[zs[z]].indexOf(id) !== -1) return zs[z]
    return "more"
  }
  // Move the picked thing one step along (delta ±1), or off (Down) and back (Up).
  function nudge(delta, vertical) {
    var id = pickedId, kind = pickedKind, next = null
    if (kind === "item") {
      var zones = ["left", "center", "right", "more"]
      var zone = zoneOf(id)
      if (vertical) {
        if (delta > 0 && zone !== "more") next = Layout.moved(base, id, "", 0)
        else if (delta < 0 && zone === "more") next = Layout.moved(base, id, "center", base.center.length)
      } else if (zone === "more") {
        if (delta < 0) next = Layout.moved(base, id, "right", base.right.length)
      } else {
        var list = base[zone]
        var at = list.indexOf(id) + delta
        if (at >= 0 && at < list.length) next = Layout.moved(base, id, zone, at)
        else {
          var z = zones[zones.indexOf(zone) + (delta > 0 ? 1 : -1)]
          if (z === "more") next = Layout.moved(base, id, "", 0)
          else if (z) next = Layout.moved(base, id, z, delta > 0 ? 0 : base[z].length)
        }
      }
    } else if (kind === "card") {
      var cards = base.cards
      var pos = cards.indexOf(id)
      if (vertical) next = delta > 0 ? (pos >= 0 ? Layout.movedCard(base, id, -1) : null) : (pos < 0 ? Layout.movedCard(base, id, cards.length) : null)
      else if (pos < 0) { if (delta < 0) next = Layout.movedCard(base, id, cards.length) }
      else if (pos + delta >= cards.length) next = Layout.movedCard(base, id, -1)
      else if (pos + delta >= 0) next = Layout.movedCard(base, id, pos + delta)
    } else if (kind === "button" && !vertical) {
      var from = buttonFrom(id)
      var to = from + delta
      if (from >= 0 && to >= 0 && to < buttons.length) commitButton(id, to)
      return
    }
    if (next && !Layout.same(next, layout)) { log("moved " + id + " with the keyboard"); root.edited(next) }
  }

  focus: true
  Keys.onPressed: function(event) {
    var horizontal = event.key === Qt.Key_Left ? -1 : (event.key === Qt.Key_Right ? 1 : 0)
    var vertical = event.key === Qt.Key_Up ? -1 : (event.key === Qt.Key_Down ? 1 : 0)
    if (event.key === Qt.Key_Escape) {
      if (root.dragId) root.endDrag()
      else if (root.pickedId) root.pick(null)
      else root.closeRequested()
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      if (root.pickedId) root.pick(null)
      else if (root.focusKey) { var c = root.chipFor(root.focusKey); if (c) root.pick(c) }
      else root.stepFocus(0)
    } else if (horizontal || vertical) {
      if (root.pickedId) {
        root.nudge(horizontal || vertical, vertical !== 0)
        root.focusKey = root.pickedKind + ":" + root.pickedId
      } else {
        // Up and down jump a whole row of chips.
        root.stepFocus(horizontal ? horizontal : vertical * 4)
      }
    } else {
      return
    }
    event.accepted = true
  }

  // ---- the card
  Rectangle {
    id: card
    width: root.width
    height: content.implicitHeight + 22 + 36 + 52
    radius: 30
    color: Theme.body
    border.width: 1
    border.color: Theme.edge
  }

  Column {
    id: content
    x: 28
    y: 26
    width: root.width - 56
    spacing: 0

    // ---- heading
    Item {
      width: parent.width
      height: 48
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Text {
          text: "Customize the top bar"
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 20
          font.weight: Font.DemiBold
        }
        Text {
          text: root.pickedId ? "Now click where it goes. Esc puts it down."
            : "Drag an item where you want it, or click it and then where it goes. Arrows and Enter work too."
          textFormat: Text.PlainText
          color: Theme.secondary
          font.family: P.sans
          font.pixelSize: 12
        }
      }
    }

    Item { width: 1; height: 20 }

    // ---- the top of the screen, in small: both corners and the notch
    Rectangle {
      id: stage
      width: parent.width
      height: labelY + 30
      radius: 18
      // A stand-in for the screen: shifted away from the theme's background,
      // so the corners and the notch (in the theme's own colour) stand out.
      color: Theme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
      clip: true

      // Three columns, so the corners and the notch never run into each other.
      readonly property real column: (width - 2 * 24) / 3
      readonly property real maxEar: column - 44
      readonly property real maxNotch: column - 56
      readonly property real labelY: Math.max(leftZone.height, centerZone.height, rightZone.height) + 10

      Zone {
        id: leftZone
        kind: "ear"
        x: 0
        targeted: root.targetZone === "left" || (root.pickedKind === "item" && pointer.overZone === "left")
        flowWidth: Math.max(110, Math.min(stage.maxEar, leftFlow.implicitW))
        contentHeight: leftFlow.height
        Flow {
          id: leftFlow
          readonly property real implicitW: root.flowWidth(leftChips)
          x: 16
          y: 12
          width: leftZone.flowWidth
          spacing: 6
          Repeater { id: leftChips; model: root.shown.left; delegate: cornerChip }
        }
      }
      Zone {
        id: centerZone
        kind: "notch"
        anchors.horizontalCenter: parent.horizontalCenter
        targeted: root.targetZone === "center" || (root.pickedKind === "item" && pointer.overZone === "center")
        flowWidth: Math.max(130, Math.min(stage.maxNotch, centerFlow.implicitW))
        contentHeight: centerFlow.height
        Flow {
          id: centerFlow
          readonly property real implicitW: root.flowWidth(centerChips)
          x: centerZone.flare + 16
          y: 12
          width: centerZone.flowWidth
          spacing: 6
          Repeater { id: centerChips; model: root.shown.center; delegate: notchChip }
        }
      }
      Zone {
        id: rightZone
        kind: "ear"
        mirrored: true
        x: stage.width - width
        targeted: root.targetZone === "right" || (root.pickedKind === "item" && pointer.overZone === "right")
        flowWidth: Math.max(110, Math.min(stage.maxEar, rightFlow.implicitW))
        contentHeight: rightFlow.height
        Flow {
          id: rightFlow
          readonly property real implicitW: root.flowWidth(rightChips)
          x: rightZone.width - width - 16
          y: 12
          width: rightZone.flowWidth
          spacing: 6
          Repeater { id: rightChips; model: root.shown.right; delegate: cornerChip }
        }
      }

      // What each place is, under it.
      Repeater {
        model: [
          { name: "Left corner", align: "left" },
          { name: "Notch", align: "center" },
          { name: "Right corner", align: "right" }
        ]
        Text {
          required property var modelData
          y: stage.labelY
          x: modelData.align === "left" ? 16
            : modelData.align === "right" ? stage.width - width - 16
            : (stage.width - width) / 2
          text: modelData.name
          textFormat: Text.PlainText
          color: Theme.tertiary
          font.family: P.sans
          font.pixelSize: 11
          font.weight: Font.DemiBold
        }
      }
    }

    // ---- which screens get the corners (with more than one)
    Item { width: 1; height: root.screens.length > 1 ? 10 : 0 }
    Row {
      visible: root.screens.length > 1
      height: visible ? 36 : 0
      spacing: 12
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Corners show on"
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
        font.weight: Font.DemiBold
      }
      Segmented {
        anchors.verticalCenter: parent.verticalCenter
        options: [{ id: "", name: "Every screen" }].concat(root.screens)
        current: root.cornerScreen
        onPicked: function(id) { root.log("corners on " + (id || "every screen")); root.cornerScreenRequested(id) }
      }
    }

    Item { width: 1; height: 12 }

    // ---- items not on the bar
    Rectangle {
      id: moreZone
      width: parent.width
      height: Math.max(52, moreFlow.height + 20)
      radius: 18
      color: Theme.card
      border.width: root.targetZone === "more" || (root.pickedKind === "item" && pointer.overZone === "more") ? 1 : 0
      border.color: Theme.secondary
      Text {
        id: moreLabel
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "Not shown"
        textFormat: Text.PlainText
        color: Theme.tertiary
        font.family: P.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
      }
      Flow {
        id: moreFlow
        x: moreLabel.x + moreLabel.width + 14
        y: 10
        width: parent.width - x - 10
        spacing: 6
        Repeater { id: moreChips; model: root.unused; delegate: shelfChip }
      }
      Text {
        visible: root.unused.length === 0
        x: moreFlow.x
        anchors.verticalCenter: parent.verticalCenter
        text: "Everything is on the bar"
        textFormat: Text.PlainText
        color: Theme.tertiary
        font.family: P.sans
        font.pixelSize: 12
      }
    }

    Item { width: 1; height: 26 }

    // ---- the open notch: its cards
    Text {
      text: "Open notch"
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 13
      font.weight: Font.DemiBold
    }
    Item { width: 1; height: 10 }
    Rectangle {
      width: parent.width
      height: 98
      radius: 18
      color: Theme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
      clip: true

      // The open notch, in small, holding its cards in order.
      Item {
        id: cardZone
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(260, cardFlow.implicitW + 32) + 24
        height: 86
        readonly property bool targeted: root.targetZone === "cards" || (root.pickedKind === "card" && pointer.overZone === "cards")
        NotchShape {
          bodyWidth: parent.width - 24
          bodyHeight: parent.height
          radius: 24
          flare: 12
          color: Theme.bodySolid
          edgeColor: cardZone.targeted ? Theme.secondary : Theme.edge
        }
        Row {
          id: cardFlow
          readonly property real implicitW: root.shown.cards.length > 0 ? root.shown.cards.length * 96 + (root.shown.cards.length - 1) * 6 : 0
          anchors.horizontalCenter: parent.horizontalCenter
          y: 14
          spacing: 6
          Repeater { id: cardChips; model: root.shown.cards; delegate: cardTile }
        }
        Text {
          visible: root.shown.cards.length === 0
          anchors.centerIn: parent
          text: "No cards"
          textFormat: Text.PlainText
          color: Theme.tertiary
          font.family: P.sans
          font.pixelSize: 12
        }
      }
      // Cards that aren't in it.
      Item {
        id: moreCardZone
        visible: root.unusedCards.length > 0 || root.dragKind === "card" || root.pickedKind === "card"
        anchors.right: parent.right
        anchors.rightMargin: 12
        width: Math.max(110, moreCardRow.width + 16)
        height: 86
        y: 6
        readonly property bool targeted: root.targetZone === "moreCards" || (root.pickedKind === "card" && pointer.overZone === "moreCards")
        Rectangle {
          anchors.fill: parent
          radius: 16
          color: "transparent"
          border.width: moreCardZone.targeted ? 1 : 0
          border.color: Theme.secondary
        }
        Text {
          x: 8
          y: 2
          text: "Not shown"
          textFormat: Text.PlainText
          color: Theme.tertiary
          font.family: P.sans
          font.pixelSize: 11
          font.weight: Font.DemiBold
        }
        Row {
          id: moreCardRow
          x: 8
          y: 20
          spacing: 6
          Repeater { id: moreCardChips; model: root.unusedCards; delegate: cardTile }
        }
      }
    }

    // ---- the open notch's buttons
    Item { width: 1; height: root.buttons.length > 0 ? 12 : 0 }
    Rectangle {
      id: buttonZone
      visible: root.buttons.length > 0
      width: parent.width
      height: visible ? buttonFlow.height + 20 : 0
      radius: 18
      color: Theme.card
      border.width: root.dragKind === "button" || (root.pickedKind === "button" && pointer.overZone === "buttons") ? 1 : 0
      border.color: Theme.secondary
      Text {
        id: buttonLabel
        x: 16
        y: 18
        text: "Buttons"
        textFormat: Text.PlainText
        color: Theme.tertiary
        font.family: P.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
      }
      Flow {
        id: buttonFlow
        x: moreFlow.x
        y: 10
        width: parent.width - x - 10
        spacing: 6
        Repeater {
          id: buttonChips
          model: root.shownButtons
          EditorChip {
            required property var modelData
            chipId: modelData.id
            kind: "button"
            label: modelData.name
            showIcon: false
            placeholder: root.dragKind === "button" && root.dragId === modelData.id
            picked: root.pickedKind === "button" && root.pickedId === modelData.id
            focused: root.focusKey === "button:" + modelData.id
            hovered: pointer.hoverId === modelData.id
            motion: root.motion
          }
        }
      }
    }
  }

  // ---- look, reset and done (above the pointer area, so they keep their
  // own clicks and hover)
  Item {
    id: footer
    z: 2
    x: content.x
    y: content.y + content.implicitHeight + 22
    width: content.width
    height: 36

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 18

      // Frosted or solid; attached to the top edge or floating below it.
      Segmented {
        options: [{ id: "frosted", name: "Frosted" }, { id: "solid", name: "Solid" }]
        current: root.glass
        onPicked: function(id) { root.log("look " + id); root.glassRequested(id) }
      }
      Segmented {
        options: [{ id: "attached", name: "Attached" }, { id: "floating", name: "Floating" }]
        current: root.floating ? "floating" : "attached"
        onPicked: function(id) { root.log("notch " + id); root.floatingRequested(id === "floating") }
      }

      // Full screen: windows under the notch, the corners hidden.
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Rectangle {
          id: fullSwitch
          objectName: "fullScreenSwitch"
          anchors.verticalCenter: parent.verticalCenter
          width: 40
          height: 24
          radius: 12
          color: root.fullScreen ? Theme.green : Theme.cardHover
          Behavior on color { ColorAnimation { duration: 120 * root.motion } }
          Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 3
            x: root.fullScreen ? parent.width - width - 3 : 3
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 140 * root.motion; easing.type: Easing.OutCubic } }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.log("full screen " + !root.fullScreen); root.fullScreenRequested(!root.fullScreen) }
          }
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1
          Text {
            text: "Full screen"
            textFormat: Text.PlainText
            color: Theme.text
            font.family: P.sans
            font.pixelSize: 12
            font.weight: Font.DemiBold
          }
          Text {
            text: root.glass === "solid" ? "Windows go under the notch; the corners hide"
              : "Windows go under the notch, which fades while idle"
            textFormat: Text.PlainText
            color: Theme.secondary
            font.family: P.sans
            font.pixelSize: 11
          }
        }
      }
    }

    PillButton {
      objectName: "resetButton"
      anchors.right: done.left
      anchors.rightMargin: 8
      label: "Reset"
      onClicked: { root.log("reset"); root.edited(Layout.defaults()) }
    }
    PillButton {
      id: done
      objectName: "doneButton"
      anchors.right: parent.right
      label: "Done"
      primary: true
      onClicked: root.closeRequested()
    }
  }

  // Bumped whenever a chip on a corner or the notch changes width (a battery
  // starts charging, a title changes), so the places re-measure their chips.
  property int chipRevision: 0
  function flowWidth(repeater) {
    var revision = chipRevision
    var w = 0
    for (var i = 0; i < repeater.count; i++) {
      var c = repeater.itemAt(i)
      if (c) w += c.implicitWidth + (i > 0 ? 6 : 0)
    }
    return w
  }

  Component {
    id: cornerChip
    EditorChip {
      required property string modelData
      chipId: modelData
      label: Layout.names[modelData] || modelData
      compact: true
      wide: true
      onImplicitWidthChanged: root.chipRevision++
      Component.onCompleted: root.chipRevision++
      Component.onDestruction: root.chipRevision++
      placeholder: root.dragKind === "item" && root.dragId === modelData
      picked: root.pickedKind === "item" && root.pickedId === modelData
      focused: root.focusKey === "item:" + modelData
      hovered: pointer.hoverId === modelData
      status: root.status
      media: root.media
      now: root.now
      clockFormat: root.clockFormat
      lead: root.lead
      motion: root.motion
    }
  }
  Component {
    id: notchChip
    EditorChip {
      required property string modelData
      chipId: modelData
      label: Layout.names[modelData] || modelData
      compact: true
      onImplicitWidthChanged: root.chipRevision++
      Component.onCompleted: root.chipRevision++
      Component.onDestruction: root.chipRevision++
      placeholder: root.dragKind === "item" && root.dragId === modelData
      picked: root.pickedKind === "item" && root.pickedId === modelData
      focused: root.focusKey === "item:" + modelData
      hovered: pointer.hoverId === modelData
      status: root.status
      media: root.media
      now: root.now
      clockFormat: root.clockFormat
      lead: root.lead
      motion: root.motion
    }
  }
  Component {
    id: shelfChip
    EditorChip {
      required property string modelData
      chipId: modelData
      label: Layout.names[modelData] || modelData
      placeholder: root.dragKind === "item" && root.dragId === modelData
      picked: root.pickedKind === "item" && root.pickedId === modelData
      focused: root.focusKey === "item:" + modelData
      hovered: pointer.hoverId === modelData
      status: root.status
      media: root.media
      now: root.now
      clockFormat: root.clockFormat
      lead: root.lead
      motion: root.motion
    }
  }
  Component {
    id: cardTile
    EditorChip {
      required property string modelData
      chipId: modelData
      kind: "card"
      label: Layout.cardNames[modelData] || modelData
      placeholder: root.dragKind === "card" && root.dragId === modelData
      picked: root.pickedKind === "card" && root.pickedId === modelData
      focused: root.focusKey === "card:" + modelData
      hovered: pointer.hoverId === "card:" + modelData
      now: root.now
      lead: root.lead
      motion: root.motion
    }
  }

  // A compact chip's name, under it while the pointer is on it.
  Rectangle {
    id: nameTip
    z: 4
    readonly property var chip: {
      if (root.dragId || !pointer.hoverId) return null
      var list = root.chips()
      for (var i = 0; i < list.length; i++) if (list[i].chipId === pointer.hoverId && list[i].compact) return list[i]
      return null
    }
    readonly property point at: chip ? chip.mapToItem(root, chip.width / 2, chip.height) : Qt.point(0, 0)
    visible: !!chip
    x: at.x - width / 2
    y: at.y + 6
    width: tipText.implicitWidth + 16
    height: 22
    radius: 11
    color: Theme.bodySolid
    border.width: 1
    border.color: Theme.edge
    Text {
      id: tipText
      anchors.centerIn: parent
      text: nameTip.chip ? nameTip.chip.label : ""
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 11
      font.weight: Font.DemiBold
    }
  }

  // ---- the pointer: one area over the whole card, so a chip can move from
  // one place to another mid-drag without losing hold of it, and a click can
  // pick a chip up and then put it down somewhere else.
  MouseArea {
    id: pointer
    anchors.fill: parent
    z: 1
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    property string hoverId: ""
    property string overZone: ""
    property var pressedChip: null
    property bool pressing: false
    property point pressAt: Qt.point(0, 0)
    cursorShape: root.dragId ? Qt.ClosedHandCursor
      : (hoverId ? Qt.OpenHandCursor : (root.pickedId && overZone ? Qt.PointingHandCursor : Qt.ArrowCursor))

    function keyOf(c) { return c ? (c.kind === "card" ? "card:" + c.chipId : c.chipId) : "" }

    onPositionChanged: function(mouse) {
      var p = Qt.point(mouse.x, mouse.y)
      if (root.dragId) {
        root.dragPoint = p
        root.updateDrag()
        return
      }
      if (pressing && pressedChip && Math.hypot(p.x - pressAt.x, p.y - pressAt.y) > 4) {
        root.pick(null)
        root.dragKind = pressedChip.kind
        root.dragId = pressedChip.chipId
        root.dragPoint = p
        root.log("dragging " + root.dragKind + " " + root.dragId)
        root.updateDrag()
        return
      }
      var c = root.chipAt(p)
      hoverId = keyOf(c)
      overZone = root.pickedId ? root.zoneAt(root.pickedKind, p) : ""
    }
    onPressed: function(mouse) {
      pressing = true
      pressAt = Qt.point(mouse.x, mouse.y)
      pressedChip = root.chipAt(pressAt)
    }
    onReleased: function(mouse) {
      var wasDragging = !!root.dragId
      if (wasDragging) root.endDrag()
      else if (pressing) root.clicked(Qt.point(mouse.x, mouse.y), pressedChip)
      pressing = false
      pressedChip = null
    }
    onCanceled: {
      pressing = false
      pressedChip = null
      if (root.dragId) root.endDrag()
    }
    onExited: { hoverId = ""; overZone = "" }
  }

  // The chip under the pointer while dragging.
  EditorChip {
    id: ghost
    z: 3
    visible: root.dragId !== ""
    chipId: root.dragId
    kind: root.dragKind || "item"
    showIcon: root.dragKind === "item"
    label: {
      if (root.dragKind === "item") return Layout.names[root.dragId] || root.dragId
      if (root.dragKind === "card") return Layout.cardNames[root.dragId] || root.dragId
      for (var i = 0; i < root.buttons.length; i++) if (root.buttons[i].id === root.dragId) return root.buttons[i].name
      return root.dragId
    }
    x: root.dragPoint.x - width / 2
    y: root.dragPoint.y - height / 2
    hovered: true
    status: root.status
    media: root.media
    now: root.now
    clockFormat: root.clockFormat
    lead: root.lead
    motion: root.motion
  }

  // ---- pieces
  // Two or more choices in one pill; the chosen one filled.
  component Segmented: Rectangle {
    id: seg
    property var options: []          // [{ id, name }]
    property string current: ""
    signal picked(string id)
    width: segRow.width + 6
    height: 36
    radius: 18
    color: Theme.card
    Row {
      id: segRow
      x: 3
      anchors.verticalCenter: parent.verticalCenter
      Repeater {
        model: seg.options
        Rectangle {
          id: segOption
          required property var modelData
          readonly property bool on: seg.current === modelData.id
          width: segText.implicitWidth + 28
          height: 30
          radius: 15
          color: on ? Theme.text : (segArea.containsMouse ? Theme.cardHover : "transparent")
          Text {
            id: segText
            anchors.centerIn: parent
            text: segOption.modelData.name
            textFormat: Text.PlainText
            color: segOption.on ? Theme.onText : Theme.text
            font.family: P.sans
            font.pixelSize: 12
            font.weight: Font.DemiBold
          }
          MouseArea {
            id: segArea
            objectName: "option-" + segOption.modelData.id
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!segOption.on) seg.picked(segOption.modelData.id)
          }
        }
      }
    }
  }

  component PillButton: Rectangle {
    id: button
    property string label: ""
    property bool primary: false
    signal clicked()
    width: buttonText.implicitWidth + 32
    height: 36
    radius: 18
    color: primary ? Theme.text : (buttonArea.containsMouse ? Theme.cardHover : Theme.card)
    opacity: primary && buttonArea.containsMouse ? 0.9 : 1
    Text {
      id: buttonText
      anchors.centerIn: parent
      text: button.label
      textFormat: Text.PlainText
      color: button.primary ? Theme.onText : Theme.text
      font.family: P.sans
      font.pixelSize: 13
      font.weight: Font.DemiBold
    }
    MouseArea {
      id: buttonArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  // A corner or the notch, drawn as itself, holding its chips.
  component Zone: Item {
    id: zone
    property string kind: "ear"      // "ear" | "notch"
    property bool mirrored: false
    property bool targeted: false
    property real flowWidth: 140
    property real contentHeight: 32
    readonly property real flare: 12
    readonly property real bodyHeight: Math.max(56, contentHeight + 24)
    readonly property real bodyWidth: flowWidth + 32
    width: kind === "ear" ? bodyWidth + flare : bodyWidth + 2 * flare
    height: bodyHeight + flare

    EarShape {
      visible: zone.kind === "ear"
      color: Theme.bodySolid
      mirrored: zone.mirrored
      bodyWidth: zone.bodyWidth
      bodyHeight: zone.bodyHeight
      radius: 24
      flare: zone.flare
      edgeColor: zone.targeted ? Theme.secondary : Theme.edge
    }
    NotchShape {
      visible: zone.kind === "notch"
      color: Theme.bodySolid
      bodyWidth: zone.bodyWidth
      bodyHeight: zone.bodyHeight
      radius: 24
      flare: zone.flare
      edgeColor: zone.targeted ? Theme.secondary : Theme.edge
    }
  }
}
