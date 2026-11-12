import QtQuick
import QtTest
import ".."

// Pointer tests for the top notch:
//   QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_notch.qml
Item {
  id: scene
  width: 1100
  height: 400

  Notch {
    id: notch
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
  }

  TestCase {
    name: "TopNotch"
    when: windowShown

    function test_hover_opens_and_leaving_closes() {
      mouseMove(scene, scene.width / 2, 15)
      tryVerify(function() { return notch.open }, 800, "hover opens it")
      mouseMove(scene, scene.width / 2, 390)
      tryVerify(function() { return !notch.open }, 1200, "leaving closes it")
    }

    // A panel closing (clicking its button again) must not shut the notch
    // while the pointer is still on it.
    function test_closing_a_panel_keeps_it_open_under_the_pointer() {
      mouseMove(scene, scene.width / 2, 20)
      tryVerify(function() { return notch.open }, 800)
      notch.hold = true            // a panel opened
      wait(300)
      notch.hold = false           // and closed again
      wait(600)
      verify(notch.open, "still open: the pointer is on it")
      mouseMove(scene, scene.width / 2, 390)
      tryVerify(function() { return !notch.open }, 1200, "closes once the pointer leaves")
    }

    function test_closing_a_panel_with_the_pointer_away_lets_it_close() {
      notch.hold = true
      tryVerify(function() { return notch.open }, 800)
      mouseMove(scene, scene.width / 2, 390)
      wait(200)
      notch.hold = false
      tryVerify(function() { return !notch.open }, 1200, "nothing holding it, pointer away: it closes")
    }
  }
}
