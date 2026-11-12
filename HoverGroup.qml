import QtQuick

// One row of the side notch: its icon in the strip and the tab that slides
// out beside it. Hovering the row opens its tab almost at once; leaving it
// closes the tab a moment later, so moving between the icon and its tab, or
// grazing past a row, doesn't flicker. Only one tab is out at a time
// (host.active holds its name).
Item {
  id: root

  property string name: ""
  property var host: null
  readonly property bool hovered: hover.hovered

  HoverHandler { id: hover }

  Timer {
    id: openTimer
    interval: 30
    // While Modes is down it covers the rows beneath; only its own switches
    // answer the pointer then.
    onTriggered: {
      if (!root.host || root.host.dragging) return
      if (root.host.modesOpen && root.name.indexOf("mode:") !== 0) return
      root.host.active = root.name
    }
  }
  Timer {
    id: closeTimer
    interval: 110
    onTriggered: if (root.host && root.host.active === root.name) root.host.active = ""
  }
  onHoveredChanged: {
    if (hovered) { closeTimer.stop(); openTimer.restart() }
    else { openTimer.stop(); closeTimer.restart() }
  }
}
