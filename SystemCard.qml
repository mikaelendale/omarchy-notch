import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// The machine at a glance: how busy the processor is, how much memory and
// disk are in use, and how warm it's running, each as a ring that closes as
// it fills (green, orange past 75%, red past 90%).
//
// system: { ready, cpu (0..1), memUsed, memTotal (bytes), diskUsed,
//           diskTotal (bytes), temp (°C, or -1), uptime (seconds) }
Rectangle {
  id: root

  property var system: ({ ready: false })
  property real motion: 1

  radius: 22
  color: Theme.card

  readonly property bool ready: !!(system && system.ready)

  function gb(bytes) {
    var g = Math.max(0, Number(bytes) || 0) / 1e9
    return (g >= 100 ? Math.round(g) : g.toFixed(1)) + " GB"
  }
  function uptime(seconds) {
    var m = Math.floor(Math.max(0, Number(seconds) || 0) / 60)
    var d = Math.floor(m / 1440), h = Math.floor((m % 1440) / 60), r = m % 60
    if (d > 0) return "Up " + d + " d " + h + " h"
    if (h > 0) return "Up " + h + " h " + r + " min"
    return "Up " + r + " min"
  }

  readonly property var dials: {
    var s = system || {}
    var list = [
      { label: "Processor", value: ready ? Math.round((s.cpu || 0) * 100) + "%" : "–", fill: s.cpu || 0, detail: "" },
      { label: "Memory", value: ready && s.memTotal > 0 ? Math.round(s.memUsed / s.memTotal * 100) + "%" : "–",
        fill: s.memTotal > 0 ? s.memUsed / s.memTotal : 0, detail: ready ? gb(s.memUsed) : "" },
      { label: "Disk", value: ready && s.diskTotal > 0 ? Math.round(s.diskUsed / s.diskTotal * 100) + "%" : "–",
        fill: s.diskTotal > 0 ? s.diskUsed / s.diskTotal : 0, detail: ready ? gb(s.diskUsed) : "" }
    ]
    if (s.temp === undefined || s.temp >= 0)
      list.push({ label: "Heat", value: ready && s.temp >= 0 ? Math.round(s.temp) + "°" : "–",
        fill: s.temp > 0 ? Math.min(1, s.temp / 100) : 0, detail: "" })
    return list
  }

  Item {
    anchors.fill: parent
    anchors.margins: 14

    Text {
      id: title
      text: "System"
      textFormat: Text.PlainText
      color: Theme.text
      font.family: P.sans
      font.pixelSize: 15
      font.weight: Font.DemiBold
    }
    Text {
      anchors.right: parent.right
      anchors.baseline: title.baseline
      visible: root.ready && root.system.uptime > 0
      text: root.uptime(root.system.uptime)
      textFormat: Text.PlainText
      color: Theme.secondary
      font.family: P.sans
      font.pixelSize: 11
    }

    Row {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Math.max(6, (parent.width - root.dials.length * 58) / Math.max(1, root.dials.length - 1))

      Repeater {
        model: root.dials
        Column {
          id: dial
          required property var modelData
          width: 58
          spacing: 3

          Item {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: 50
            height: 50
            readonly property real stroke: 4.5
            readonly property real r: (width - stroke) / 2
            readonly property real fill: Math.max(0, Math.min(1, Number(dial.modelData.fill) || 0))
            readonly property color tint: !root.ready ? Theme.tertiary
              : (fill >= 0.9 ? Theme.red : (fill >= 0.75 ? Theme.orange : Theme.green))
            Shape {
              anchors.fill: parent
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.hairline
                strokeWidth: ring.stroke
                PathAngleArc { centerX: 25; centerY: 25; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
              }
              ShapePath {
                fillColor: "transparent"
                strokeColor: ring.tint
                strokeWidth: ring.stroke
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 25; centerY: 25; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: Math.max(4, ring.fill * 360) }
              }
            }
            Text {
              anchors.centerIn: parent
              text: dial.modelData.value
              textFormat: Text.PlainText
              color: Theme.text
              font.family: P.sans
              font.pixelSize: 12
              font.weight: Font.DemiBold
              font.features: { "tnum": 1 }
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.modelData.label
            textFormat: Text.PlainText
            color: Theme.secondary
            font.family: P.sans
            font.pixelSize: 11
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.modelData.detail || " "
            textFormat: Text.PlainText
            color: Theme.tertiary
            font.family: P.sans
            font.pixelSize: 10
            font.features: { "tnum": 1 }
          }
        }
      }
    }
  }
}
