import QtQuick
import QtTest
import ".."

// Pointer tests for the side strip:
//   QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_side.qml
Item {
  id: scene
  width: 1200
  height: 700

  SideNotch {
    id: side
    x: scene.width - width
    y: 100
    modes: ({ dnd: false, muted: false, layout: "dwindle" })
    usage: ({ ready: true, session: 0.2, weekly: 0.5 })
    property var lastDrop: null
    property int drags: 0
    onDragged: function(dx, dy) { drags++ }
    onDropped: function(dx, dy) { lastDrop = { dx: dx, dy: dy } }
    property int mutes: 0
    onMuteRequested: mutes++
  }

  SignalSpy { id: dropSpy; target: side; signalName: "dropped" }

  TestCase {
    name: "SideStrip"
    when: windowShown

    function stripPoint(rowY) {
      // centre of the strip, at a y inside the SideNotch
      return { x: side.x + side.stripX + side.stripW / 2, y: side.y + rowY }
    }

    function test_drag_from_grip() {
      dropSpy.clear()
      var p = stripPoint(side.gripY + side.gripH / 2)
      mousePress(scene, p.x, p.y)
      for (var i = 1; i <= 12; i++) mouseMove(scene, p.x - i * 75, p.y + i * 10)
      mouseRelease(scene, p.x - 900, p.y + 120)
      compare(dropSpy.count, 1, "a drag from the grip ends in a drop")
      verify(side.lastDrop.dx < -800, "dx " + side.lastDrop.dx)
      verify(side.lastDrop.dy > 100, "dy " + side.lastDrop.dy)
    }

    function test_drag_from_icon() {
      dropSpy.clear()
      var mutesBefore = side.mutes
      var p = stripPoint(side.volumeY + side.rowH / 2)
      mousePress(scene, p.x, p.y)
      for (var i = 1; i <= 8; i++) mouseMove(scene, p.x, p.y + i * 8)
      mouseRelease(scene, p.x, p.y + 64)
      compare(dropSpy.count, 1, "a drag that starts on an icon moves the strip too")
      compare(side.mutes, mutesBefore, "and doesn't click the icon")
      verify(side.lastDrop.dy > 50, "dy " + side.lastDrop.dy)
    }

    function test_click_icon() {
      var before = side.mutes
      var p = stripPoint(side.volumeY + side.rowH / 2)
      mouseClick(scene, p.x, p.y)
      compare(side.mutes, before + 1, "a click on the volume icon mutes")
    }

    function test_modes_drop_down_without_moving_rows() {
      var volumeBefore = side.volumeY
      var p = stripPoint(side.modesY + side.rowH / 2)
      mouseMove(scene, p.x, p.y)
      tryCompare(side, "modesOpen", true, 500)
      tryVerify(function() { return side.modesAmount > 0.99 }, 1200, "Modes opens")
      compare(side.volumeY, volumeBefore, "the rows below don't move")
      // Hovering where the volume row is, under the open list, picks a switch, not volume.
      var under = stripPoint(side.volumeY + side.rowH / 2)
      mouseMove(scene, under.x, under.y)
      wait(250)
      verify(side.active === "" || side.active.indexOf("mode:") === 0, "active " + side.active)
      mouseMove(scene, 10, 10)
      tryCompare(side, "modesOpen", false, 800)
      tryVerify(function() { return side.modesAmount < 0.01 }, 1200, "Modes shuts")
    }

    function test_modes_open_upward_near_the_bottom() {
      side.roomBelow = 10
      var p = stripPoint(side.modesY + side.rowH / 2)
      var iconAbsY = side.y + side.modesY
      mouseMove(scene, p.x, p.y)
      tryVerify(function() { return side.modesAmount > 0.99 }, 1200, "Modes opens")
      verify(side.modesUp, "opens upward")
      // In the real window the strip's bottom is held; here the item stays put,
      // so the icon's offset grows by exactly what the strip grows by.
      fuzzyCompare(side.modesY - side.gripY - side.gripH, side.modesListH, 4)
      mouseMove(scene, 10, 10)
      tryVerify(function() { return side.modesAmount < 0.01 }, 1200, "Modes shuts")
      side.roomBelow = 10000
    }

    function test_hover_opens_volume() {
      var p = stripPoint(side.volumeY + side.rowH / 2)
      mouseMove(scene, p.x, p.y)
      tryCompare(side, "active", "volume", 500)
      verify(side.engaged)
      mouseMove(scene, 10, 10)
      tryCompare(side, "active", "", 600)
    }
  }
}
