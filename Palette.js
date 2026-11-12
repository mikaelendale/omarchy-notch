.pragma library

// Fonts, the motion curve and a colour helper. Colours come from Theme.qml,
// which follows the current Omarchy theme.

var sans = "Adwaita Sans"
var glyphs = "JetBrainsMono Nerd Font"
var symbols = "Noto Sans Symbols 2"   // ✳ without the colour-emoji fallback

// Motion: an ease-out with a long tail. No bounce, no ease-in (Omarchy's rules).
var ease = [0.22, 0.9, 0.24, 1.0, 1.0, 1.0]

function alpha(color, a) {
  var c = Qt.color(color)
  return Qt.rgba(c.r, c.g, c.b, a)
}
