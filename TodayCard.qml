import QtQuick
import "Palette.js" as P

// Today: the month and day, and this week with today circled.
Rectangle {
  id: root

  property date now: new Date()

  radius: 22
  color: Theme.card

  readonly property var week: {
    var start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay())
    var days = []
    for (var i = 0; i < 7; i++) {
      var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
      days.push({ letter: Qt.formatDate(d, "ddd").charAt(0), day: d.getDate(), today: i === now.getDay(), weekend: i === 0 || i === 6 })
    }
    return days
  }

  Item {
    anchors.fill: parent
    anchors.margins: 14

    Row {
      spacing: 10
      Text {
        id: bigDay
        text: root.now.getDate()
        textFormat: Text.PlainText
        color: Theme.text
        font.family: P.sans
        font.pixelSize: 44
        font.weight: Font.Light
        font.features: { "tnum": 1 }
      }
      Column {
        anchors.verticalCenter: bigDay.verticalCenter
        anchors.verticalCenterOffset: 1
        spacing: 1
        Text {
          text: Qt.formatDate(root.now, "dddd")
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 15
          font.weight: Font.DemiBold
        }
        Text {
          text: Qt.formatDate(root.now, "MMMM")
          textFormat: Text.PlainText
          color: Theme.secondary
          font.family: P.sans
          font.pixelSize: 12
        }
      }
    }

    Row {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 0

      Repeater {
        model: root.week
        Column {
          id: day
          required property var modelData
          width: 24
          spacing: 5
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: day.modelData.letter
            textFormat: Text.PlainText
            color: day.modelData.today ? Theme.text : Theme.tertiary
            font.family: P.sans
            font.pixelSize: 10
            font.weight: Font.DemiBold
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            height: 22
            radius: 11
            color: day.modelData.today ? Theme.accent : "transparent"
            Text {
              anchors.centerIn: parent
              text: day.modelData.day
              textFormat: Text.PlainText
              color: day.modelData.today ? Theme.contrastOn(Theme.accent) : (day.modelData.weekend ? Theme.secondary : Theme.text)
              font.family: P.sans
              font.pixelSize: 12
              font.weight: day.modelData.today ? Font.Bold : Font.Medium
              font.features: { "tnum": 1 }
            }
          }
        }
      }
    }
  }
}
