import QtQuick
import "Palette.js" as P

// One item in the editor: its real icon, drawn live, and its name. A button
// of the open notch has only its name; a card of the open notch is a small
// tile. While it's being dragged, the slot it would drop into shows as a faint
// outline; clicked (picked up, to click where it goes), it's ringed.
Rectangle {
  id: root

  property string chipId: ""
  property string kind: "item"         // "item" | "card" | "button"
  property string label: ""
  property bool picked: false
  // Reached with the arrow keys.
  property bool focused: false
  // A card of the open notch: a tile with its glyph over its name.
  readonly property bool tile: kind === "card"
  property bool showIcon: true
  property bool placeholder: false
  property bool hovered: false
  // On a corner or the notch: the item exactly as the bar draws it, no name
  // (it shows on hover). In a corner, music shows its title too.
  property bool compact: false
  property bool wide: false
  // For the live icon.
  property var status: ({})
  property var media: ({ available: false })
  property date now: new Date()
  property string clockFormat: "h:mm AP"
  property var lead: ({ agent: "claude", state: "idle" })
  property real motion: 1

  implicitWidth: tile ? 96 : row.implicitWidth + (compact ? 18 : 22)
  implicitHeight: tile ? 58 : 32
  width: implicitWidth
  height: implicitHeight
  radius: tile ? 16 : height / 2
  color: placeholder ? "transparent" : (hovered || picked || focused ? Theme.cardHover : Theme.card)
  border.width: picked ? 2 : (placeholder || focused ? 1 : 0)
  border.color: picked || focused ? Theme.text : Theme.secondary
  Behavior on color { ColorAnimation { duration: 90 * root.motion } }

  // A card's tile.
  Column {
    visible: root.tile
    anchors.centerIn: parent
    spacing: 4
    opacity: root.placeholder ? 0.35 : 1
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 22
      height: 20
      AgentMark {
        visible: root.chipId === "agents"
        anchors.centerIn: parent
        size: 18
        agent: root.lead && root.lead.agent ? root.lead.agent : "claude"
        motion: root.motion
      }
      Text {
        visible: root.chipId !== "agents"
        anchors.centerIn: parent
        text: root.chipId === "today" ? String(root.now.getDate())
          : String.fromCodePoint(root.chipId === "system" ? 0xF035B : (root.chipId === "notifications" ? 0xF009A : 0xF075A))
        textFormat: Text.PlainText
        color: Theme.text
        font.family: root.chipId === "today" ? P.sans : P.glyphs
        font.pixelSize: root.chipId === "today" ? 17 : 18
        font.weight: root.chipId === "today" ? Font.DemiBold : Font.Normal
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 11
      font.weight: Font.DemiBold
    }
  }

  Row {
    id: row
    visible: !root.tile
    anchors.centerIn: parent
    spacing: 8
    opacity: root.placeholder ? 0.35 : 1

    StatusItem {
      visible: root.showIcon
      anchors.verticalCenter: parent.verticalCenter
      itemId: root.showIcon && (root.compact || (root.chipId !== "clock" && root.chipId !== "date" && root.chipId !== "speed")) ? root.chipId : ""
      always: true
      wide: root.wide
      status: root.status
      media: root.media
      now: root.now
      clockFormat: root.clockFormat
      lead: root.lead
      motion: root.motion
    }
    // Time, date and speed are words already; a glyph stands in for them.
    Text {
      visible: root.showIcon && !root.compact && (root.chipId === "clock" || root.chipId === "date" || root.chipId === "speed")
      anchors.verticalCenter: parent.verticalCenter
      text: String.fromCodePoint(root.chipId === "speed" ? 0xF04C5 : (root.chipId === "clock" ? 0xF0954 : 0xF00ED))
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.glyphs
      font.pixelSize: 15
    }
    Text {
      visible: !root.compact
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 12
      font.weight: Font.DemiBold
    }
  }
}
