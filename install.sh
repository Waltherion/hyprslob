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

# Install the qs-dmenu helper (a drop-in `fuzzel --dmenu` replacement that renders in the bar) into
# ~/.local/bin, so your own scripts can pipe choices to it: `printf '%s\n' a b c | qs-dmenu -p 'Pick:'`.
if [ -f "$SRC/qs-dmenu" ]; then
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    install -m 755 "$SRC/qs-dmenu" "$BIN_DIR/qs-dmenu"
    echo "Installed qs-dmenu -> $BIN_DIR/qs-dmenu  (ensure ~/.local/bin is on your PATH)"
fi

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
  4. Optional: add an "actions" list to your config for the menu button, and pipe
     choices to `qs-dmenu` from your own scripts (a fuzzel --dmenu replacement). See README.md.

Dependencies: see README.md.
EOF
