import QtQuick
import QtTest
import ".."
import "../Layout.js" as L

// Pointer tests for the top bar's editor and the corners:
//   QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_editor.qml
Item {
  id: scene
  width: 1100
  height: 1000

  Editor {
    id: editor
    x: 40
    y: 20
    layout: ({ left: ["media"], center: ["agents", "clock"], right: ["wifi", "bluetooth", "battery"] })
    buttons: [{ id: "a", name: "Alpha" }, { id: "b", name: "Bravo" }, { id: "c", name: "Charlie" }]
    status: ({ battery: { present: true, level: 0.5 } })
    property var last: null
    // What the bar saves: the edit through Layout.normalize, as Bar.setLayout
    // does. (An edit arrives as Qt's own list type; normalize once took that
    // for "nothing" and saved the defaults, so every edit was lost.)
    property var saved: null
    onEdited: function(next) { last = next; saved = L.normalize(next); layout = saved }
    property var lastButton: null
    onButtonMoved: function(id, index) { lastButton = { id: id, index: index } }
    property string lastGlass: ""
    onGlassRequested: function(g) { lastGlass = g; glass = g }
    property var lastFull: null
    onFullScreenRequested: function(on) { lastFull = on; fullScreen = on }
    property var lastFloating: null
    onFloatingRequested: function(on) { lastFloating = on; floating = on }
  }
  SignalSpy { id: closeSpy; target: editor; signalName: "closeRequested" }

  Ear {
    id: ear
    x: 0
    y: 600
    side: "left"
    items: ["media"]
    media: ({ available: true, playing: true, title: "Song", length: 200, position: 50, canSeek: true, canNext: true, canPrevious: true })
    property var lastMedia: null
    onMediaRequested: function(action, value) { lastMedia = { action: action, value: value } }
  }

  TestCase {
    name: "Editor"
    when: windowShown

    function chip(id, kind) {
      var list = editor.chips()
      for (var i = 0; i < list.length; i++) if (list[i].chipId === id && list[i].kind === (kind || list[i].kind)) {
        if (!kind && list[i].kind === "card") continue
        return list[i]
      }
      return null
    }
    function centre(item) { return item.mapToItem(scene, item.width / 2, item.height / 2) }
    function drag(from, to) {
      mousePress(scene, from.x, from.y)
      for (var i = 1; i <= 10; i++)
        mouseMove(scene, from.x + (to.x - from.x) * i / 10, from.y + (to.y - from.y) * i / 10)
      mouseRelease(scene, to.x, to.y)
    }

    function init() {
      editor.layout = ({ left: ["media"], center: ["agents", "clock"], right: ["wifi", "bluetooth", "battery"], cards: ["system", "today", "agents"] })
      editor.focusKey = ""
      editor.last = null
      editor.saved = null
      editor.lastButton = null
      editor.lastGlass = ""
      editor.lastFull = null
      editor.pick(null)
      closeSpy.clear()
      wait(50)
    }

    function test_move_between_corners() {
      var from = centre(chip("wifi"))
      var music = centre(chip("media"))
      drag(from, Qt.point(music.x + 50, music.y))
      verify(editor.last, "dropping on the left corner edits the layout")
      compare(JSON.stringify(editor.last.left), JSON.stringify(["media", "wifi"]))
      compare(JSON.stringify(editor.last.right), JSON.stringify(["bluetooth", "battery"]))
      compare(JSON.stringify(editor.saved.left), JSON.stringify(["media", "wifi"]), "and that's what gets saved")
      compare(JSON.stringify(editor.saved.right), JSON.stringify(["bluetooth", "battery"]))
    }

    function test_insert_before() {
      // Into the notch first: it widens for the new item, so aim once inside.
      var from = centre(chip("battery"))
      var clock = centre(chip("clock"))
      mousePress(scene, from.x, from.y)
      for (var i = 1; i <= 10; i++) mouseMove(scene, from.x + (clock.x - from.x) * i / 10, from.y)
      var agents = centre(chip("agents"))
      mouseMove(scene, agents.x - 6, agents.y)
      mouseMove(scene, agents.x - 8, agents.y)
      mouseRelease(scene, agents.x - 8, agents.y)
      compare(JSON.stringify(editor.last.center), JSON.stringify(["battery", "agents", "clock"]))
    }

    function test_take_off_and_put_back() {
      drag(centre(chip("bluetooth")), centre(chip("date")))
      compare(JSON.stringify(editor.last.right), JSON.stringify(["wifi", "battery"]), "dropped on Not shown")
      wait(50)
      var clock = centre(chip("clock"))
      drag(centre(chip("bluetooth")), Qt.point(clock.x + 40, clock.y))
      compare(JSON.stringify(editor.last.center), JSON.stringify(["agents", "clock", "bluetooth"]), "and back onto the notch")
    }

    function test_drop_nowhere_changes_nothing() {
      var from = centre(chip("wifi"))
      drag(from, Qt.point(from.x, editor.y + editor.height + 30))
      compare(editor.last, null, "dropped outside every place: back where it was")
    }

    function test_click_is_not_a_drag() {
      var p = centre(chip("clock"))
      mouseClick(scene, p.x, p.y)
      compare(editor.last, null, "a click picks it up, nothing moves yet")
      compare(editor.pickedId, "clock")
      mouseClick(scene, p.x, p.y)
      compare(editor.pickedId, "", "clicking it again puts it down")
    }

    function test_click_to_move() {
      var wifi = centre(chip("wifi"))
      mouseClick(scene, wifi.x, wifi.y)
      compare(editor.pickedId, "wifi")
      var music = centre(chip("media"))
      mouseClick(scene, music.x + 50, music.y)
      verify(editor.last, "clicking the left corner moves it there")
      compare(JSON.stringify(editor.last.left), JSON.stringify(["media", "wifi"]))
      compare(editor.pickedId, "", "and puts it down")
    }

    function test_click_to_take_off() {
      var bt = centre(chip("bluetooth"))
      mouseClick(scene, bt.x, bt.y)
      var date = centre(chip("date"))
      mouseClick(scene, date.x + 80, date.y)
      compare(JSON.stringify(editor.last.right), JSON.stringify(["wifi", "battery"]), "clicked onto Not shown")
    }

    function test_cards() {
      // Drag Today in front of System.
      var today = centre(chip("today", "card"))
      var system = centre(chip("system", "card"))
      drag(today, Qt.point(system.x - 30, system.y))
      verify(editor.last, "cards reorder")
      compare(JSON.stringify(editor.last.cards), JSON.stringify(["today", "system", "agents"]))
      editor.layout = editor.last
      wait(50)
      // Click Music (not shown), then the open notch: it joins at the end.
      var music = centre(chip("media", "card"))
      mouseClick(scene, music.x, music.y)
      compare(editor.pickedKind, "card")
      var agents = centre(chip("agents", "card"))
      mouseClick(scene, agents.x + 40, agents.y)
      compare(JSON.stringify(editor.last.cards), JSON.stringify(["today", "system", "agents", "media"]))
      editor.layout = editor.last
      wait(50)
      // And drag System off.
      var sys = centre(chip("system", "card"))
      var more = editor.mapToItem(scene, editor.width - 60, sys.y - editor.y)
      drag(sys, Qt.point(scene.mapFromItem(editor, editor.width - 60, 0).x, sys.y))
      compare(JSON.stringify(editor.last.cards), JSON.stringify(["today", "agents", "media"]))
      compare(JSON.stringify(editor.saved.cards), JSON.stringify(["today", "agents", "media"]), "saved as moved")
    }

    function test_keyboard() {
      editor.forceActiveFocus()
      keyClick(Qt.Key_Right)
      compare(editor.focusKey, "item:media", "the arrows put a ring on the first chip")
      keyClick(Qt.Key_Right)
      keyClick(Qt.Key_Right)
      compare(editor.focusKey, "item:clock")
      keyClick(Qt.Key_Return)
      compare(editor.pickedId, "clock", "Enter picks it up")
      keyClick(Qt.Key_Left)
      compare(JSON.stringify(editor.saved.center), JSON.stringify(["clock", "agents"]), "Left moves it along")
      keyClick(Qt.Key_Left)
      compare(JSON.stringify(editor.saved.left), JSON.stringify(["media", "clock"]), "and past the start into the left corner")
      keyClick(Qt.Key_Down)
      compare(editor.saved.left.indexOf("clock"), -1, "Down takes it off")
      keyClick(Qt.Key_Up)
      compare(editor.saved.center.indexOf("clock"), editor.saved.center.length - 1, "Up puts it back on the notch")
      keyClick(Qt.Key_Return)
      compare(editor.pickedId, "", "Enter puts it down")
    }

    function test_look_and_full_screen() {
      var solid = findChild(editor, "option-solid")
      var p = solid.mapToItem(scene, solid.width / 2, solid.height / 2)
      mouseClick(scene, p.x, p.y)
      compare(editor.lastGlass, "solid")
      var floatOpt = findChild(editor, "option-floating")
      var q = floatOpt.mapToItem(scene, floatOpt.width / 2, floatOpt.height / 2)
      mouseClick(scene, q.x, q.y)
      compare(editor.lastFloating, true, "Floating")
      var sw = findChild(editor, "fullScreenSwitch")
      p = sw.mapToItem(scene, sw.width / 2, sw.height / 2)
      mouseClick(scene, p.x, p.y)
      compare(editor.lastFull, true)
      mouseClick(scene, p.x, p.y)
      compare(editor.lastFull, false)
    }

    function test_reorder_buttons() {
      var a = centre(chip("a"))
      var c = centre(chip("c"))
      drag(centre(chip("c")), Qt.point(a.x - 20, a.y))
      verify(editor.lastButton, "a button moved")
      compare(editor.lastButton.id, "c")
      compare(editor.lastButton.index, 0)
    }

    function test_done_and_escape_close() {
      var p = centre(findChild(editor, "doneButton"))
      mouseClick(scene, p.x, p.y)
      compare(closeSpy.count, 1, "Done closes")
      editor.forceActiveFocus()
      keyClick(Qt.Key_Escape)
      compare(closeSpy.count, 2, "Esc closes")
    }

    function test_reset() {
      editor.layout = ({ left: [], center: ["clock"], right: [] })
      wait(50)
      var p = centre(findChild(editor, "resetButton"))
      mouseClick(scene, p.x, p.y)
      verify(editor.last, "Reset edits the layout")
      compare(JSON.stringify(editor.last.left), JSON.stringify(["workspaces", "media"]))
      compare(JSON.stringify(editor.last.center), JSON.stringify(["agents", "clock", "privacy"]))
      compare(JSON.stringify(editor.last.right), JSON.stringify(["wifi", "bluetooth", "battery"]))
      compare(JSON.stringify(editor.last.cards), JSON.stringify(["system", "notifications", "agents"]))
    }
  }

  Notch {
    id: notch
    x: 600
    y: 600
    seeThroughWhenIdle: false
  }
  Ear {
    id: dots
    x: scene.width - width
    y: 480
    side: "right"
    hoverEnabled: false
    items: ["workspaces", "privacy", "volume"]
    status: ({ workspaces: [{ id: 1, slot: 1, active: true, occupied: true }, { id: 2, slot: 2, occupied: true }, { id: 3, slot: 3 }],
               privacy: ({ mic: false, camera: false, screen: false }) })
    property var lastWs: null
    property var lastWheel: null
    onWorkspaceRequested: function(id) { lastWs = id }
    onWheelRequested: function(kind, steps) { lastWheel = { kind: kind, steps: steps } }
  }
  NotificationsCard {
    id: notes
    x: 40
    y: 800
    width: 300
    height: 160
    now: new Date(1794743900 * 1000)
    property int clears: 0
    property int alls: 0
    onCleared: clears++
    onShowAll: alls++
  }
  MiniPlayer {
    id: player
    x: 380
    y: 800
    width: 312
    media: ({ available: true, playing: true, title: "Song", identity: "Chrome", playerKey: "a",
              players: [{ key: "a", name: "Chrome" }, { key: "b", name: "Spotify" }] })
    property var last: null
    onRequested: function(action, value) { last = action }
  }
  SignalSpy { id: notchEdit; target: notch; signalName: "editRequested" }
  SignalSpy { id: earEdit; target: ear; signalName: "editRequested" }

  TestCase {
    name: "Corner"
    when: windowShown

    function test_right_click_edits() {
      mouseClick(scene, 20, ear.y + 17, Qt.RightButton)
      compare(earEdit.count, 1, "right-clicking a corner opens the editor")
      var p = notch.mapToItem(scene, notch.width / 2, 17)
      mouseClick(scene, p.x, p.y, Qt.RightButton)
      compare(notchEdit.count, 1, "and right-clicking the notch")
      mouseMove(scene, 700, 300)
    }

    function test_hover_opens_the_player_and_seeks() {
      ear.media = ({ available: true, playing: true, title: "Song", length: 200, position: 50, canSeek: true, canNext: true, canPrevious: true })
      mouseMove(scene, 40, ear.y + 17)
      tryVerify(function() { return ear.open }, 800, "hover opens it")
      tryVerify(function() { return ear.progress > 0.98 }, 1500)
      // Click three quarters of the way along the seek bar.
      var track = findChild(ear, "seekTrack")
      var at = track.mapToItem(scene, track.width * 0.75, track.height / 2)
      mouseClick(scene, at.x, at.y)
      verify(ear.lastMedia, "the click seeks")
      compare(ear.lastMedia.action, "seek")
      verify(Math.abs(ear.lastMedia.value - 150) < 3, "to three quarters of 200 s: " + ear.lastMedia.value)
      mouseMove(scene, 700, 300)
      tryVerify(function() { return !ear.open }, 1500, "leaving closes it")
    }

    function test_suppressed_and_held_closed() {
      ear.media = ({ available: true, playing: true, title: "Song" })
      ear.suppressed = true
      tryVerify(function() { return !ear.shown && ear.presence < 0.02 }, 1500, "full screen: the corner goes")
      ear.suppressed = false
      tryVerify(function() { return ear.shown && ear.presence > 0.98 }, 1500, "and comes back")
      mouseMove(scene, 40, ear.y + 17)
      tryVerify(function() { return ear.open }, 800)
      ear.holdClosed = true
      verify(!ear.open, "a panel from the corner shuts it")
      ear.holdClosed = false
      mouseMove(scene, 700, 300)
    }

    function test_tapping_the_music_goes_to_its_window() {
      ear.media = ({ available: true, playing: true, title: "Song", length: 200, position: 50, canSeek: true, canNext: true, canPrevious: true })
      ear.lastMedia = null
      mouseMove(scene, 700, 300)
      tryVerify(function() { return !ear.open }, 1500)
      // A quick tap on the closed pill, before hover opens it.
      mouseClick(scene, 40, ear.y + 17)
      verify(ear.lastMedia, "tapping the closed pill")
      compare(ear.lastMedia.action, "raise")
      // Open: the title.
      ear.lastMedia = null
      mouseMove(scene, 42, ear.y + 18)
      tryVerify(function() { return ear.progress > 0.98 }, 1500)
      var words = findChild(ear, "playerWords")
      var p = words.mapToItem(scene, 20, words.height / 2)
      mouseClick(scene, p.x, p.y)
      verify(ear.lastMedia, "tapping the title")
      compare(ear.lastMedia.action, "raise")
      mouseMove(scene, 700, 300)
    }

    function test_workspace_dots_and_scroll() {
      var row = null
      function find(item) {
        for (var i = 0; i < item.children.length; i++) {
          var c = item.children[i]
          if (c.itemId === "workspaces" && c.wide === true && !c.always) row = c
          find(c)
        }
      }
      find(dots)
      verify(row, "the workspaces item is there")
      // The second dot (the first is the wider active one).
      var p = row.mapToItem(scene, 16 + 5 + 3, row.height / 2)
      mouseClick(scene, p.x, p.y)
      compare(dots.lastWs, 2, "clicking a dot goes to its workspace")
      mouseWheel(scene, p.x, p.y, 0, -120)
      verify(dots.lastWheel, "scroll")
      compare(dots.lastWheel.kind, "workspaces", "over the dots it steps through workspaces")
      compare(dots.lastWheel.steps, -1)
    }

    function test_privacy_dots_only_while_in_use() {
      compare(dots.shownItems.indexOf("privacy"), -1, "nothing in use: no dots, no row")
      dots.status = ({ workspaces: dots.status.workspaces, privacy: ({ mic: true, camera: false, screen: false }) })
      tryVerify(function() { return dots.shownItems.indexOf("privacy") !== -1 }, 500, "the microphone in use: the dots show")
      dots.status = ({ workspaces: dots.status.workspaces, privacy: ({ mic: false, camera: false, screen: false }) })
    }

    function test_notifications_card() {
      var rows = []
      for (var i = 0; i < 7; i++) rows.push({ key: "k" + i, app: "App", glyph: "", summary: "Note " + i, body: "Body", ts: 1794743800 - i * 600 })
      notes.notifications = rows
      wait(100)
      compare(notes.overflow, true, "more than fit")
      verify(notes.shown.length >= 2 && notes.shown.length < 7, "shows what fits: " + notes.shown.length)
      var more = findChild(notes, "showAllNotifications")
      var p = more.mapToItem(scene, more.width / 2, more.height / 2)
      mouseClick(scene, p.x, p.y)
      compare(notes.alls, 1, "Show all")
      var clear = findChild(notes, "clearNotifications")
      p = clear.mapToItem(scene, clear.width / 2, clear.height / 2)
      mouseClick(scene, p.x, p.y)
      compare(notes.clears, 1, "Clear")
      compare(notes.ago(1794743900 - 30), "now")
      compare(notes.ago(1794743900 - 7200), "2h")
    }

    function test_switch_player() {
      var pill = findChild(player, "switchPlayer")
      verify(pill.visible, "two players: the switch shows")
      var p = pill.mapToItem(scene, pill.width / 2, pill.height / 2)
      mouseClick(scene, p.x, p.y)
      compare(player.last, "switchPlayer", "and switches, without also going to the window")
    }

    function test_hides_when_nothing_plays() {
      ear.media = ({ available: false })
      tryVerify(function() { return !ear.shown && ear.presence < 0.02 }, 1500, "nothing playing: the corner goes")
      ear.media = ({ available: true, playing: false, title: "Song" })
      tryVerify(function() { return ear.shown && ear.presence > 0.98 }, 1500, "paused music still shows")
    }
  }
}



