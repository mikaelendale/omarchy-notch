import QtQuick
import "Palette.js" as P

// One coding-agent session: its agent's mark (uncovering itself while it
// works, yellow when it needs you), its name, and the state in words. Click to
// go to its window.
Rectangle {
  id: root

  property var session: ({})
  signal requested()

  readonly property string state: String(session && session.state || "idle")

  function stateColor(state) {
    if (state === "needs") return Theme.yellow
    if (state === "done") return Theme.green
    if (state === "working") return Theme.orange
    if (state === "watching") return Theme.teal
    return Theme.tertiary
  }
  function stateWord(state) {
    if (state === "needs") return "needs you"
    if (state === "done") return "your turn"
    if (state === "working") return "working"
    if (state === "watching") return "watching"
    return "idle"
  }

  height: 24
  radius: 8
  color: hover.hovered ? Theme.cardHover : "transparent"
  Behavior on color { ColorAnimation { duration: 100 } }

  AgentMark {
    id: dot
    x: 4
    anchors.verticalCenter: parent.verticalCenter
    size: 13
    agent: root.session && root.session.agent ? root.session.agent : "claude"
    working: root.state === "working" || root.state === "watching"
    needs: root.state === "needs"
  }
  Text {
    anchors.left: dot.right
    anchors.leftMargin: 8
    anchors.right: word.left
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.session && (root.session.label || root.session.project) || "Session"
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Theme.text
    font.family: P.sans
    font.pixelSize: 12
  }
  Text {
    id: word
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.stateWord(root.state)
    textFormat: Text.PlainText
    color: root.state === "idle" ? Theme.secondary : root.stateColor(root.state)
    font.family: P.sans
    font.pixelSize: 11
    font.weight: Font.Medium
  }
  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.requested() }
}
