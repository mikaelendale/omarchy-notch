import QtQuick
import QtQuick.Effects
import "Palette.js" as P

// A coding agent's mark, in one of three states:
//
//   idle       the agent's own logo
//   working    a circle grows from the middle, uncovering it, then shrinks back
//   needs you  tinted yellow
//
// Claude's is drawn from its official outline (ClaudeLogo); the others use
// the logos Omarchy ships for its agents panel, picking the light-surface
// version on light themes, with a sparkle for agents that have none.
Item {
  id: root

  property string agent: "claude"
  property real size: 18
  property bool working: false
  property bool needs: false
  property real motion: 1

  readonly property string assets: "file:///usr/share/omarchy/shell/plugins/agents/assets/"
  readonly property var known: ["agy", "codex", "copilot", "cursor", "devin", "grok", "hermes", "kimi", "muse", "opencode", "qwen", "deepseek", "minimax"]
  readonly property bool hasLogo: known.indexOf(agent) !== -1
  property bool lightFailed: false
  onAgentChanged: lightFailed = false
  readonly property string source: !hasLogo ? ""
    : assets + agent + (!Theme.dark && !lightFailed ? "-light" : "") + ".svg"

  property real reveal: 1
  readonly property bool revealing: working && !needs && motion > 0 && agent !== "claude"

  width: size
  height: size

  ClaudeLogo {
    visible: root.agent === "claude"
    anchors.fill: parent
    size: root.size
    working: root.working
    needs: root.needs
    motion: root.motion
  }

  Item {
    anchors.fill: parent
    visible: root.agent !== "claude"

    Image {
      id: logo
      anchors.fill: parent
      source: root.source
      sourceSize.width: Math.ceil(root.size * 2)
      sourceSize.height: Math.ceil(root.size * 2)
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      visible: false
      onStatusChanged: if (status === Image.Error && !Theme.dark && !root.lightFailed) root.lightFailed = true
    }
    // The growing circle, as a mask.
    Item {
      id: circle
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 1.45 * root.reveal
        height: width
        radius: width / 2
      }
    }
    // A faint copy underneath while the circle works.
    MultiEffect {
      anchors.fill: parent
      source: logo
      visible: logo.status === Image.Ready && root.revealing
      opacity: 0.2
    }
    MultiEffect {
      anchors.fill: parent
      source: logo
      visible: logo.status === Image.Ready
      maskEnabled: root.revealing
      maskSource: circle
      maskThresholdMin: 0.5
      maskSpreadAtMin: 0.3
      colorization: root.needs ? 1 : 0
      colorizationColor: Theme.yellow
    }
    // No logo of its own: a sparkle.
    Text {
      anchors.centerIn: parent
      visible: !root.hasLogo || logo.status === Image.Error
      text: String.fromCodePoint(0xF0674)
      textFormat: Text.PlainText
      color: root.needs ? Theme.yellow : Theme.text
      opacity: root.revealing ? (0.35 + 0.65 * root.reveal) : 1
      font.family: P.glyphs
      font.pixelSize: root.size * 0.9
    }
  }

  SequentialAnimation {
    running: root.revealing && root.visible
    loops: Animation.Infinite
    NumberAnimation { target: root; property: "reveal"; from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 160 }
    NumberAnimation { target: root; property: "reveal"; to: 0; duration: 520; easing.type: Easing.InOutCubic }
    PauseAnimation { duration: 90 }
  }
  onRevealingChanged: if (!revealing) reveal = 1
}
