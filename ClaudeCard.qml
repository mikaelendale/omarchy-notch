import QtQuick
import "Palette.js" as P

// Coding agents: every open session (Claude, Codex, OpenCode...), most urgent
// first, each with its agent's mark. Click one to go to its window;
// Conversations opens the Super+Shift+C picker.
Rectangle {
  id: root

  property var claude: ({ sessions: [], counts: ({}) })
  property real motion: 1

  signal sessionRequested(var session)
  signal conversationsRequested()

  readonly property var sessions: claude && claude.sessions ? claude.sessions : []
  readonly property var counts: claude && claude.counts ? claude.counts : ({})
  readonly property bool working: (counts.working || 0) + (counts.watching || 0) > 0
  property string defaultAgent: "claude"
  readonly property var lead: {
    for (var i = 0; i < sessions.length; i++) if (sessions[i].state === "needs") return sessions[i]
    for (var j = 0; j < sessions.length; j++) if (sessions[j].state === "working" || sessions[j].state === "watching") return sessions[j]
    return { agent: defaultAgent, state: "idle" }
  }
  // "Claude" when every session is Claude's, "Agents" when they're mixed.
  readonly property string heading: {
    var names = {}
    for (var i = 0; i < sessions.length; i++) names[sessions[i].agentName || "Claude"] = true
    var keys = Object.keys(names)
    return keys.length === 1 ? keys[0] : (keys.length === 0 ? "Agents" : "Agents")
  }

  radius: 22
  color: Theme.card

  Item {
    anchors.fill: parent
    anchors.margins: 14

    Row {
      id: header
      spacing: 7
      AgentMark {
        anchors.verticalCenter: parent.verticalCenter
        size: 16
        agent: root.lead.agent || "claude"
        working: root.lead.state === "working" || root.lead.state === "watching"
        needs: root.lead.state === "needs"
        motion: root.motion
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.heading
        textFormat: Text.PlainText
        color: Theme.text
        font.family: P.sans
        font.pixelSize: 15
        font.weight: Font.DemiBold
      }
    }

    Column {
      anchors.top: header.bottom
      anchors.topMargin: 9
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 2

      Text {
        visible: root.sessions.length === 0
        width: parent.width
        text: "No sessions open"
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: P.sans
        font.pixelSize: 12
      }

      Repeater {
        model: root.sessions.slice(0, 3)
        SessionRow {
          width: parent.width
          session: modelData
          onRequested: root.sessionRequested(modelData)
        }
      }
    }

    // Conversations: the picker from Super+Shift+C.
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 26
      radius: 13
      color: convHover.hovered
        ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09))
        : (Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
      Behavior on color { ColorAnimation { duration: 100 } }
      Text {
        anchors.centerIn: parent
        text: root.sessions.length > 3 ? ("All conversations  ·  " + root.sessions.length + " open") : "Conversations"
        textFormat: Text.PlainText
        color: Theme.text
        font.family: P.sans
        font.pixelSize: 12
        font.weight: Font.Medium
      }
      HoverHandler { id: convHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.conversationsRequested() }
    }
  }
}
