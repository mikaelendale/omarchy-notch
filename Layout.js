.pragma library

// What the top bar can show, and where: the left corner, the notch, or the
// right corner; and which cards the open notch shows. The layout is saved in
// prefs.json as
//   { left: [ids], center: [ids], right: [ids], cards: [ids] }
// and edited with the notch's editor (right-click the notch or a corner).

var names = {
  media: "Music",
  agents: "Agents",
  clock: "Time",
  date: "Date",
  wifi: "Wi-Fi",
  bluetooth: "Bluetooth",
  battery: "Battery",
  volume: "Volume",
  speed: "Network speed",
  workspaces: "Workspaces",
  privacy: "Privacy dots"
}

// The order items are offered in, when they aren't on the bar.
var all = ["workspaces", "media", "agents", "clock", "date", "privacy", "wifi", "bluetooth", "battery", "volume", "speed"]
var zones = ["left", "center", "right"]

// The open notch's cards.
var cardNames = {
  system: "System",
  notifications: "Notifications",
  media: "Music",
  today: "Today",
  agents: "Agents"
}
var allCards = ["system", "notifications", "media", "today", "agents"]

// A real array from whatever list came in. A layout that has been through a
// QML signal or a `var` property comes back with Qt's own list type, which
// Array.isArray() says isn't an array; taking that for "no list" is what
// once made every edit save the defaults.
function toList(x) {
  if (!x || typeof x === "string") return []
  if (Array.isArray(x)) return x
  if (typeof x.length === "number") return Array.prototype.slice.call(x)
  return []
}
function isList(x) {
  return !!x && typeof x !== "string" && (Array.isArray(x) || typeof x.length === "number")
}

function defaults() {
  return { left: ["workspaces", "media"], center: ["agents", "clock", "privacy"], right: ["wifi", "bluetooth", "battery"],
           cards: ["system", "notifications", "agents"] }
}

// Unknown ids are dropped and each item shows in one place only, so a
// hand-edited or older prefs.json can't break the bar.
function normalize(raw) {
  if (!raw || typeof raw !== "object") return defaults()
  var seen = {}
  var out = { left: [], center: [], right: [], cards: [] }
  var any = false
  for (var z = 0; z < zones.length; z++) {
    var list = toList(raw[zones[z]])
    for (var i = 0; i < list.length; i++) {
      var id = String(list[i])
      if (!names[id] || seen[id]) continue
      seen[id] = true
      out[zones[z]].push(id)
      any = true
    }
  }
  if (!any && !isList(raw.left)) out = defaults()
  // Layouts saved before cards could be chosen get the default cards.
  if (isList(raw.cards)) {
    var seenCard = {}
    out.cards = toList(raw.cards).map(String).filter(function(id) {
      if (!cardNames[id] || seenCard[id]) return false
      seenCard[id] = true
      return true
    })
  } else {
    out.cards = defaults().cards
  }
  return out
}

function unusedCards(layout) {
  var placed = toList(layout.cards)
  return allCards.filter(function(id) { return placed.indexOf(id) === -1 })
}

// The layout with card `id` at `index` among the cards; index -1 takes it off.
function movedCard(layout, id, index) {
  var out = moved(layout, "", "", 0)
  var list = toList(layout.cards).filter(function(x) { return x !== id })
  if (index >= 0) list.splice(Math.max(0, Math.min(list.length, index)), 0, id)
  out.cards = list
  return out
}

function unused(layout) {
  var placed = {}
  for (var z = 0; z < zones.length; z++) {
    var list = toList(layout[zones[z]])
    for (var i = 0; i < list.length; i++) placed[list[i]] = true
  }
  return all.filter(function(id) { return !placed[id] })
}

// The layout with `id` moved to `zone` at `index`; zone "" takes it off the bar.
function moved(layout, id, zone, index) {
  var out = { left: [], center: [], right: [], cards: toList(layout.cards).slice() }
  for (var z = 0; z < zones.length; z++)
    out[zones[z]] = toList(layout[zones[z]]).filter(function(x) { return x !== id })
  if (zone && out[zone]) {
    var list = out[zone]
    var at = Math.max(0, Math.min(list.length, index))
    list.splice(at, 0, id)
  }
  return out
}

function same(a, b) {
  return JSON.stringify(normalize(a)) === JSON.stringify(normalize(b))
}
