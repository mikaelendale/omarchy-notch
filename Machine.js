.pragma library

// What this machine can take, for Motion's Auto and for how often the bar
// checks on things.

// A modest machine: 4 GB of memory or less (with a little slack, since the
// kernel reports a bit under what's fitted), or 2 processor threads or fewer.
function isModest(memKb, cpus) {
  var mem = Number(memKb) || 0, n = Number(cpus) || 0
  return (mem > 0 && mem <= 4.2 * 1024 * 1024) || (n > 0 && n <= 2)
}

// The motion level: the editor's choice, or for Auto: Off when Omarchy's
// animations are off, Light on a modest machine, Smooth otherwise.
function level(choice, animationsOn, modest) {
  if (choice === "smooth" || choice === "light" || choice === "off") return choice
  if (!animationsOn) return "off"
  return modest ? "light" : "smooth"
}
