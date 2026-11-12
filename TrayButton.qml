import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "Palette.js" as P

// One tray app as a round button in the open notch's row: click to open the
// app (or its menu, if that's all it has), right-click for its menu, middle-
// click for its second action. The menu is drawn here, in Omarchy's own popup
// card, so it has the same rounded black look as every other panel and only
// one popup is ever open (the shell can't show apps' native menus).
Item {
  id: root

  required property var modelData      // a SystemTrayItem
  property var host: null               // the bar (Bar.qml)

  property bool menuOpen: false
  property var subMenu: null            // a submenu entry being shown, or null
  property string subTitle: ""
  function close() { menuOpen = false }

  readonly property string title: modelData ? (modelData.tooltipTitle || modelData.title || modelData.id || "") : ""

  width: 38
  height: 32

  Rectangle {
    id: chip
    width: 32
    height: 32
    radius: 16
    color: hover.hovered || root.menuOpen ? Theme.cardHover : Theme.card
    scale: hover.hovered ? 1.04 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    IconImage {
      anchors.centerIn: parent
      implicitSize: 18
      source: root.modelData ? root.modelData.icon : ""
      asynchronous: true
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: {
      if (!root.host) return
      if (hovered && root.title) root.host.showTooltip(chip, root.title)
      else root.host.hideTooltip(chip)
    }
  }
  TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onTapped: function(point, button) {
      var item = root.modelData
      if (!item) return
      if (root.host) root.host.hideTooltip(chip)
      if (button === Qt.MiddleButton) { item.secondaryActivate(); return }
      if (button === Qt.RightButton || (item.onlyMenu && item.hasMenu)) {
        if (item.hasMenu) root.menuOpen = !root.menuOpen
        return
      }
      root.menuOpen = false
      item.activate()
    }
  }

  QsMenuOpener {
    id: opener
    menu: root.modelData && root.modelData.hasMenu ? root.modelData.menu : null
  }
  QsMenuOpener {
    id: subOpener
    menu: root.subMenu
  }

  PopupCard {
    id: card
    anchorItem: chip
    bar: root.host
    owner: root
    open: root.menuOpen
    contentWidth: 248
    contentHeight: card.fittedContentHeight(list.implicitHeight, 440)
    onVisibleChanged: if (!visible) { root.subMenu = null; root.subTitle = "" }

    Flickable {
      anchors.fill: parent
      contentHeight: list.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: list
        width: parent.width
        spacing: 2

        // In a submenu: its name, and the way back.
        MenuRow {
          visible: root.subMenu !== null
          width: list.width
          label: "‹  " + (root.subTitle || "Back")
          onActivated: { root.subMenu = null; root.subTitle = "" }
        }

        Repeater {
          model: root.subMenu ? subOpener.children : opener.children
          delegate: Item {
            id: entryRow
            required property var modelData
            width: list.width
            height: modelData.isSeparator ? 9 : 30

            Rectangle {
              visible: entryRow.modelData.isSeparator
              anchors.verticalCenter: parent.verticalCenter
              x: 8
              width: parent.width - 16
              height: 1
              color: Theme.hairline
            }
            MenuRow {
              visible: !entryRow.modelData.isSeparator
              width: parent.width
              label: entryRow.modelData.text || ""
              enabled: entryRow.modelData.enabled
              checked: entryRow.modelData.checkState === Qt.Checked
              more: entryRow.modelData.hasChildren
              onActivated: {
                var entry = entryRow.modelData
                if (entry.hasChildren) { root.subTitle = entry.text || ""; root.subMenu = entry; return }
                entry.triggered()
                root.menuOpen = false
              }
            }
          }
        }
      }
    }
  }
}
