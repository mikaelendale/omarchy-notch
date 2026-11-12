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

  // ---- motion follows `omarchy toggle animations`
  readonly property real motion: Style.duration(100) > 0 ? 1 : 0

  // ---- the time
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // ---- what's playing
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var list = players
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
    running: !!root.player && root.player.isPlaying
    onTriggered: {
      if (root.player) root.player.positionChanged()
      root.mediaTick++
    }
  }
  readonly property var media: {
    var tick = mediaTick
    var p = player
    if (!p) return ({ available: false })
    return {
      available: true,
      playing: !!p.isPlaying,
      title: p.trackTitle || "",
      artist: p.trackArtist || "",
      artUrl: p.trackArtUrl || "",
      identity: p.identity || "",
      position: p.positionSupported ? p.position : 0,
      length: p.lengthSupported ? p.length : 0
    }
  }
  function mediaAction(action) {
    var p = player
    if (!p) return
    if (action === "toggle" && p.canTogglePlaying) p.togglePlaying()
    else if (action === "next" && p.canGoNext) p.next()
    else if (action === "previous" && p.canGoPrevious) p.previous()
  }

  // ---- Every coding agent's sessions (agents.py): Claude Code from the
  // claude-sessions widget's collector, the others by watching their terminals.
  // A non-Claude session whose terminal rang the bell (Hyprland's urgent flag)
  // is waiting on you.
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
    command: ["python3", "-I", "-B", root.agentsScript]
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
      try {
        var rows = JSON.parse(text())
        root.notificationsShowing = Array.isArray(rows) && rows.length > 0
      } catch (e) { root.notificationsShowing = false }
    }
    onLoadFailed: root.notificationsShowing = false
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
    // Show or hide the side notch.
    function side(): void { root.saveSide(root.sideWith({ hidden: !root.side.hidden })) }
    function sideShow(): void { root.saveSide(root.sideWith({ hidden: false })) }
    // Full screen (windows under the notch) or the notch's own strip.
    function screen(): void { root.setPref("windowsUnderNotch", !root.windowsUnderNotch) }
    function sideHide(): void { root.saveSide(root.sideWith({ hidden: true })) }
    // What the side strip thinks is going on (for testing).
    function sideState(): string { return sideNotch.debugState() }
    // Show what a "Claude needs you" toast looks like.
    function previewSessions(): void { root.previewSessions() }
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
      for (var i = 0; i < nets.length; i++) {
        if (nets[i] && nets[i].connected) {
          var raw = Number(nets[i].signalStrength || 0)
          strength = raw > 1 ? raw / 100 : raw
          break
        }
      }
      return { kind: "wifi", strength: strength }
    }
    return { kind: "none", strength: 0, enabled: !!Networking.wifiEnabled }
  }
  readonly property var batteryStatus: {
    var d = UPower.displayDevice
    if (!d || !d.isPresent) return { present: false }
    var level = Number(d.percentage || 0)
    if (level > 1) level = level / 100
    var charging = d.state === UPowerDeviceState.Charging || (d.state === UPowerDeviceState.FullyCharged && !UPower.onBattery)
    return { present: true, level: level, charging: charging }
  }
  readonly property var bluetoothStatus: {
    var adapter = Bluetooth.defaultAdapter
    var devices = Bluetooth.devices ? Bluetooth.devices.values : []
    var connected = false
    for (var i = 0; i < devices.length; i++) if (devices[i] && devices[i].connected) { connected = true; break }
    return { enabled: !!(adapter && adapter.enabled), connected: connected }
  }
  readonly property var status: ({
    wifi: wifiStatus,
    battery: batteryStatus,
    bluetooth: bluetoothStatus,
    volume: { level: volume, muted: muted },
    claude: {
      working: (claude.counts.working || 0) + (claude.counts.watching || 0),
      needs: claude.counts.needs || 0,
      agent: claude.sessions.length > 0 && (claude.sessions[0].state === "needs" || claude.sessions[0].state === "working" || claude.sessions[0].state === "watching")
        ? (claude.sessions[0].agent || "claude") : defaultAgent
    },
    usage: usage
  })

  // ---- the side notch's data
  readonly property var notifService: shell && typeof shell.firstPartyServiceFor === "function" ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var idleService: shell && typeof shell.firstPartyServiceFor === "function" ? shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var nightService: shell && typeof shell.firstPartyServiceFor === "function" ? shell.firstPartyServiceFor("omarchy.nightlight") : null

  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property real volume: sink && sink.audio ? Math.min(1, sink.audio.volume) : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)

  property string layoutMode: "dwindle"
  Process {
    id: layoutProbe
    running: true
    command: ["omarchy-hyprland-workspace-layout-current"]
    stdout: SplitParser { onRead: function(line) { var v = String(line).trim(); if (v) root.layoutMode = v } }
  }
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() { layoutProbe.running = true }
  }
  Timer { id: layoutRecheck; interval: 400; onTriggered: layoutProbe.running = true }

  readonly property var modes: ({
    screen: windowsUnderNotch,
    dnd: notifService ? !!notifService.doNotDisturb : false,
    awake: idleService ? !!idleService.stayAwake : false,
    nightlight: nightService ? !!nightService.enabled : false,
    muted: muted,
    layout: layoutMode
  })

  function toggleMode(mode) {
    if (mode === "dnd" && notifService) notifService.setDoNotDisturb(!notifService.doNotDisturb)
    else if (mode === "awake" && idleService) idleService.setIdleEnabled(!!idleService.stayAwake)
    else if (mode === "nightlight" && nightService) nightService.setNightlight(!nightService.enabled)
    else if (mode === "mute" && sink && sink.audio) sink.audio.muted = !sink.audio.muted
    else if (mode === "screen") setPref("windowsUnderNotch", !windowsUnderNotch)
    else if (mode === "layout") {
      Quickshell.execDetached(["omarchy-hyprland-workspace-layout-toggle"])
      layoutRecheck.restart()
    }
  }
  function setVolume(value) {
    if (!sink || !sink.audio) return
    sink.audio.volume = Math.max(0, Math.min(1, value))
    if (value > 0 && sink.audio.muted) sink.audio.muted = false
  }

  // Brightness through brightnessctl; a drag sends at most ~15 updates a second.
  property real brightness: 0.5
  property bool brightnessAvailable: false
  property real pendingBrightness: -1
  Process {
    id: brightnessProbe
    command: ["brightnessctl", "-m"]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).split(",")
        if (parts.length >= 5 && parts[1] === "backlight") {
          var current = Number(parts[2]), max = Number(parts[4])
          if (max > 0) { root.brightness = current / max; root.brightnessAvailable = true }
        }
      }
    }
  }
  Timer {
    interval: 4000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (root.pendingBrightness < 0) brightnessProbe.running = true
  }
  Timer {
    id: brightnessSend
    interval: 66
    onTriggered: {
      if (root.pendingBrightness < 0) return
      var pct = Math.max(1, Math.round(root.pendingBrightness * 100))
      Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"])
      root.pendingBrightness = -1
    }
  }
  function setBrightness(value) {
    brightness = Math.max(0.01, Math.min(1, value))
    pendingBrightness = brightness
    if (!brightnessSend.running) brightnessSend.start()
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

  // Where the side notch sits: which edge, how far down, and whether it's shown.
  property var side: ({ edge: "right", center: 0.42, hidden: false, screen: "" })
  property bool sideLoaded: false
  readonly property string sideStatePath: root.home + "/.local/state/mike-notch/side.json"
  FileView {
    id: sideFile
    path: root.sideStatePath
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        root.side = {
          edge: d.edge === "left" ? "left" : "right",
          center: Math.max(0, Math.min(1, Number(d.center))) || 0.42,
          hidden: d.hidden === true,
          screen: String(d.screen || "")
        }
      } catch (e) {}
      root.sideLoaded = true
    }
    onLoadFailed: root.sideLoaded = true
  }
  function saveSide(next) {
    side = next
    Quickshell.execDetached(["mkdir", "-p", root.home + "/.local/state/mike-notch"])
    sideSave.restart()
  }
  Timer {
    id: sideSave
    interval: 250
    onTriggered: sideFile.setText(JSON.stringify(root.side) + "\n")
  }
  function sideWith(changes) {
    var next = {}
    for (var k in side) next[k] = side[k]
    for (var c in changes) next[c] = changes[c]
    return next
  }
  readonly property var sideScreen: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (screens[i].name === side.screen) return screens[i]
    return screens.length ? screens[0] : null
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
      readonly property real thickness: notch.open ? notch.expandedHeight : notch.collapsedHeight


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
      readonly property bool holdsPopout: {
        var owner = root.activePopout
        if (!owner) return false
        if (Quickshell.screens.length <= 1) return true
        return root.targetBelongsToWindow(owner, win)
      }

      anchors { top: true; left: true; right: true }
      implicitHeight: notch.implicitHeight + 40
      color: "transparent"
      // Full screen (the default): no reserved strip, every window gets the
      // whole screen and the notch sits over it like a camera notch,
      // see-through until it's used. Switched off (the Full screen switch in
      // the side strip's Modes), the notch keeps a strip and windows start
      // below it.
      exclusionMode: root.windowsUnderNotch || root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
      exclusiveZone: root.windowsUnderNotch ? 0 : notch.collapsedHeight
      margins.top: root.barHidden ? -implicitHeight : 0
      WlrLayershell.namespace: "mike-notch"
      // Above everything, fullscreen apps included.
      WlrLayershell.layer: WlrLayer.Overlay

      // Only the slab takes the pointer. Exact numbers rather than an item: an
      // item's region doesn't follow its parent moving.
      mask: Region {
        x: Math.floor((win.width - notch.bodyW) / 2)
        y: 0
        width: Math.ceil(notch.bodyW)
        height: Math.max(1, Math.ceil(notch.bodyH))
      }

      Notch {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        motion: root.motion
        status: root.status
        alert: root.alert
        onAlertDismissed: root.alert = null
        notificationsShowing: root.notificationsShowing
        seeThroughWhenIdle: root.windowsUnderNotch
        defaultAgent: root.defaultAgent
        forceOpen: root.pinned && (Quickshell.screens.length <= 1 || win.screenName === root.focusedScreenName())
        hold: win.holdsPopout || win.summonHold
        now: clock.date
        clockFormat: root.clockFormat
        media: root.media
        claude: root.claude
        onMediaRequested: function(action) { root.mediaAction(action) }
        onSessionRequested: function(session) { root.focusSession(session) }
        onConversationsRequested: root.openConversations()
      }

      // How far down the notch reaches, for the notifications hanging under it
      // (a copy of Omarchy's notifications can't ask the bar, so it reads this).
      readonly property int reach: Math.round(notch.open ? notch.expandedHeight
        : (notch.alertActive ? notch.alertHeight : notch.collapsedHeight))
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
        delegate: WidgetHost { host: root; screenName: win.screenName; window: win }
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

  // ---- the side notch
  PanelWindow {
    id: sideWin

    screen: root.sideScreen
    visible: root.sideLoaded && !root.barHidden && !root.side.hidden
    readonly property bool onLeft: root.side.edge === "left"
    anchors { top: true; bottom: true; left: sideWin.onLeft; right: !sideWin.onLeft }
    implicitWidth: sideNotch.implicitWidth + 4
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "mike-side-notch"
    WlrLayershell.layer: WlrLayer.Top
    // Only the strip and the tab that's out take the pointer. Exact numbers
    // rather than items: an item's region doesn't follow the strip moving.
    mask: Region {
      x: Math.floor(sideNotch.x + sideNotch.stripX)
      y: Math.floor(sideNotch.y + sideNotch.stripTop)
      width: Math.ceil(sideNotch.stripW)
      height: Math.ceil(sideNotch.bodyH)
      regions: [
        Region {
          x: Math.floor(sideNotch.x + sideNotch.flyAreaX)
          y: Math.floor(sideNotch.y + sideNotch.flyGeom.y)
          width: Math.ceil(sideNotch.flyGeom.w)
          height: Math.ceil(sideNotch.flyGeom.h)
        }
      ]
    }

    readonly property var monitor: Hyprland.monitorFor(sideWin.screen)
    readonly property bool fullscreenHere: !!(monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen)

    // Dragging: follow the pointer along the edge; across the screen, switch edge.
    property real dragDy: 0
    readonly property real centerY: root.side.center * height + dragDy

    SideNotch {
      id: sideNotch
      x: sideWin.onLeft ? 0 : sideWin.width - width
      // Placed by its height with Modes shut, so opening Modes never moves the
      // icons: downward it grows from a fixed top; upward (no room below) it
      // grows from a fixed bottom.
      readonly property real restTop: Math.max(4, Math.min(sideWin.centerY - restHeight / 2, sideWin.height - restHeight - 4))
      y: Math.round(modesUp ? restTop - modesAmount * modesListH : Math.min(restTop, sideWin.height - height - 4))
      roomBelow: sideWin.height - (restTop + restHeight) - 4
      edge: root.side.edge
      motion: root.motion
      modes: root.modes
      volume: root.volume
      brightness: root.brightness
      brightnessAvailable: root.brightnessAvailable
      usage: root.usage
      fullscreen: sideWin.fullscreenHere

      onModeRequested: function(mode) { root.toggleMode(mode) }
      onMuteRequested: root.toggleMode("mute")
      onVolumeRequested: function(value) { root.setVolume(value) }
      onBrightnessRequested: function(value) { root.setBrightness(value) }
      onDragged: function(dx, dy) { sideWin.dragDy = dy }
      onDropped: function(dx, dy) {
        var h = Math.max(1, sideWin.height)
        var center = Math.max(0.06, Math.min(0.94, (root.side.center * h + dy) / h))
        var width = sideWin.screen ? sideWin.screen.width : 1920
        var edge = root.side.edge
        if (edge === "right" && dx < -width * 0.35) edge = "left"
        else if (edge === "left" && dx > width * 0.35) edge = "right"
        sideWin.dragDy = 0
        root.saveSide(root.sideWith({ center: center, edge: edge, screen: sideWin.screen ? sideWin.screen.name : "" }))
      }
    }
  }
}
