#!/bin/sh
# foot runs this when a program rings the bell in a window you're not looking
# at (set in ~/.config/foot/foot.ini by `notch-look bell on`). It notes which
# terminal rang (its pid is our parent), and agents.py shows that window's
# agent as needing you until you go to it or the agent gets busy again.
dir="${XDG_STATE_HOME:-$HOME/.local/state}/mike-notch/bells"
mkdir -p "$dir" && date +%s > "$dir/$PPID"
