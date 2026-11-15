import QtQuick
import "Palette.js" as P

// Notifications you've had, newest first: what Omarchy showed and keeps in
// its history, so one that came and went can still be read. As many as the
// card has room for (nothing scrolls); "Show all" brings them back up as
// Omarchy's own cards, Clear starts the list afresh.
//
// notifications: [{ key, app, glyph, summary, body, ts (seconds), live }]
Rectangle {
  id: root

  property var notifications: []
  property date now: new Date()
  property real motion: 1

  signal cleared()
  signal showAll()

  radius: 22
  color: Theme.card

  readonly property int rowHeight: 34
  readonly property real listRoom: height - 14 - header.height - 8 - 14
  readonly property int fits: Math.max(1, Math.floor(listRoom / rowHeight))
  readonly property bool overflow: notifications.length > fits
  // With more than fit, the last row says how many more.
  readonly property var shown: notifications.slice(0, overflow ? Math.max(0, fits - 1) : fits)

  function ago(ts) {
    var s = Math.max(0, (now.getTime() / 1000) - Number(ts || 0))
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    if (s < 2 * 86400) return "Yesterday"
    return Qt.formatDate(new Date(Number(ts) * 1000), "d MMM")
  }

  Item {
    anchors.fill: parent
    anchors.margins: 14

    Item {
      id: header
      width: parent.width
      height: 22
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Notifications"
        textFormat: Text.PlainText
        color: Theme.text
        font.family: P.sans
        font.pixelSize: 15
        font.weight: Font.DemiBold
      }
      Text {
        id: clearText
        objectName: "clearNotifications"
        visible: root.notifications.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Clear"
        textFormat: Text.PlainText
        color: clearHover.hovered ? Theme.text : Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
        font.weight: Font.DemiBold
        HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.cleared() }
      }
    }

    Column {
      y: header.height + 8
      width: parent.width
      spacing: 0

      Repeater {
        model: root.shown
        Item {
          id: row
          required property var modelData
          width: parent.width
          height: root.rowHeight

          // The app's own glyph, or its initial.
          Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 12
            color: Theme.cardHover
            Text {
              anchors.centerIn: parent
              text: row.modelData.glyph || (row.modelData.app ? row.modelData.app.charAt(0).toUpperCase() : "•")
              textFormat: Text.PlainText
              color: Theme.text
              font.family: row.modelData.glyph ? P.glyphs : P.sans
              font.pixelSize: row.modelData.glyph ? 13 : 11
              font.weight: Font.DemiBold
            }
          }
          Column {
            anchors.left: badge.right
            anchors.leftMargin: 9
            anchors.right: when.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
              width: parent.width
              text: row.modelData.summary || row.modelData.app || "Notification"
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: Theme.text
              font.family: P.sans
              font.pixelSize: 12
              font.weight: Font.DemiBold
            }
            Text {
              width: parent.width
              visible: text !== ""
              text: row.modelData.body || ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              maximumLineCount: 1
              color: Theme.secondary
              font.family: P.sans
              font.pixelSize: 11
            }
          }
          Text {
            id: when
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.ago(row.modelData.ts)
            textFormat: Text.PlainText
            color: Theme.tertiary
            font.family: P.sans
            font.pixelSize: 11
            font.features: { "tnum": 1 }
          }
        }
      }

      // More than fit: how many, and Omarchy's cards for all of them.
      Rectangle {
        objectName: "showAllNotifications"
        visible: root.overflow
        width: parent.width
        height: 26
        radius: 13
        color: moreHover.hovered ? Theme.cardHover : "transparent"
        Text {
          anchors.centerIn: parent
          text: (root.notifications.length - root.shown.length) + " more  ·  Show all"
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }
        HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.showAll() }
      }
    }

    // Nothing yet.
    Column {
      visible: root.notifications.length === 0
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 10
      spacing: 6
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: String.fromCodePoint(0xF009C)
        textFormat: Text.PlainText
        color: Theme.tertiary
        font.family: P.glyphs
        font.pixelSize: 22
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No notifications"
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
      }
    }
  }
}
