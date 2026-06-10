#!/usr/bin/env bash
# HyprSlob installer - copies the app into ~/.config/quickshell/hyprslob and
# seeds a config. Safe to re-run; never overwrites an existing config.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/quickshell/hyprslob"
CFG_DIR="$HOME/.config/hyprslob"
CFG="$CFG_DIR/config.jsonc"

mkdir -p "$DEST" "$CFG_DIR"

# Copy the app files (skip if running from the destination itself).
if [ "$SRC" != "$DEST" ]; then
    cp -f "$SRC"/*.qml "$SRC"/*.py "$SRC"/cava.conf "$SRC"/*.sh "$SRC"/config.default.jsonc "$DEST"/
    echo "Copied app files -> $DEST"
fi
chmod +x "$DEST"/*.sh 2>/dev/null || true

# Seed the user config only if absent - never clobber an existing file/symlink.
if [ ! -e "$CFG" ]; then
    cp "$DEST/config.default.jsonc" "$CFG"
    echo "Seeded config -> $CFG"
else
    echo "Config already exists, left untouched -> $CFG"
fi

cat <<'EOF'

HyprSlob installed.

Next:
  1. Add the Hyprland integration (autostart + layer blur + keybinds)
     from hyprland/hyprslob.lua into your hyprland.lua
  2. Reload Hyprland, then run:   qs -c hyprslob
  3. Edit ~/.config/hyprslob/config.jsonc to taste (live-reload).

Dependencies: see README.md.
EOF
