#!/bin/bash
# Installs the notch on Omarchy:
#
#   omarchy plugin add https://github.com/mikaelendale/omarchy-notch
#   ~/.config/omarchy/plugins/mike.notch/install.sh
#
# or ./install.sh from any copy of this folder, which puts it in
# ~/.config/omarchy/plugins/mike.notch (or updates an earlier install where it
# is). It links notch-look and claude-conversations into ~/.local/bin and turns
# the notch look on. `notch-look off` puts everything back the way it was.
set -euo pipefail

fail() { echo "install.sh: $*" >&2; exit 1; }

command -v omarchy >/dev/null || fail "this is a plugin for Omarchy (omarchy.org)."
command -v python3 >/dev/null || fail "python3 is needed: omarchy pkg add python"
[[ -f $HOME/.config/hypr/looknfeel.lua ]] ||
  fail "this needs Omarchy's Lua Hyprland config (~/.config/hypr/looknfeel.lua); run omarchy update first."
# (Read into a variable: `cmd | grep -q` fails under pipefail when grep stops early.)
bar_help=$(omarchy bar --help 2>&1 || true)
[[ $bar_help == *"use <id>"* ]] ||
  fail "this Omarchy can't swap its bar for a plugin yet; run omarchy update first."

plugins="$HOME/.config/omarchy/plugins"
src=$(cd "$(dirname "$0")" && pwd)
if [[ $src == "$plugins"/* ]]; then
  dest=$src                          # already in place (omarchy plugin add, git clone)
else
  dest="$plugins/mike.notch"
  for manifest in "$plugins"/*/manifest.json; do
    # An earlier install, under whatever folder name, is updated where it is.
    if [[ -f $manifest ]] && grep -q '"id": *"mike.notch"' "$manifest"; then
      dest=$(dirname "$manifest")
      break
    fi
  done
  mkdir -p "$dest"
  # Everything but a git checkout's own .git, which stays the installed copy's.
  shopt -s dotglob nullglob
  for entry in "$src"/*; do
    [[ $(basename "$entry") == .git ]] && continue
    cp -a "$entry" "$dest/"
  done
  shopt -u dotglob nullglob
fi

mkdir -p "$HOME/.local/bin"
for tool in notch-look claude-conversations; do
  chmod +x "$dest/bin/$tool"
  ln -sf "$dest/bin/$tool" "$HOME/.local/bin/$tool"
done
chmod +x "$dest/bell.sh"

# Wait for the shell to find the plugin before switching the bar to it.
found() { local list; list=$(omarchy plugin list --json 2>/dev/null || true); [[ $list == *'"mike.notch"'* ]]; }
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
for _ in $(seq 40); do
  found && break
  sleep 0.1
done
found || fail "the shell didn't find the plugin; try omarchy restart shell, then run this again."

"$HOME/.local/bin/notch-look" on

cat <<'DONE'

The notch is on. Hover it at the top of the screen, or the corners beside
it; right-click any of them to choose what goes where.

  notch-look         what's on
  notch-look off     everything back the way it was

Optional: a Super+Shift+C picker for your Claude Code conversations. Add this
to ~/.config/hypr/bindings.lua (it needs fzf: omarchy pkg add fzf):

  o.rebind("SUPER + SHIFT + C", "Claude conversations",
    "omarchy-launch-or-focus-tui --app-id=org.omarchy.claude-conversations claude-conversations")
DONE
