.pragma library

// Which window is playing: for a tap on the music, which goes there. Most
// players can't bring their own window up (Chrome, and so YouTube, can't),
// so the window is found by its title holding the track's title (a YouTube
// tab or app window does), else a window of a site that plays media (YouTube
// keeps the old video's title for a while after moving on, while hidden),
// else by the player's app; between equals, the one used most recently.
//
// clients: `hyprctl clients -j`; track: the track's title; app: the player's
// desktop entry or name ("Chrome", "Spotify"...).
// Returns { address, class, title }, or null.
function windowFor(clients, track, app) {
  var words = String(app || "").toLowerCase().split(/[^a-z0-9]+/).filter(function(w) { return w.length > 2 })
  // Chrome's player is "Chrome"; its windows are google-chrome, or
  // chrome-<site>-Default for an installed site.
  if (words.indexOf("chrome") !== -1) words.push("chromium")
  var t = String(track || "").toLowerCase().slice(0, 48)
  var sites = ["youtube", "music", "spotify", "soundcloud", "deezer", "tidal", "twitch", "netflix", "vimeo", "bandcamp", "pandora", "podcast"]
  var best = null, bestScore = 0
  var list = clients || []
  for (var i = 0; i < list.length; i++) {
    var c = list[i]
    if (!c) continue
    var title = String(c.title || "").toLowerCase()
    var cls = (String(c["class"] || "") + " " + String(c.initialClass || "")).toLowerCase()
    var score = 0
    if (t.length > 2 && title.indexOf(t) !== -1) score += 10
    var app = false
    for (var w = 0; w < words.length; w++) if (cls.indexOf(words[w]) !== -1) { app = true; break }
    if (app) {
      score += 2
      for (var m = 0; m < sites.length; m++) if (cls.indexOf(sites[m]) !== -1 || title.indexOf(sites[m]) !== -1) { score += 5; break }
    }
    if (score === 0) continue
    if (score > bestScore || (score === bestScore && Number(c.focusHistoryID) < Number(best.focusHistoryID))) {
      best = c
      bestScore = score
    }
  }
  return best ? { address: String(best.address), "class": String(best["class"] || ""), title: String(best.title || "") } : null
}
