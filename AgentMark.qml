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
  readonly property bool revealing: working && !needs && motion > 0 && Motion.ambient && agent !== "claude"

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

  // The reveal, in steps on Motion's slow beat (sampled from the original
  // curve: in over 620 ms, a beat at full, out over 520 ms, a beat at
  // nothing) rather than every frame: each step repaints the bar's window and
  // Hyprland re-blurs it, so a handful of steps a second keeps a working agent
  // from keeping the whole bar busy.
  readonly property var revealSteps: {
    function outCubic(t) { return 1 - Math.pow(1 - t, 3) }
    function inOutCubic(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2 }
    var out = []
    for (var ms = 0; ms < 1390; ms += Motion.beat) {
      if (ms < 620) out.push(outCubic(ms / 620))
      else if (ms < 780) out.push(1)
      else if (ms < 1300) out.push(1 - inOutCubic((ms - 780) / 520))
      else out.push(0)
    }
    return out
  }
  property int revealStep: 0
  Timer {
    running: root.revealing && root.visible
    repeat: true
    interval: Motion.beat
    onTriggered: {
      root.revealStep = (root.revealStep + 1) % root.revealSteps.length
      root.reveal = root.revealSteps[root.revealStep]
    }
  }
  onRevealingChanged: if (!revealing) { reveal = 1; revealStep = 0 }
  // Still (Motion at Light or Off): a small dot says it's at work.
  Rectangle {
    visible: root.working && !root.needs && !Motion.ambient
    width: Math.max(4, Math.round(root.size * 0.3))
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: -width / 3
    anchors.bottomMargin: -width / 3
    color: Theme.green
    border.width: 1
    border.color: Theme.bodySolid
  }
}
