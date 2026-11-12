pragma Singleton
import QtQuick

// Colours for both notches.
//
// The current Omarchy theme tints the glass and the text: Bar.qml reads the
// theme's colors.toml and calls apply(), so switching themes re-tints them.
// Status colours (working, needs you, charging, on/off switches) are fixed
// system colours instead, one set for dark themes and one for light: themes
// disagree about what "green" is (White's is grey, Rose Pine's is blue), and a
// battery or a "needs you" mustn't change meaning with the wallpaper.
//
// Light mode is designed, not inverted: white cards on light glass, soft dark
// hairlines, and darker status colours that read on a light surface. The
// defaults (Tokyo Night) are what the off-screen tests draw with.
QtObject {
  id: theme

  property bool dark: true
  property color background: "#1a1b26"
  property color foreground: "#c0caf5"
  property color accent: "#7aa2f7"

  // ---- the glass
  // Thick enough that the theme's colour always leads: Omarchy's blur is
  // light, so at thinner tints a busy or bright wallpaper shows through as
  // shapes and the notch takes on the wallpaper's look instead of the theme's.
  readonly property real frostAlpha: dark ? 0.86 : 0.88
  readonly property color body: Qt.rgba(background.r, background.g, background.b, frostAlpha)
  // A little light along the top edge, like glass catching it.
  readonly property color bodyTop: Qt.tint(body, Qt.rgba(1, 1, 1, dark ? 0.06 : 0.34))
  readonly property color bodySolid: background
  // The rim: a light edge on dark glass, a soft dark one on light glass.
  readonly property color edge: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.09)

  // ---- surfaces on the glass
  readonly property color card: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.56)
  readonly property color cardHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.82)
  readonly property color hairline: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.1)

  // ---- text
  readonly property color text: foreground
  readonly property color secondary: Qt.rgba(foreground.r, foreground.g, foreground.b, dark ? 0.62 : 0.66)
  readonly property color tertiary: Qt.rgba(foreground.r, foreground.g, foreground.b, dark ? 0.34 : 0.4)
  // Text on a solid `text`-coloured fill (a slider, the Open button).
  readonly property color onText: background

  // ---- status, the same in every theme
  readonly property color green: dark ? "#30d158" : "#24a148"
  readonly property color orange: dark ? "#ff9f0a" : "#d9650b"
  readonly property color yellow: dark ? "#ffd60a" : "#b8860b"
  readonly property color red: dark ? "#ff453a" : "#d70015"
  readonly property color blue: dark ? "#0a84ff" : "#0a64d6"
  readonly property color purple: dark ? "#bf5af2" : "#8e44c4"
  readonly property color teal: dark ? "#40c8e0" : "#0e8aa8"

  // Black or white, whichever reads on this colour.
  function contrastOn(c) {
    var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    return lum > 0.6 ? "#000000" : "#ffffff"
  }

  // colors.toml as "key = value" pairs; unknown keys are ignored.
  function apply(values) {
    if (!values) return
    function c(key, fallback) { return values[key] ? values[key] : fallback }
    dark = String(values.mode || "dark") !== "light"
    background = c("background", background)
    foreground = dark ? c("bright_foreground", c("foreground", foreground)) : c("foreground", foreground)
    accent = c("accent", accent)
  }
}
