import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import qs.Commons
import "Palette.js" as P
import "Layout.js" as Layout
import "Players.js" as Players
import "Machine.js" as Machine

// A replacement for Omarchy's bar (kind "bar"): one notch per screen.
//
// This file is the bar host. It feeds the notch its data (the time, what's
// playing, Claude Code's sessions, tray apps) and lends the open notch
// Omarchy's own bar widgets, read from the same `bar.layout` in shell.json
// the stock bar uses. Those widgets stay Omarchy's code, so they keep getting
// Omarchy's updates; this host gives them the bar surface they expect
// (colours, run, tooltips, one-panel-at-a-time) the way the stock bar does.
//
// To go back to the stock bar, remove "id": "mike.notch" from the bar section
// of ~/.config/omarchy/shell.json. If this file ever fails to load, the shell
// falls back to the stock bar on its own.
Item {
  id: root

  // ---- injected by the shell
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})

  readonly property string home: Quickshell.env("HOME")
  readonly property string agentsScript: Qt.resolvedUrl("agents.py").toString().replace(/^file:\/\//, "")

  // ---- the bar surface Omarchy's widgets and the shell read
  property bool barHidden: false
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property int barSize: Style.bar.sizeHorizontal
  readonly property string fontFamily: Style.font.family
  readonly property color foreground: Theme.text
  readonly property color barForeground: Theme.text
  readonly property color background: Theme.bodySolid
  readonly property color urgent: Theme.red
  readonly property bool transparent: false
  readonly property bool glassy: false
  readonly property bool foregroundAnimationEnabled: Style.duration(100) > 0
  readonly property var layoutConfig: barConfig && barConfig.layout ? barConfig.layout : ({})
  property var activePopout: null
  property var clickTargets: []
  property bool centerHoverRevealSuppressed: false
  readonly property bool centerSectionRevealHeld: false
  readonly property bool traySectionDragActive: false
  readonly property bool traySectionPopoutOpen: false
  readonly property bool barHovered: false

  // Each screen's notch thickness: closed, or the open notch while it's open,
  // so a widget's panel opens below it and toasts clear it.
  readonly property var screenBarSizes: {
    var sizes = ({})
    var list = notches.instances
    for (var i = 0; i < list.length; i++) {
      var w = list[i]
      if (w && w.screenName) sizes[w.screenName] = w.thickness
    }
    return sizes
  }

  function barSizeFor(screenName) {
    var size = screenBarSizes[String(screenName || "")]
    return size > 0 ? size : 34
  }

  function run(command) {
    var text = String(command || "")
    if (text) Quickshell.execDetached(["bash", "-c", text])
  }

  // One panel open at a time, like the stock bar.
  function requestPopout(owner) {
    if (activePopout === owner) return
    var previous = activePopout
    if (previous) {
      if ("closeForPopoutSwitch" in previous) previous.closeForPopoutSwitch()
      else if ("close" in previous) previous.close()
    }
    activePopout = owner
  }
  function releasePopout(owner) { if (activePopout === owner) activePopout = null }
  function notePopoutCard(card) {}
  function popoutCardFor(owner) { return null }
  function switchPanelFrom(owner, direction) { return false }
  function setCenterHoverRevealSuppressed(value) { centerHoverRevealSuppressed = !!value }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    clickTargets = clickTargets.concat([target])
  }
  function unregisterClickTarget(target) {
    var i = clickTargets.indexOf(target)
    if (i === -1) return
    var next = clickTargets.slice()
    next.splice(i, 1)
    clickTargets = next
  }
  function windowOf(item) {
    try { return item && item.QsWindow ? item.QsWindow.window : null } catch (e) { return null }
  }
  function targetBelongsToWindow(target, window) {
    var w = windowOf(target)
    return !!w && !!window && (w === window || (window.QsWindow && w === window.QsWindow.window))
  }

  // ---- tooltips (drawn inside the notch's own window)
  property var tooltipTarget: null
  property string tooltipText: ""
  function showTooltip(target, text) { tooltipTarget = target; tooltipText = String(text || "") }
  function hideTooltip(target) { if (!target || target === tooltipTarget) { tooltipTarget = null; tooltipText = "" } }

  // ---- hosted widgets
  property var hosts: []
  function registerHost(host) { hosts = hosts.concat([host]) }
  function unregisterHost(host) {
    var i = hosts.indexOf(host)
    if (i === -1) return
    var next = hosts.slice()
    next.splice(i, 1)
    hosts = next
  }
  function moduleWidgets(id) {
    var out = []
    for (var i = 0; i < hosts.length; i++)
      if (hosts[i].widgetId === id && hosts[i].item) out.push(hosts[i].item)
    return out
  }
  function focusedScreenName() {
    var m = Hyprland.focusedMonitor
    return m ? m.name : ""
  }
  function findHost(id) {
    var focused = focusedScreenName()
    var any = null
    for (var i = 0; i < hosts.length; i++) {
      var h = hosts[i]
      if (h.widgetId !== id || !h.item) continue
      if (h.screenName === focused) return h
      if (!any) any = h
    }
    return any
  }
  // Keyboard shortcuts and `omarchy-shell shell toggle <panel>` land here.
  // The notch opens first, so the panel hangs from the widget where it shows.
  function summonBarWidget(id) {
    // A widget whose item sits in a corner opens its panel from there.
    var focused = focusedScreenName()
    var wins = notches.instances
    for (var w = 0; w < wins.length; w++) {
      var win = wins[w]
      if (!win || (wins.length > 1 && win.screenName !== focused)) continue
      var corner = win.cornerFor(String(id || ""))
      if (corner) { win.openFromCorner(corner, String(id)); return true }
      break
    }
    var host = findHost(String(id || ""))
    if (!host || !host.item || typeof host.item.open !== "function") return false
    host.window.summon(host.item)
    return true
  }
  function hideBarWidget(id) {
    var host = findHost(String(id || ""))
    if (!host || !host.item || typeof host.item.close !== "function") return false
    host.item.close()
    return true
  }
  function isBarWidgetOpen(id) {
    var host = findHost(String(id || ""))
    return !!host && !!host.item && host.item.opened === true
  }

  function entrySettings(entry) {
    var out = ({})
    if (!entry || typeof entry !== "object") return out
    for (var k in entry) if (k !== "id" && k !== "type" && k !== "source") out[k] = entry[k]
    return out
  }
  function entries(section) {
    var list = layoutConfig && Array.isArray(layoutConfig[section]) ? layoutConfig[section] : []
    return list.filter(function(e) { return e && typeof e === "object" && e.id && !e.type })
  }
  // The stock bar's sections, mapped onto the notch. The Omarchy menu sits on
  // the left; every other widget joins one scrollable row of round buttons,
  // the right section's first (Wi-Fi, volume, battery...), then the ones that
  // sat around the clock. The notch draws its own clock, has no workspace
  // numbers, and shows tray apps itself (no drawer, nothing to pin), so
  // Omarchy's clock, workspaces and tray widgets are left out.
  readonly property var skippedWidgets: ["omarchy.workspaces", "omarchy.clock", "omarchy.tray"]
  readonly property var sections: {
    var skip = skippedWidgets
    function keep(e) { return skip.indexOf(e.id) === -1 }
    var menu = entries("left").filter(keep)
    var strip = [].concat(
      entries("right").filter(keep),
      entries("centerBegin").filter(keep),
      entries("center").filter(keep),
      entries("centerEnd").filter(keep),
      entries("tray").filter(keep))
    return { menu: menu, strip: strip }
  }
  readonly property string clockFormat: {
    var all = [].concat(entries("left"), entries("center"), entries("right"))
    for (var i = 0; i < all.length; i++)
      if (all[i].id === "omarchy.clock" && all[i].format && String(all[i].format).indexOf("\n") === -1) return String(all[i].format)
    return "h:mm AP"
  }

  // ---- colours from the current Omarchy theme (colors.toml), re-read whenever
  // a theme is set (Omarchy bumps theme.generation)
  readonly property string themeDir: home + "/.local/state/omarchy/current"
  FileView {
    id: themeColors
    path: root.themeDir + "/theme/colors.toml"
    printErrors: false
    onLoaded: {
      var values = ({})
      var lines = text().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([a-z_]+)\s*=\s*"([^"]*)"/)
        if (m) values[m[1]] = m[2]
      }
      Theme.apply(values)
    }
  }
  FileView {
    path: root.themeDir + "/theme.generation"
    watchChanges: true
    printErrors: false
    onFileChanged: { reload(); themeColors.reload() }
  }

  // ---- motion: the editor's choice (Auto, Smooth, Light, Off). Auto picks
  // Off when Omarchy's animations are off (`omarchy toggle animations`),
  // Light on a modest machine (4 GB of memory or less, or 2 processor
  // threads or fewer), and Smooth otherwise. Every animation reads Motion.
  readonly property string motionChoice: ["smooth", "light", "off"].indexOf(String(prefs.motion)) !== -1 ? String(prefs.motion) : "auto"
  property bool modestMachine: false
  Process {
    running: true
    command: ["bash", "-c", "awk '/^MemTotal:/ {print $2}' /proc/meminfo; nproc"]
    stdout: StdioCollector {
      onStreamFinished: {
        var f = String(text).trim().split(/\s+/)
        root.modestMachine = Machine.isModest(f[0], f[1])
      }
    }
  }
  readonly property string motionLevel: Machine.level(motionChoice, Style.duration(100) > 0, modestMachine)
  Binding { target: Motion; property: "level"; value: root.motionLevel }
  readonly property real motion: Motion.scale

  // ---- the time
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // ---- what's playing
  readonly property var players: Mpris.players ? Mpris.players.values : []
  // The player chosen in the music corner (its "switch" button), by D-Bus
  // name; until then, or once it's gone, the one playing.
  property string preferredPlayerKey: ""
  function playerKey(p) { return p ? String(p.dbusName || p.identity || "") : "" }
  // A new player turning up hands the choice back to whichever plays.
  property int playerCount: 0
  onPlayersChanged: {
    if (players.length > playerCount) preferredPlayerKey = ""
    playerCount = players.length
  }
  readonly property var playerChoices: players.filter(function(p) {
    return p && (p.isPlaying || p.trackTitle || p.trackArtist)
  }).map(function(p) { return { key: root.playerKey(p), name: String(p.identity || "Player") } })
  readonly property var player: {
    var list = players
    if (preferredPlayerKey)
      for (var k = 0; k < list.length; k++) if (list[k] && playerKey(list[k]) === preferredPlayerKey) return list[k]
    var fallback = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p) continue
      if (p.isPlaying) return p
      if (!fallback && (p.trackTitle || p.trackArtist)) fallback = p
    }
    return fallback
  }
  property int mediaTick: 0
  Timer {
    interval: 1000
    repeat: true
    running: !!root.player && root.player.isPlaying && (root.openNotches > 0 || root.openCorners > 0)
    onTriggered: {
      if (root.player) root.player.positionChanged()
      root.mediaTick++
    }
    // Opening a player: the right position at once, not a second later.
    onRunningChanged: if (running) triggered()
  }
  // The showcase's song: playing, silent (nothing actually plays), so the
  // bar can be seen, and measured, with music going.
  readonly property var showcaseMedia: ({
    available: true, playing: true, title: "Lose My Mind", artist: "Showcase", artUrl: "", identity: "Music",
    position: 64, length: 212, canSeek: false, canNext: true, canPrevious: true, canRaise: false,
    shuffleSupported: false, shuffle: false, loopSupported: false, loop: "none", rateSupported: false, rate: 1,
    players: [], playerKey: ""
  })
  readonly property var media: showcase || loadTest ? showcaseMedia : realMedia
  // `omarchy-shell mike.notch loadTest true|false` (for measuring): your own
  // layout, with a silent song playing and agents all at work, the load that
  // used to keep the bar repainting non-stop.
  property bool loadTest: false
  readonly property var realMedia: {
    var tick = mediaTick
    var p = player
    if (!p) return ({ available: false })
    var minRate = Number(p.minRate || 1), maxRate = Number(p.maxRate || 1)
    return {
      available: true,
      playing: !!p.isPlaying,
      title: p.trackTitle || "",
      artist: p.trackArtist || "",
      artUrl: p.trackArtUrl || "",
      identity: p.identity || "",
      position: p.positionSupported ? p.position : 0,
      length: p.lengthSupported ? p.length : 0,
      canSeek: !!p.canSeek && !!p.positionSupported,
      canNext: !!p.canGoNext,
      canPrevious: !!p.canGoPrevious,
      canRaise: !!p.canRaise,
      shuffleSupported: !!p.shuffleSupported,
      shuffle: !!p.shuffle,
      loopSupported: !!p.loopSupported,
      loop: p.loopState === MprisLoopState.Track ? "track" : (p.loopState === MprisLoopState.Playlist ? "playlist" : "none"),
      rateSupported: maxRate > 1.001 || minRate < 0.999,
      rate: Number(p.rate || 1),
      minRate: minRate,
      maxRate: maxRate,
      players: playerChoices,
      playerKey: playerKey(p)
    }
  }
  function mediaAction(action, value) {
    var p = player
    if (!p) return
    if (action === "toggle" && p.canTogglePlaying) p.togglePlaying()
    else if (action === "next" && p.canGoNext) p.next()
    else if (action === "previous" && p.canGoPrevious) p.previous()
    else if (action === "seek" && p.canSeek) {
      var to = Math.max(0, Number(value) || 0)
      if (p.lengthSupported && p.length > 0) to = Math.min(to, p.length - 0.5)
      p.position = to
      mediaTick++
    }
    else if (action === "shuffle" && p.shuffleSupported) p.shuffle = !!value
    else if (action === "loop" && p.loopSupported)
      p.loopState = value === "track" ? MprisLoopState.Track : (value === "playlist" ? MprisLoopState.Playlist : MprisLoopState.None)
    else if (action === "rate") p.rate = Number(value) || 1
    else if (action === "raise") raisePlayer()
    else if (action === "switchPlayer") {
      var choices = playerChoices
      if (choices.length < 2) return
      var at = 0
      for (var i = 0; i < choices.length; i++) if (choices[i].key === playerKey(p)) at = i
      preferredPlayerKey = choices[(at + 1) % choices.length].key
    }
  }

  // ---- go to the window that's playing. A player that can raise itself
  // does; most can't (Chrome, and so YouTube, can't), so the window is found
  // by its title holding the track's title (a YouTube tab or app window
  // does), else by the player's app, and focused.
  function raisePlayer() {
    var p = player
    if (!p) return
    if (p.canRaise) { p.raise(); return }
    raiseProbe.track = String(p.trackTitle || "")
    raiseProbe.app = String(p.desktopEntry || p.identity || "")
    raiseProbe.focus = true
    if (!raiseProbe.running) raiseProbe.running = true
  }
  property string lastPlayerWindow: ""
  Process {
    id: raiseProbe
    property string track: ""
    property string app: ""
    property bool focus: true
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var clients = []
        try { clients = JSON.parse(text) } catch (e) {}
        var win = Players.windowFor(clients, raiseProbe.track, raiseProbe.app)
        root.lastPlayerWindow = JSON.stringify(win)
        if (raiseProbe.focus && win && /^0x[0-9a-fA-F]+$/.test(win.address))
          Hyprland.dispatch('hl.dsp.focus({ window = "address:' + win.address + '" })')
      }
    }
  }

  // ---- Every coding agent's sessions (agents.py): Claude Code from the
  // claude-sessions widget's collector, the others by watching their terminals.
  // A non-Claude session whose terminal rang the bell (Hyprland's urgent flag)
  // is waiting on you.
  Text { id: fontProbe; visible: false; text: "Ag"; font.family: "monospace" }
  property var agentsRaw: ({ sessions: [], counts: ({}) })
  // `omarchy-shell mike.notch previewSessions` (or `notch-look preview`): a
  // minute of made-up sessions, to see the notch with a crowd of them.
  property var agentsPreview: null
  Timer { id: agentsPreviewEnd; interval: 60000; onTriggered: root.agentsPreview = null }
  function previewSessions() {
    var agents = ["claude", "codex", "claude", "opencode", "claude", "gemini", "claude"]
    var names = { claude: "Claude", codex: "Codex", opencode: "OpenCode", gemini: "Gemini" }
    var labels = ["Fix the flaky payments webhook retries", "Respond to the design review",
      "Super shift C shortcut for the conversations window", "Refactor the notch hover timing",
      "Write the release notes", "Buildr creator directory search", "Dock flares on every edge",
      "Translate the README", "Contextual teaser sky shader", "Bump Hyprland and test the Lua config",
      "Birthday scrapbook PIN lock", "Sort out the Telegram bot", "RAVN landing copy pass", "Google Drive installation"]
    var states = ["needs", "needs", "done", "working", "working", "working", "watching", "done", "idle", "idle", "idle", "idle", "idle", "idle"]
    var list = []
    for (var i = 0; i < labels.length; i++) {
      var agent = agents[i % agents.length]
      list.push({ id: "preview:" + i, agent: agent, agentName: names[agent], label: labels[i], project: "preview",
        state: states[i], reason: states[i] === "needs" ? "permission" : "", detail: "", window: "", workspace: "", focused: false })
    }
    agentsPreview = { sessions: list, counts: {} }
    agentsPreviewEnd.restart()
  }
  readonly property var urgentWindows: {
    var out = ({})
    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < list.length; i++) {
      var t = list[i]
      if (t && t.urgent && t.address) out["0x" + String(t.address).replace(/^0x/, "")] = true
    }
    return out
  }
  readonly property var claude: {
    var raw = agentsPreview || agentsRaw
    var list = Array.isArray(raw.sessions) ? raw.sessions : []
    var urgent = urgentWindows
    var sessions = []
    var counts = { needs: 0, done: 0, working: 0, watching: 0, idle: 0 }
    for (var i = 0; i < list.length; i++) {
      var s = list[i]
      if (s.agent && s.agent !== "claude" && s.window && urgent[s.window]) {
        var copy = {}
        for (var k in s) copy[k] = s[k]
        copy.state = "needs"
        copy.reason = "bell"
        s = copy
      }
      sessions.push(s)
      if (counts[s.state] !== undefined) counts[s.state]++
    }
    // Most urgent first. (Not `order[x] || 9`: "needs" is 0, which || skips.)
    sessions.sort(function(a, b) {
      var order = { needs: 0, done: 1, working: 2, watching: 3, idle: 4 }
      return (a.state in order ? order[a.state] : 9) - (b.state in order ? order[b.state] : 9)
    })
    return { sessions: sessions, counts: counts }
  }
  onClaudeChanged: checkAlerts(claude.sessions)
  Process {
    id: sessions
    running: true
    command: ["python3", "-I", "-B", root.agentsScript, "--interval", root.lean ? "3" : "1"]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line)
          if (data && Array.isArray(data.sessions)) root.agentsRaw = data
        } catch (e) {}
      }
    }
    onExited: restartSessions.start()
  }

  // The agent `omarchy agent` starts: its mark stands in when nothing's running.
  property string defaultAgent: "claude"
  Process {
    running: true
    command: ["omarchy-default-agent"]
    stdout: SplitParser {
      onRead: function(line) {
        var id = String(line).trim()
        if (id === "cursor-agent") id = "cursor"
        if (/^[a-z0-9-]{1,32}$/.test(id)) root.defaultAgent = id
      }
    }
  }
  Timer {
    id: restartSessions
    interval: 5000
    onTriggered: sessions.running = true
  }
  function focusSession(session) {
    var address = session && session.window ? String(session.window) : ""
    if (/^0x[0-9a-fA-F]+$/.test(address))
      Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })')
  }
  // ---- notifications on screen
  //
  // Omarchy's notification daemon writes the cards it's showing to live.json;
  // while there are any, the notch stays solid, so the card hanging under it
  // and the notch read as one.
  property bool notificationsShowing: false
  FileView {
    path: root.home + "/.local/state/omarchy/notifications/live.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var rows = root.readRows(text())
      root.notifLive = rows
      root.notificationsShowing = rows.length > 0
    }
    onLoadFailed: { root.notificationsShowing = false; root.notifLive = [] }
  }

  // ---- "Claude needs you" toasts, in the notch
  //
  // When a session starts waiting on you and its window isn't the one you're
  // looking at, the notch grows into a toast for it (and the claude-sessions
  // widget's own desktop notification is switched off, so there's one).
  property var alert: null
  property var lastStates: ({})
  // `notch-look claude-toasts notch|desktop` switches these off in favour of
  // the claude-sessions widget's desktop notifications.
  property bool claudeToasts: true
  // Full screen (windows run under the notch, and it's see-through while idle)
  // or not, the default (the notch keeps a solid strip of its own and windows
  // start below it).
  property bool windowsUnderNotch: false
  property var prefs: ({})
  FileView {
    id: prefsFile
    path: root.home + "/.local/state/mike-notch/prefs.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.prefs = JSON.parse(text()) || ({}) } catch (e) { root.prefs = ({}) }
      root.claudeToasts = root.prefs.claudeToasts !== false
      root.windowsUnderNotch = root.prefs.windowsUnderNotch === true
    }
    onLoadFailed: { root.claudeToasts = true; root.windowsUnderNotch = false }
  }
  function setPref(key, value) {
    var next = ({})
    for (var k in prefs) next[k] = prefs[k]
    next[key] = value
    prefs = next
    if (key === "windowsUnderNotch") windowsUnderNotch = !!value
    Quickshell.execDetached(["mkdir", "-p", root.home + "/.local/state/mike-notch"])
    prefsSave.restart()
  }
  Timer {
    id: prefsSave
    interval: 150
    onTriggered: prefsFile.setText(JSON.stringify(root.prefs) + "\n")
  }
  readonly property var reasonText: ({
    bell: "is waiting on you",
    permission: "needs permission",
    approval: "has a plan to approve",
    question: "has a question",
    dialog: "has a dialog open"
  })
  function checkAlerts(list) {
    var next = ({})
    for (var i = 0; i < list.length; i++) {
      var s = list[i]
      if (!s || !s.id) continue
      next[s.id] = s.state
      var was = lastStates[s.id]
      if (root.claudeToasts && s.state === "needs" && was !== undefined && was !== "needs" && !s.focused) {
        var what = reasonText[s.reason] || (s.detail ? s.detail : "is waiting on you")
        root.alert = {
          title: (s.agentName || "Claude") + " needs you",
          detail: (s.label || s.project || "A session") + " " + what,
          session: s
        }
        alertTimer.restart()
      }
      // The session it was about stopped waiting, or you went to it.
      if (root.alert && root.alert.session && root.alert.session.id === s.id && (s.state !== "needs" || s.focused))
        root.alert = null
    }
    if (root.alert && root.alert.session && next[root.alert.session.id] === undefined) root.alert = null
    lastStates = next
  }
  Timer {
    id: alertTimer
    interval: 9000
    onTriggered: root.alert = null
  }

  function openConversations() {
    Quickshell.execDetached(["omarchy-launch-or-focus-tui", "--app-id=org.omarchy.claude-conversations", "claude-conversations"])
  }

  // ---- open the notch from a key or a script:
  //   omarchy-shell mike.notch toggle | open | close
  property bool pinned: false
  ShellIpc {
    target: "mike.notch"
    function toggle(): void { root.pinned = !root.pinned }
    function open(): void { root.pinned = true }
    function close(): void { root.pinned = false }
    // Full screen (windows under the notch) or the notch's own strip.
    function screen(): void { root.setPref("windowsUnderNotch", !root.windowsUnderNotch) }
    // Show what a "Claude needs you" toast looks like.
    function previewSessions(): void { root.previewSessions() }
    // The family Omarchy's "monospace" resolves to in this shell (for testing
    // `notch-look font`).
    function fontCheck(): string { return fontProbe.fontInfo.family }
    // The top bar's editor.
    function edit(): void { root.openEditor() }
    // Open (or close) a corner's panel on the focused screen as a click on
    // its row does (for testing): wifi, bluetooth, battery or volume.
    function cornerPanel(id: string): string {
      var widgetId = root.cornerPanels[id]
      if (!widgetId) return "no panel for " + id
      var list = notches.instances
      var name = root.focusedScreenName()
      for (var i = 0; i < list.length; i++) {
        var w = list[i]
        if (!w || (list.length > 1 && w.screenName !== name)) continue
        var ear = w.rightCorner.items.indexOf(id) !== -1 ? w.rightCorner : w.leftCorner
        w.openFromCorner(ear, widgetId)
        return ear.side + " corner on " + w.screenName
      }
      return "no screen"
    }
    // Which window a tap on the music would go to, without going (for
    // testing; the answer lands a moment later: run it twice).
    function playerWindow(): string {
      var p = root.player
      if (!p) return "no player"
      raiseProbe.track = String(p.trackTitle || "")
      raiseProbe.app = String(p.desktopEntry || p.identity || "")
      raiseProbe.focus = false
      if (!raiseProbe.running) raiseProbe.running = true
      return root.lastPlayerWindow || "looking"
    }
    // What the bar sees (for testing).
    function privacyState(): string { return JSON.stringify(root.privacy) }
    function notificationsState(): string { return JSON.stringify(root.notifications.slice(0, 3)) }
    function workspacesState(): string {
      var out = []
      var list = notches.instances
      for (var i = 0; i < list.length; i++) out.push({ screen: list[i].screenName, dots: list[i].wsDots })
      return JSON.stringify(out)
    }
    // Made-up sessions, notifications and privacy dots, and no network name,
    // for a minute and a half: for screenshots.
    function showcase(): void { root.previewSessions(); root.showcase = true; showcaseEnd.restart() }
    function showcaseEnd(): void { root.showcase = false; root.showCornerSide = ""; root.showcaseStyle = "" }
    function loadTest(on: bool): void {
      root.loadTest = on
      root.agentsPreview = on ? ({ counts: {}, sessions: [
        { id: "t1", agent: "claude", agentName: "Claude", label: "Load test one", state: "working" },
        { id: "t2", agent: "claude", agentName: "Claude", label: "Load test two", state: "working" },
        { id: "t3", agent: "codex", agentName: "Codex", label: "Load test three", state: "working" }] }) : null
    }
    // The showcase attached or floating ("attached", "floating", or "" for yours).
    function showcaseStyle(style: string): void { root.showcaseStyle = style }
    // Hold a corner open ("left", "right" or "" for neither), for screenshots.
    function showCorner(side: string): void { root.showCornerSide = side; if (side) showcaseEnd.restart() }
    // A low-battery warning, to see it.
    function previewLowBattery(): void { root.lowBatteryAlert = true; lowBatteryEnd.restart() }
    // Where things stand (for testing).
    function cornersState(): string {
      var out = []
      var list = notches.instances
      for (var i = 0; i < list.length; i++) {
        var w = list[i]
        out.push({ screen: w.screenName, cornersOn: w.cornersOn, fullscreen: w.fullscreenHere,
          left: w.leftCorner.shown, right: w.rightCorner.shown, notchItems: w.notchItems,
          holdsPopout: w.holdsPopout, rightHeld: w.rightCorner.holdClosed })
      }
      return JSON.stringify({ glass: root.glass, solid: Theme.solid, popout: !!root.activePopout, screens: out })
    }
    // The network speed the bar sees (for testing; keeps it measuring 10 s).
    function netState(): string {
      root.netWatch = true
      netWatchEnd.restart()
      return JSON.stringify({ iface: root.netInterface, down: Math.round(root.netRates.down), up: Math.round(root.netRates.up) })
    }
    function editClose(): void { root.editorOpen = false }
    function previewToast(): void {
      root.alert = { title: "Claude needs you", detail: "This is what a waiting session looks like", session: null }
      alertTimer.restart()
    }
  }

  // ---- `omarchy toggle bar` hides the notch too
  Process {
    id: hiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: hiddenProbe.running = true
  }
  ShellIpc {
    target: "omarchy.bar"
    function syncHidden(): void { hiddenProbe.running = true }
  }

  // ---- Wi-Fi, Bluetooth, battery, volume: the notch's own icons draw these
  readonly property var netDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: {
    for (var i = 0; i < netDevices.length; i++) if (netDevices[i] && netDevices[i].type === DeviceType.Wifi) return netDevices[i]
    return null
  }
  readonly property var wiredDevice: {
    for (var i = 0; i < netDevices.length; i++) if (netDevices[i] && netDevices[i].type === DeviceType.Wired) return netDevices[i]
    return null
  }
  readonly property var wifiStatus: {
    if (wiredDevice && wiredDevice.connected) return { kind: "ethernet", strength: 1 }
    if (wifiDevice && wifiDevice.connected) {
      var nets = wifiDevice.networks ? wifiDevice.networks.values : []
      var strength = 1
      var name = ""
      for (var i = 0; i < nets.length; i++) {
        if (nets[i] && nets[i].connected) {
          var raw = Number(nets[i].signalStrength || 0)
          strength = raw > 1 ? raw / 100 : raw
          name = String(nets[i].name || "")
          break
        }
      }
      return { kind: "wifi", strength: strength, name: name }
    }
    return { kind: "none", strength: 0, enabled: !!Networking.wifiEnabled }
  }
  readonly property var batteryStatus: {
    var d = UPower.displayDevice
    if (!d || !d.isPresent) return { present: false }
    var level = Number(d.percentage || 0)
    if (level > 1) level = level / 100
    var charging = d.state === UPowerDeviceState.Charging || (d.state === UPowerDeviceState.FullyCharged && !UPower.onBattery)
    return {
      present: true, level: level, charging: charging,
      full: d.state === UPowerDeviceState.FullyCharged || (!UPower.onBattery && level >= 0.995),
      timeToEmpty: Number(d.timeToEmpty || 0),
      timeToFull: Number(d.timeToFull || 0)
    }
  }
  readonly property var bluetoothStatus: {
    var adapter = Bluetooth.defaultAdapter
    var devices = Bluetooth.devices ? Bluetooth.devices.values : []
    var connected = false
    var device = ""
    for (var i = 0; i < devices.length; i++) if (devices[i] && devices[i].connected) {
      connected = true
      device = String(devices[i].name || devices[i].deviceName || "")
      break
    }
    return { enabled: !!(adapter && adapter.enabled), connected: connected, device: device }
  }
  readonly property var status: ({
    wifi: wifiStatus,
    battery: batteryStatus,
    bluetooth: bluetoothStatus,
    volume: { level: volume, muted: muted },
    net: netRates,
    claude: {
      working: (claude.counts.working || 0) + (claude.counts.watching || 0),
      needs: claude.counts.needs || 0,
      agent: claude.sessions.length > 0 && (claude.sessions[0].state === "needs" || claude.sessions[0].state === "working" || claude.sessions[0].state === "watching")
        ? (claude.sessions[0].agent || "claude") : defaultAgent
    },
    usage: usage
  })

  // ---- how fast the network is going, from /proc/net/dev: only while
  // something shows it (the speed item, or an open corner with Wi-Fi in it)
  property var netRates: ({ down: 0, up: 0 })
  property var netLast: null
  property int openCorners: 0
  readonly property bool netNeeded: {
    var l = barLayout
    var all = [].concat(l.left, l.center, l.right)
    return all.indexOf("speed") !== -1 || openCorners > 0 || netWatch
  }
  // `omarchy-shell mike.notch netState` (for testing): watch for ten seconds.
  property bool netWatch: false
  Timer { id: netWatchEnd; interval: 10000; onTriggered: root.netWatch = false }
  onNetNeededChanged: if (!netNeeded) { netLast = null; netRates = ({ down: 0, up: 0 }) }
  readonly property string netInterface: {
    var d = wiredDevice && wiredDevice.connected ? wiredDevice : (wifiDevice && wifiDevice.connected ? wifiDevice : null)
    return d && d.name ? String(d.name) : ""
  }
  function readNet(text) {
    var rx = 0, tx = 0
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([^:\s]+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/)
      if (!m) continue
      var name = m[1]
      if (netInterface ? name !== netInterface : /^(lo|docker|veth|br-|virbr|vnet|tailscale|wg|tun)/.test(name)) continue
      rx += Number(m[2])
      tx += Number(m[3])
    }
    var now = Date.now()
    if (netLast && now > netLast.at) {
      var dt = (now - netLast.at) / 1000
      netRates = { down: Math.max(0, (rx - netLast.rx) / dt), up: Math.max(0, (tx - netLast.tx) / dt) }
    }
    netLast = { at: now, rx: rx, tx: tx }
  }
  Process {
    id: netProbe
    command: ["cat", "/proc/net/dev"]
    stdout: StdioCollector { onStreamFinished: root.readNet(text) }
  }
  Timer {
    interval: root.lean ? 3000 : 1500
    repeat: true
    running: root.netNeeded
    triggeredOnStart: true
    onTriggered: if (!netProbe.running) netProbe.running = true
  }

  // ---- the machine, for the open notch's system card: the processor, memory,
  // disk and heat, every 2 s while a notch is open (every 30 s otherwise, so
  // it opens with recent numbers)
  property var system: ({ ready: false })
  property var cpuLast: null
  property int openNotches: 0
  function readSystem(text) {
    var next = { ready: true, cpu: system.cpu || 0, memUsed: 0, memTotal: 0, diskUsed: 0, diskTotal: 0, temp: -1, uptime: 0 }
    var temps = ({})
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f[0] === "cpu") {
        var total = 0
        for (var k = 1; k < f.length; k++) total += Number(f[k]) || 0
        var idle = (Number(f[4]) || 0) + (Number(f[5]) || 0)
        if (cpuLast && total > cpuLast.total) next.cpu = Math.max(0, Math.min(1, 1 - (idle - cpuLast.idle) / (total - cpuLast.total)))
        cpuLast = { total: total, idle: idle }
      }
      else if (f[0] === "MemTotal:") next.memTotal = Number(f[1]) * 1024
      else if (f[0] === "MemAvailable:") next.memAvail = Number(f[1]) * 1024
      else if (f[0] === "disk") { next.diskTotal = Number(f[1]) || 0; next.diskUsed = Number(f[2]) || 0 }
      else if (f[0] === "temp" && f.length >= 3) temps[f[1]] = Number(f[2]) / 1000
      else if (f[0] === "up") next.uptime = Number(f[1]) || 0
    }
    next.memUsed = Math.max(0, next.memTotal - (next.memAvail || 0))
    var order = ["x86_pkg_temp", "TCPU", "cpu_thermal", "k10temp", "coretemp", "acpitz"]
    for (var j = 0; j < order.length; j++) if (temps[order[j]] > 0) { next.temp = temps[order[j]]; break }
    system = next
  }
  Process {
    id: systemProbe
    command: ["bash", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; "
      + "df -B1 --output=size,used / | tail -1 | sed 's/^/disk /'; "
      + "for z in /sys/class/thermal/thermal_zone*; do echo \"temp $(cat $z/type 2>/dev/null) $(cat $z/temp 2>/dev/null)\"; done; "
      + "echo \"up $(cut -d' ' -f1 /proc/uptime)\""]
    stdout: StdioCollector { onStreamFinished: root.readSystem(text) }
  }
  Timer {
    interval: root.openNotches > 0 ? (root.lean ? 5000 : 2000) : (root.lean ? 120000 : 30000)
    repeat: true
    running: root.barLayout.cards.indexOf("system") !== -1
    triggeredOnStart: true
    onTriggered: if (!systemProbe.running) systemProbe.running = true
  }
  // Opening a notch: fresh numbers at once.
  onOpenNotchesChanged: if (openNotches > 0 && !systemProbe.running) systemProbe.running = true

  // ---- how it looks: frosted (the default) or solid, for the notch and the
  // corners
  readonly property string glass: prefs.glass === "solid" ? "solid" : "frosted"
  // Attached to the top edge (the default), floating a little below it, or
  // unified (one strip across the top that the notch and corners hang from).
  readonly property string barStyle: {
    var st = showcase && showcaseStyle ? showcaseStyle : String(prefs.notchStyle || "")
    return st === "floating" || st === "unified" ? st : "attached"
  }
  readonly property bool floating: barStyle === "floating"
  readonly property bool unified: barStyle === "unified"
  // Every running agent in the closed notch, not just the one that matters
  // most (the editor's switch; off unless switched on).
  readonly property bool allAgents: prefs.allAgents === true
  // The showcase's own attached or floating ("" = yours).
  property string showcaseStyle: ""
  readonly property real topGap: floating ? 8 : 0
  Binding { target: Theme; property: "solid"; value: root.glass === "solid" }

  // ---- privacy dots: the microphone (orange), the camera (green) and a
  // screen recording (red), while something uses them. Checked every 3 s,
  // only while the privacy item is on the bar.
  property var privacy: ({ mic: false, camera: false, screen: false, micApps: "", cameraApp: "" })
  readonly property bool privacyNeeded: {
    var l = barLayout
    return [].concat(l.left, l.center, l.right).indexOf("privacy") !== -1
  }
  onPrivacyNeededChanged: if (!privacyNeeded) privacy = ({ mic: false, camera: false, screen: false, micApps: "", cameraApp: "" })
  function readPrivacy(text) {
    var next = { mic: false, camera: false, screen: false, micApps: "", cameraApp: "" }
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.indexOf("mic ") === 0) { next.micApps = line.slice(4).trim(); next.mic = next.micApps.length > 0 }
      else if (line.indexOf("cam ") === 0) { next.camera = true; next.cameraApp = line.slice(4).trim() }
      else if (line === "rec") next.screen = true
    }
    privacy = next
  }
  Process {
    id: privacyProbe
    command: ["bash", "-c",
      // Apps recording from a microphone (not the shell's own level meters).
      "pactl -f json list source-outputs 2>/dev/null | jq -r '[.[] | .properties | select(((.\"application.process.binary\" // \"\") | test(\"^(quickshell|qs|pavucontrol|wireplumber|pipewire)$\")) | not) | (.\"application.name\" // .\"application.process.binary\" // \"An app\")] | unique | join(\", \") | \"mic \" + .' 2>/dev/null; "
      // A camera held open by any process of yours.
      + "f=$(find /proc/[0-9]*/fd -lname '/dev/video*' -print -quit 2>/dev/null); "
      + "[ -n \"$f\" ] && echo \"cam $(cat /proc/$(echo $f | cut -d/ -f3)/comm 2>/dev/null)\"; "
      // Omarchy's own screen recording.
      + "omarchy-capture-screenrecording --status >/dev/null 2>&1 && echo rec; true"]
    stdout: StdioCollector { onStreamFinished: root.readPrivacy(text) }
  }
  Timer {
    interval: root.lean ? 6000 : 3000
    repeat: true
    running: root.privacyNeeded
    triggeredOnStart: true
    onTriggered: if (!privacyProbe.running) privacyProbe.running = true
  }

  // ---- notification history: what Omarchy's notifications showed (it keeps
  // them in history.json, the ones still up in live.json), newest first, for
  // the open notch's notifications card. Clear hides what's there now.
  property var notifHistory: []
  property var notifLive: []
  function readRows(text) {
    try { var rows = JSON.parse(text); return Array.isArray(rows) ? rows : [] } catch (e) { return [] }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.notifHistory = root.readRows(text())
    onLoadFailed: root.notifHistory = []
  }
  readonly property real notificationsClearedAt: Number(prefs.notificationsClearedAt || 0)
  // `omarchy-shell mike.notch showcase` (or `notch-look showcase`): a minute
  // and a half of made-up sessions, notifications and privacy dots, and no
  // network name, for screenshots that show nothing of yours.
  property bool showcase: false
  Timer { id: showcaseEnd; interval: 90000; onTriggered: { root.showcase = false; root.showCornerSide = ""; root.showcaseStyle = "" } }
  readonly property var showcaseNotifications: {
    var now = Date.now() / 1000
    return [
      { key: "s1", app: "Telegram", glyph: "", summary: "Sam", body: "Are we still on for 7? I booked the place by the river", ts: now - 60, live: false },
      { key: "s2", app: "Calendar", glyph: String.fromCodePoint(0xF00ED), summary: "Design review in 10 minutes", body: "Room 3 · with Alex and Priya", ts: now - 900, live: false },
      { key: "s3", app: "Claude", glyph: "", summary: "Claude needs you", body: "Refactor the notch hover timing needs permission", ts: now - 2400, live: false },
      { key: "s4", app: "omarchy-action", glyph: String.fromCodePoint(0xF0A1C), summary: "Screen recording saved", body: "0:42 · 6.1 MB", ts: now - 5400, live: false },
      { key: "s5", app: "Spotify", glyph: "", summary: "Now playing", body: "Lose My Mind", ts: now - 7200, live: false },
      { key: "s6", app: "Mail", glyph: "", summary: "Invoice #1042", body: "Paid, thank you", ts: now - 86000, live: false }
    ]
  }
  readonly property var notifications: showcase ? showcaseNotifications : realNotifications
  // The side a corner is held open on for screenshots ("left" | "right").
  property string showCornerSide: ""
  readonly property var realNotifications: {
    var seen = ({})
    var out = []
    var all = [].concat(notifLive, notifHistory)
    for (var i = 0; i < all.length; i++) {
      var r = all[i]
      if (!r || !r.key || seen[r.key]) continue
      seen[r.key] = true
      var ts = Number(r.ts || 0)
      if (ts <= notificationsClearedAt) continue
      out.push({
        key: String(r.key),
        app: String(r.app || r.source || ""),
        glyph: String(r.glyph || ""),
        summary: String(r.summary || ""),
        body: String(r.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(),
        ts: ts,
        live: !r.closed_ts
      })
    }
    out.sort(function(a, b) { return b.ts - a.ts })
    return out.slice(0, 40)
  }
  function clearNotifications() { setPref("notificationsClearedAt", Date.now() / 1000) }
  function showAllNotifications() { Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"]) }

  // ---- low battery: crossing 15% (and 5%) unplugged, the corner holding
  // the battery opens for a few seconds, red
  property real lastBatteryLevel: -1
  property bool lowBatteryAlert: false
  onBatteryStatusChanged: {
    var b = batteryStatus
    if (!b || !b.present) return
    var level = Number(b.level || 0)
    var was = lastBatteryLevel
    if (!b.charging && was > 0 && ((was > 0.15 && level <= 0.15) || (was > 0.05 && level <= 0.05))) {
      lowBatteryAlert = true
      lowBatteryEnd.restart()
    }
    if (b.charging) lowBatteryAlert = false
    lastBatteryLevel = level
  }
  Timer { id: lowBatteryEnd; interval: 6000; onTriggered: root.lowBatteryAlert = false }

  // ---- which screens get the corners: every one (""), or just one
  readonly property string cornerScreen: String(prefs.cornerScreen || "")
  readonly property bool cornerScreenPresent: {
    var list = Quickshell.screens
    for (var i = 0; i < list.length; i++) if (list[i].name === cornerScreen) return true
    return false
  }
  // For the editor: each screen, by a name people know it by.
  readonly property var screenChoices: Quickshell.screens.map(function(sc) {
    var n = String(sc.name || "")
    var friendly = /^eDP/.test(n) ? "Laptop" : (String(sc.model || "").trim() || n)
    return { id: n, name: friendly }
  })

  // ---- workspaces: each monitor's own block of ten (Omarchy keeps which
  // block is whose in monitor-workspaces)
  property var wsBlocks: ({})
  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var next = ({})
      var lines = String(text()).split("\n")
      for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split("\t")
        if (f.length >= 3 && f[1] !== "") next[f[1]] = parseInt(f[0], 10)
      }
      root.wsBlocks = next
    }
    onLoadFailed: root.wsBlocks = ({})
  }

  // ---- what goes where: the corners and the closed notch (Layout.js), saved
  // in prefs.json and changed with the editor
  // The showcase shows the default layout, whatever yours is (nothing saved).
  readonly property var barLayout: showcase ? Layout.defaults() : Layout.normalize(prefs.layout)
  function setLayout(next) { setPref("layout", Layout.normalize(next)) }

  // The session that matters most, for the agents item in a corner.
  readonly property var lead: {
    var list = claude.sessions
    for (var i = 0; i < list.length; i++) if (list[i].state === "needs") return list[i]
    for (var j = 0; j < list.length; j++) if (list[j].state === "working" || list[j].state === "watching") return list[j]
    return { agent: defaultAgent, state: "idle" }
  }

  // A corner's row was clicked: open Omarchy's own panel for it, from the
  // corner itself (the window's openFromCorner), not the notch.
  readonly property var cornerPanels: ({ wifi: "omarchy.network", bluetooth: "omarchy.bluetooth", battery: "omarchy.power", volume: "omarchy.audio" })
  function itemAction(id, action, value, win, ear) {
    if (action === "speedtest") { Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy.speedtest"]); return }
    if (action === "mute") { toggleMode("mute"); return }
    if (action === "volume") { setVolume(value); return }
    if (action !== "open") return
    if (id === "agents") { openConversations(); return }
    if (cornerPanels[id] && win && ear) win.openFromCorner(ear, cornerPanels[id])
  }
  // A scroll over a corner: tracks over the music, workspaces over the dots,
  // the volume anywhere else. Up is back (or louder).
  function wheelAction(kind, steps, win) {
    if (kind === "tracks") mediaAction(steps > 0 ? "previous" : "next")
    else if (kind === "workspaces" && win) win.stepWorkspace(steps)
    else if (kind === "volume") setVolume(volume + steps * 0.05)
  }
  function isInside(item, ancestor) {
    for (var p = item; p; p = p.parent) if (p === ancestor) return true
    return false
  }

  // ---- the editor: right-click the notch or a corner, or
  // `omarchy-shell mike.notch edit` (`notch-look edit`)
  property bool editorOpen: false
  property var editorScreen: null
  function openEditor() {
    var name = focusedScreenName()
    var screens = Quickshell.screens
    var found = screens.length ? screens[0] : null
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) found = screens[i]
    editorScreen = found
    editorOpen = true
  }
  // The open notch's buttons, in order, with their names.
  readonly property var editorButtons: {
    var registry = barWidgetRegistry
    var revision = registry ? registry.revision : 0
    return sections.strip.map(function(e) {
      var meta = registry && typeof registry.metadataFor === "function" ? registry.metadataFor(e.id) : null
      var name = meta && meta.displayName ? String(meta.displayName) : ""
      if (!name) {
        // Omarchy's own by what they are (omarchy.weather: "Weather"), anyone
        // else's by whose they are (superwhisper.panel: "Superwhisper").
        var parts = String(e.id).split(".")
        name = (parts[0] === "omarchy" && parts.length > 1 ? parts.slice(1).join(" ") : parts[0]).replace(/-/g, " ")
      }
      return { id: e.id, name: name.charAt(0).toUpperCase() + name.slice(1) }
    })
  }
  // A button dragged to `index` (counted without it): put it before the
  // button now there, or after the last one, through Omarchy's own bar
  // command so shell.json stays Omarchy's to write.
  function moveButton(id, index) {
    var rest = editorButtons.filter(function(b) { return b.id !== id })
    if (rest.length === 0) return
    if (index < rest.length) Quickshell.execDetached(["omarchy-bar", "move", id, "--before", rest[index].id])
    else Quickshell.execDetached(["omarchy-bar", "move", id, "--after", rest[rest.length - 1].id])
  }

  // ---- saving battery: unplugged, everything that checks on things does
  // so less often (agents every 3 s instead of every second, the machine
  // every 5 s, the network every 3 s, the privacy dots every 6 s)
  readonly property bool saving: UPower.onBattery
  // Lean: unplugged, or a modest machine (see motionLevel), plugged in or
  // not: there every process the bar starts counts, so it checks less often.
  readonly property bool lean: saving || modestMachine
  // A new interval needs a new agents.py; it restarts on its own after exiting.
  onLeanChanged: sessions.running = false

  // ---- the volume (the corners' volume item and scroll)
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property real volume: sink && sink.audio ? Math.min(1, sink.audio.volume) : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)

  function toggleMode(mode) {
    if (mode === "mute" && sink && sink.audio) sink.audio.muted = !sink.audio.muted
    else if (mode === "screen") setPref("windowsUnderNotch", !windowsUnderNotch)
  }
  function setVolume(value) {
    if (!sink || !sink.audio) return
    sink.audio.volume = Math.max(0, Math.min(1, value))
    if (value > 0 && sink.audio.muted) sink.audio.muted = false
  }

  // Claude plan usage, from the file Omarchy's agents panel keeps current.
  property var usage: ({ ready: false })
  FileView {
    path: root.home + "/.local/state/omarchy/agents/usage/claude.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(text())
        var limits = Array.isArray(data.limits) ? data.limits : []
        var session = -1, weekly = -1
        for (var i = 0; i < limits.length; i++) {
          var label = String(limits[i].label || "")
          if (session < 0 && label.indexOf("5-hour") !== -1) session = Number(limits[i].percent)
          else if (weekly < 0 && label.indexOf("Weekly (7-day)") !== -1) weekly = Number(limits[i].percent)
        }
        root.usage = { ready: session >= 0 || weekly >= 0, session: Math.max(0, session), weekly: Math.max(0, weekly) }
      } catch (e) {}
    }
  }

  // ---- one notch per screen
  Variants {
    id: notches
    model: Quickshell.screens

    PanelWindow {
      id: win

      required property var modelData
      screen: modelData
      readonly property string screenName: modelData ? modelData.name : ""
      readonly property real thickness: root.topGap + (notch.open ? notch.expandedHeight : notch.collapsedHeight)


      // A panel summoned from a shortcut: open the notch, then the panel.
      property bool summonHold: false
      property var summonTarget: null
      function summon(item) {
        summonHold = true
        summonTarget = item
        summonTimer.restart()
      }
      Timer {
        id: summonTimer
        interval: 260 * root.motion + 20
        onTriggered: {
          if (win.summonTarget && typeof win.summonTarget.open === "function") win.summonTarget.open()
          win.summonTarget = null
          summonRelease.restart()
        }
      }
      // If no panel claimed the notch, let it close again.
      Timer {
        id: summonRelease
        interval: 1500
        onTriggered: if (!root.activePopout) win.summonHold = false
      }
      Connections {
        target: root
        function onActivePopoutChanged() { if (!root.activePopout) win.summonHold = false }
      }

      // A widget's panel or a tray app's menu is open: keep the notch open.
      // A panel opened from a corner keeps the notch shut.
      readonly property bool holdsPopout: {
        var owner = root.activePopout
        if (!owner) return false
        if (root.isInside(owner, leftEar) || root.isInside(owner, rightEar) || root.isInside(owner, notch.closedRowItem)) return false
        if (Quickshell.screens.length <= 1) return true
        return root.targetBelongsToWindow(owner, win)
      }

      readonly property alias leftCorner: leftEar
      readonly property alias rightCorner: rightEar

      // The corners show only with the notch's own strip, and not over an app
      // that's fullscreen (Super+F): then only the notch shows, holding the
      // corners' items too.
      readonly property var hyprMonitor: Hyprland.monitorFor(win.screen)
      readonly property bool fullscreenHere: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
      readonly property bool cornersOn: (!root.windowsUnderNotch || root.showcase) && !fullscreenHere
        && (root.cornerScreen === "" || !root.cornerScreenPresent || root.cornerScreen === win.screenName)

      // This monitor's workspaces as dots: the first five of its block, any
      // other of its block that exists, then visitors (Omarchy's own rule).
      readonly property int activeWs: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : -1
      readonly property var wsDots: {
        if (!hyprMonitor) return []
        var name = hyprMonitor.name
        var active = activeWs
        var block = root.wsBlocks[name] !== undefined ? root.wsBlocks[name] : (active > 0 ? Math.floor((active - 1) / 10) : 0)
        var base = block * 10
        var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
        var guests = []
        var byId = ({})
        var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < values.length; i++) {
          var ws = values[i]
          if (!ws || ws.id <= 0) continue
          byId[ws.id] = ws
          if (Math.floor((ws.id - 1) / 10) === block) { if (ids.indexOf(ws.id) === -1) ids.push(ws.id) }
          else if (ws.monitor && ws.monitor.name === name) guests.push(ws.id)
        }
        ids.sort(function(a, b) { return a - b })
        guests.sort(function(a, b) { return a - b })
        return ids.concat(guests).map(function(id) {
          var w = byId[id]
          var count = w && w.toplevels ? w.toplevels.values.length : 0
          return { id: id, slot: Math.floor((id - 1) / 10) === block ? (id - 1) % 10 + 1 : id, active: id === active, occupied: count > 0 }
        })
      }
      function focusWorkspace(id) {
        var name = hyprMonitor ? hyprMonitor.name : ""
        var block = root.wsBlocks[name] !== undefined ? root.wsBlocks[name] : (activeWs > 0 ? Math.floor((activeWs - 1) / 10) : 0)
        var expr = Math.floor((id - 1) / 10) === block
          ? "o.workspaces.focus(" + ((id - 1) % 10 + 1) + ", \"" + name + "\")"
          : "hl.dsp.focus({ workspace = \"" + id + "\" })"
        var command = "hyprctl dispatch " + Util.shellQuote(expr)
        if (hyprMonitor && !hyprMonitor.focused)
          command = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + name + "\" })") + " >/dev/null && " + command
        root.run(command)
      }
      // Next or previous workspace, for a scroll over the dots.
      function stepWorkspace(steps) {
        var dots = wsDots
        var at = -1
        for (var i = 0; i < dots.length; i++) if (dots[i].active) at = i
        if (at < 0 || dots.length === 0) return
        var to = Math.max(0, Math.min(dots.length - 1, at - steps))
        if (to !== at) focusWorkspace(dots[to].id)
      }
      // The bar's status, with this monitor's workspaces and the privacy dots.
      readonly property var screenStatus: {
        var out = ({})
        var st = root.status
        for (var k in st) out[k] = st[k]
        out.workspaces = wsDots
        out.privacy = root.showcase ? ({ mic: true, micApps: "Zoom", camera: true, cameraApp: "Zoom", screen: false }) : root.privacy
        if (root.showcase && st.wifi && st.wifi.kind === "wifi") {
          var w = ({})
          for (var j in st.wifi) w[j] = st.wifi[j]
          w.name = "Home"
          out.wifi = w
        }
        return out
      }
      // Omarchy's widgets whose items show in a corner here: their buttons
      // leave the open notch (the corner opens their panels instead).
      readonly property var cornerWidgets: {
        if (!cornersOn) return []
        var out = []
        var items = [].concat(root.barLayout.left, root.barLayout.right)
        for (var i = 0; i < items.length; i++) if (root.cornerPanels[items[i]]) out.push(root.cornerPanels[items[i]])
        return out
      }
      function cornerFor(widgetId) {
        if (cornerWidgets.indexOf(widgetId) === -1) return null
        for (var item in root.cornerPanels) {
          if (root.cornerPanels[item] !== widgetId) continue
          if (root.barLayout.right.indexOf(item) !== -1) return rightEar
          if (root.barLayout.left.indexOf(item) !== -1) return leftEar
        }
        return null
      }
      readonly property var notchItems: cornersOn ? root.barLayout.center
        : [].concat(root.barLayout.left, root.barLayout.center, root.barLayout.right)

      // A bar widget the editor placed on the closed bar ("w:<id>"): Omarchy's
      // own widget, bare, with the settings it has in the bar's layout (a
      // third party's too, such as a workspace grid).
      Component {
        id: placedWidgetComponent
        WidgetHost { register: false; bare: true }
      }
      function hostBarWidget(id, parentItem) {
        var all = [].concat(root.sections.strip, root.sections.menu)
        var entry = null
        for (var i = 0; i < all.length; i++) if (all[i].id === id) entry = all[i]
        return placedWidgetComponent.createObject(parentItem, {
          host: root, screenName: win.screenName, window: win, modelData: entry || ({ id: id })
        })
      }
      readonly property var widgetFactory: function(id, parentItem) { return win.hostBarWidget(id, parentItem) }
      readonly property var stripHidden: win.cornerWidgets.concat(Layout.placedWidgets(root.barLayout))

      // Omarchy's widgets for the corners' panels, made the first time one is
      // asked for and kept: "left:omarchy.network" -> WidgetHost.
      property var cornerHosts: ({})
      Component {
        id: cornerHostComponent
        WidgetHost { register: false }
      }
      function openFromCorner(ear, widgetId) {
        var key = ear.side + ":" + widgetId
        var h = cornerHosts[key]
        if (!h) {
          h = cornerHostComponent.createObject(ear.panelSlot, {
            host: root, screenName: win.screenName, window: win, modelData: ({ id: widgetId })
          })
          if (!h) return
          var next = ({})
          for (var k in cornerHosts) next[k] = cornerHosts[k]
          next[key] = h
          cornerHosts = next
        }
        cornerOpen.target = h
        cornerOpen.tries = 0
        cornerOpen.restart()
      }
      // The widget may still be loading: open it once it's there.
      Timer {
        id: cornerOpen
        property var target: null
        property int tries: 0
        interval: 30
        onTriggered: {
          var item = target ? target.item : null
          if (item && typeof item.open === "function") {
            if (item.opened === true && typeof item.close === "function") item.close()
            else item.open()
          } else if (++tries < 20) restart()
        }
      }

      anchors { top: true; left: true; right: true }
      // Only as tall as the closed bar while nothing is open or moving: every
      // repaint (a step of the music's bars, a working agent) repaints the
      // whole window and Hyprland re-blurs it, so a short window keeps those
      // cheap. It grows the moment something opens.
      readonly property bool busy: notch.open || notch.progress > 0.001 || notch.alertProgress > 0.001
        || leftEar.open || leftEar.progress > 0.001 || rightEar.open || rightEar.progress > 0.001
        || win.summonHold || win.holdsPopout
      // It stays tall a couple of seconds after closing, so hovering in and
      // out doesn't make Hyprland hand over new buffers each time.
      property bool roomyHold: false
      onBusyChanged: if (busy) { roomyHold = true; roomyRelease.stop() } else roomyRelease.restart()
      Timer { id: roomyRelease; interval: 2500; onTriggered: win.roomyHold = false }
      readonly property bool roomy: busy || roomyHold
      readonly property real fullHeight: Math.max(notch.implicitHeight + root.topGap, leftEar.implicitHeight, rightEar.implicitHeight) + 40
      readonly property real compactHeight: Math.max(root.topGap, leftEar.inset) + notch.collapsedHeight + 14
      implicitHeight: roomy ? fullHeight : compactHeight
      color: "transparent"
      // Full screen (the editor's switch): no reserved strip, every window
      // gets the whole screen and the notch sits over it like a camera notch,
      // see-through until it's used (unless the look is Solid: then it stays
      // solid). Otherwise the notch keeps a strip and windows start below it.
      exclusionMode: root.windowsUnderNotch || root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
      exclusiveZone: root.windowsUnderNotch ? 0 : notch.collapsedHeight + root.topGap
      margins.top: root.barHidden ? -implicitHeight : 0
      WlrLayershell.namespace: "mike-notch"
      // Above everything, fullscreen apps included.
      WlrLayershell.layer: WlrLayer.Overlay

      // Only the slab takes the pointer. Exact numbers rather than an item: an
      // item's region doesn't follow its parent moving.
      mask: Region {
        x: Math.floor((win.width - notch.bodyW) / 2)
        y: Math.floor(notch.y)
        width: Math.ceil(notch.bodyW)
        height: Math.max(1, Math.ceil(notch.bodyH))
        regions: [
          Region {
            x: Math.floor(leftEar.inset + leftEar.extraX)
            y: Math.floor(leftEar.inset)
            width: leftEar.covered ? 0 : Math.ceil(leftEar.bodyW)
            height: Math.ceil(leftEar.bodyH)
          },
          Region {
            x: Math.floor(win.width - rightEar.bodyW - rightEar.inset - rightEar.extraX)
            y: Math.floor(rightEar.inset)
            width: rightEar.covered ? 0 : Math.ceil(rightEar.bodyW)
            height: Math.ceil(rightEar.bodyH)
          }
        ]
      }

      // Unified: one long bar across the top, a gap from either side, that
      // stretches to the screen's edges while the notch or a corner is open,
      // so what opens hangs from one piece (UnifiedStrip.qml).
      property real stripT: root.unified && (notch.open || leftEar.open || rightEar.open) ? 1 : 0
      Behavior on stripT { enabled: root.motion > 0; NumberAnimation { duration: win.stripT < 0.5 ? Motion.open : Motion.close; easing.type: Easing.OutCubic } }
      readonly property real stripGap: 10
      // How far in from the side the corners sit while the strip keeps its gap.
      readonly property real stripIn: root.unified ? (stripGap + 12) * (1 - stripT) : 0
      UnifiedStrip {
        visible: root.unified
        screenWidth: win.width
        gap: win.stripGap
        barHeight: notch.collapsedHeight
        expand: win.stripT
        opacity: notch.opacity
        leftDrop: ({ width: leftEar.bodyW, height: leftEar.covered ? 0 : leftEar.bodyH - notch.collapsedHeight })
        centerDrop: ({ width: notch.bodyW, height: notch.bodyH - notch.collapsedHeight })
        rightDrop: ({ width: rightEar.bodyW, height: rightEar.covered ? 0 : rightEar.bodyH - notch.collapsedHeight })
      }

      Notch {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.topGap
        floating: root.floating
        unified: root.unified
        widgetFactory: win.widgetFactory
        allAgents: root.allAgents
        maxExpandedWidth: Math.max(600, win.width - 48)
        motion: root.motion
        status: win.screenStatus
        alert: root.alert
        onAlertDismissed: root.alert = null
        notificationsShowing: root.notificationsShowing
        seeThroughWhenIdle: root.windowsUnderNotch && !root.showcase && root.glass !== "solid"
        defaultAgent: root.defaultAgent
        forceOpen: root.pinned && (Quickshell.screens.length <= 1 || win.screenName === root.focusedScreenName())
        hold: win.holdsPopout || win.summonHold
        now: clock.date
        clockFormat: root.clockFormat
        media: root.media
        claude: root.claude
        items: win.notchItems
        cards: root.barLayout.cards
        system: root.system
        notifications: root.notifications
        onNotificationsCleared: root.clearNotifications()
        onNotificationsShowAll: root.showAllNotifications()
        onWorkspaceRequested: function(id) { win.focusWorkspace(id) }
        onOpenChanged: root.openNotches = Math.max(0, root.openNotches + (open ? 1 : -1))
        onEditRequested: root.openEditor()
        onMediaRequested: function(action) { root.mediaAction(action) }
        onSessionRequested: function(session) { root.focusSession(session) }
        onConversationsRequested: root.openConversations()
      }

      // The corners: music on the left, Wi-Fi, Bluetooth and the battery on the
      // right, by default (the editor moves things around).
      Ear {
        id: leftEar
        floating: root.floating
        unified: root.unified
        extraX: win.stripIn
        widgetFactory: win.widgetFactory
        sessions: root.claude.sessions
        allAgents: root.allAgents
        covered: notch.progress > 0.2 && leftEar.inset + leftEar.extraX + leftEar.bodyW + 8 > (win.width - notch.bodyW) / 2
        forceOpen: (root.lowBatteryAlert && items.indexOf("battery") !== -1) || root.showCornerSide === side
        onWorkspaceRequested: function(id) { win.focusWorkspace(id) }
        onWheelRequested: function(kind, steps) { root.wheelAction(kind, steps, win) }
        suppressed: !win.cornersOn
        holdClosed: !!root.activePopout && root.isInside(root.activePopout, leftEar)
        x: 0
        side: "left"
        items: root.barLayout.left
        status: win.screenStatus
        media: root.media
        now: clock.date
        clockFormat: root.clockFormat
        motion: root.motion
        lead: root.lead
        counts: root.claude.counts
        seeThroughWhenIdle: root.windowsUnderNotch && !root.showcase && root.glass !== "solid"
        onOpenChanged: root.openCorners = Math.max(0, root.openCorners + (open ? 1 : -1))
        Component.onDestruction: if (open) root.openCorners = Math.max(0, root.openCorners - 1)
        onMediaRequested: function(action, value) { root.mediaAction(action, value) }
        onItemRequested: function(itemId, action, value) { root.itemAction(itemId, action, value, win, leftEar) }
        onEditRequested: root.openEditor()
      }
      Ear {
        id: rightEar
        floating: root.floating
        unified: root.unified
        extraX: win.stripIn
        widgetFactory: win.widgetFactory
        sessions: root.claude.sessions
        allAgents: root.allAgents
        covered: notch.progress > 0.2 && rightEar.inset + rightEar.extraX + rightEar.bodyW + 8 > (win.width - notch.bodyW) / 2
        forceOpen: (root.lowBatteryAlert && items.indexOf("battery") !== -1) || root.showCornerSide === side
        onWorkspaceRequested: function(id) { win.focusWorkspace(id) }
        onWheelRequested: function(kind, steps) { root.wheelAction(kind, steps, win) }
        suppressed: !win.cornersOn
        holdClosed: !!root.activePopout && root.isInside(root.activePopout, rightEar)
        x: win.width - width
        side: "right"
        items: root.barLayout.right
        status: win.screenStatus
        media: root.media
        now: clock.date
        clockFormat: root.clockFormat
        motion: root.motion
        lead: root.lead
        counts: root.claude.counts
        seeThroughWhenIdle: root.windowsUnderNotch && !root.showcase && root.glass !== "solid"
        onOpenChanged: root.openCorners = Math.max(0, root.openCorners + (open ? 1 : -1))
        Component.onDestruction: if (open) root.openCorners = Math.max(0, root.openCorners - 1)
        onMediaRequested: function(action, value) { root.mediaAction(action, value) }
        onItemRequested: function(itemId, action, value) { root.itemAction(itemId, action, value, win, rightEar) }
        onEditRequested: root.openEditor()
      }

      // How far down the notch reaches, for the notifications hanging under it
      // (a copy of Omarchy's notifications can't ask the bar, so it reads this).
      readonly property int reach: Math.round(root.topGap + (notch.open ? notch.expandedHeight
        : (notch.alertActive ? notch.alertHeight : notch.collapsedHeight)))
      onReachChanged: reachSave.restart()
      Component.onCompleted: reachSave.restart()
      Timer {
        id: reachSave
        interval: 30
        onTriggered: if (Quickshell.screens.length <= 1 || win.screenName === root.focusedScreenName())
          reachFile.setText(JSON.stringify({ height: win.reach }) + "\n")
      }
      FileView {
        id: reachFile
        path: root.home + "/.local/state/mike-notch/notch.json"
        printErrors: false
      }

      // The Omarchy menu, and every other widget as a round button in the row.
      Instantiator {
        model: root.sections.menu
        delegate: WidgetHost { host: root; screenName: win.screenName; window: win }
        onObjectAdded: function(index, object) { object.parent = notch.menuSlot }
      }
      Instantiator {
        model: root.sections.strip
        delegate: WidgetHost { host: root; screenName: win.screenName; window: win; hiddenIds: win.stripHidden }
        onObjectAdded: function(index, object) { object.parent = notch.statusSlot }
      }
      // Tray apps, every one of them, at the end of the row.
      Instantiator {
        model: SystemTray.items
        delegate: TrayButton { host: root }
        onObjectAdded: function(index, object) { object.parent = notch.traySlot }
      }

      // The shared tooltip, under the widget that asked for it.
      Rectangle {
        id: tip
        readonly property bool mine: !!root.tooltipTarget && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, win)
        readonly property point at: {
          if (!mine) return Qt.point(0, 0)
          var t = root.tooltipTarget
          return t.mapToItem(win.contentItem, t.width / 2, t.height)
        }
        visible: mine && notch.open
        x: Math.max(8, Math.min(at.x - width / 2, win.width - width - 8))
        y: at.y + 8
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: height / 2
        color: Theme.bodySolid
        opacity: 0.94
        border.color: Theme.edge
        border.width: 1
        Text {
          id: tipText
          anchors.centerIn: parent
          text: root.tooltipText
          textFormat: Text.PlainText
          color: Theme.text
          font.family: P.sans
          font.pixelSize: 12
        }
      }
    }
  }

  // ---- the top bar's editor, on the screen you're on
  PanelWindow {
    id: editorWin
    visible: root.editorOpen
    screen: root.editorScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "mike-notch-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.editorOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // A light dim, so the bar stays in view and changes show on it live.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, Theme.dark ? 0.26 : 0.14)
      MouseArea { anchors.fill: parent; onClicked: root.editorOpen = false }
    }

    // Built while it's open and let go when it closes: it's a big window
    // that's rarely open, so it doesn't sit in memory the rest of the time.
    Loader {
      id: editorLoader
      anchors.centerIn: parent
      active: root.editorOpen
      onLoaded: item.forceActiveFocus()
      sourceComponent: Component {
        Editor {
          layout: root.barLayout
          buttons: root.editorButtons
          status: root.status
          media: root.media
          now: clock.date
          clockFormat: root.clockFormat
          lead: root.lead
          motion: root.motion
          glass: root.glass
          barStyle: root.barStyle
          allAgents: root.allAgents
          motionChoice: root.motionChoice
          motionLevel: root.motionLevel
          screens: root.screenChoices
          cornerScreen: root.cornerScreenPresent ? root.cornerScreen : ""
          fullScreen: root.windowsUnderNotch
          onEdited: function(next) { root.setLayout(next) }
          onButtonMoved: function(id, index) { root.moveButton(id, index) }
          onGlassRequested: function(glass) { root.setPref("glass", glass) }
          onStyleRequested: function(style) { root.setPref("notchStyle", style) }
          onAllAgentsRequested: function(on) { root.setPref("allAgents", on) }
          onMotionRequested: function(choice) { root.setPref("motion", choice) }
          onCornerScreenRequested: function(name) { root.setPref("cornerScreen", name) }
          onFullScreenRequested: function(on) { root.setPref("windowsUnderNotch", on) }
          onCloseRequested: root.editorOpen = false
        }
      }
    }
    onVisibleChanged: if (visible && editorLoader.item) editorLoader.item.forceActiveFocus()
  }
}
