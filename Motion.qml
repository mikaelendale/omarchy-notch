pragma Singleton
import QtQuick

// How much the notch moves, everywhere at once. Bar.qml sets `level` from the
// editor's Motion choice (Auto picks Light on a machine with 4 GB of memory
// or less, or 2 processor threads or fewer, and Off when Omarchy's animations
// are off).
//
//   smooth  quick opening and closing, and the music's bars and an agent at
//           work move on their own, a few steps a second (not every frame)
//   light   shorter opening and closing; nothing moves on its own
//   off     no motion at all: everything changes at once
//
// Things that move on their own step on a slow shared beat (`beat` ms) rather
// than animating every frame: the bar's window is repainted, and re-blurred
// by Hyprland, on each step, so fewer steps is what keeps it light.
QtObject {
  property string level: "smooth"

  // Multiplies every duration: 0 turns animations off.
  readonly property real scale: level === "off" ? 0 : (level === "light" ? 0.6 : 1)
  // The notch and corners opening, and closing (ms).
  readonly property int open: Math.round(180 * scale)
  readonly property int close: Math.round(140 * scale)
  // Things that move on their own.
  readonly property bool ambient: level === "smooth"
  readonly property int beat: 160
}
