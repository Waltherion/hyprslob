<p align="center">
  <img src="assets/hyprslob-256.png" width="140" alt="HyprSlob Center Bar logo">
</p>

# HyprSlob Center Bar

A standalone, config-driven **center bar** for [Hyprland](https://hyprland.org/),
built with [Quickshell](https://quickshell.org/). One cohesive pill at the top that
**morphs and expands downward** into a hub of panels - no loose widgets.

<p align="center">
  <img src="screenshots/desktop/trueBlackOrange.jpg" width="760" alt="HyprSlob on the desktop">
</p>

### Showcase

See it in motion - the morph, the visualizer, the launcher and the panels:

<p align="center">
  <a href="https://www.youtube.com/watch?v=WFAML7jn-bs">
    <img src="https://img.youtube.com/vi/WFAML7jn-bs/maxresdefault.jpg" width="640" alt="HyprSlob video showcase on YouTube">
  </a>
  <br>
  <sub>▶ Watch on YouTube (~1 min)</sub>
</p>

## The pill

Collapsed, it's intentionally minimal - `Time | Day | Date`:

<p align="center"><img src="screenshots/bar/day.png" width="420" alt="Collapsed pill"></p>

But it does two things most bars don't:

### Built-in audio visualizer

When sound plays, the center `Day` field smoothly **morphs into a live waveform** that flows with
the music, right inside the pill - powered by [cava](https://github.com/karlstav/cava) and colored
by your rainbow gradient. It follows whatever output you're actually using (headphones included),
and it costs nothing when idle or switched off.

<p align="center"><img src="screenshots/bar/themes/trueBlackOrange.png" width="440" alt="Audio visualizer in the pill"></p>

### Inline workspace indicator

One side field (`Time` or `Date`) **crossfades into workspace dots** on demand - the active
workspace is a large accent dot, the rest dimmed. Show them on workspace switch, on hover, both,
or always; the dots can ride the rainbow gradient too. No separate widget, no layout shift.

<p align="center"><img src="screenshots/bar/workspace.png" width="500" alt="Workspace dots in the pill"></p>

## The hub

Hover the pill and it expands downward into a row of buttons; click one and the pill morphs further
into that panel - one cohesive surface, never loose floating widgets.

<p align="center"><img src="screenshots/hub.png" width="470" alt="The hub buttons"></p>

- **Launcher** - the bar morphs into a fuzzy app launcher (fuzzy + frecency ranking, keyboard-first).
  Bind a key (e.g. `Super+Space`) to open it instantly via `ipc call hyprslob launcher`.
- **Menu** - a config-driven action palette of your own commands. Only appears once you've set
  `actions` in your config (see [Custom menus & dmenu](#custom-menus--dmenu)).
- **System** - OS + kernel, CPU/RAM/GPU usage & temps, focused window, system tray
  (left-click = activate, middle-click = hard-close the app, right-click = its menu). A small
  caffeine (keep-awake) toggle sits by the OS name - it holds a Wayland idle inhibitor that survives
  fullscreen; also bindable via the `caffeine` IPC.
- **Audio** - media controls (MPRIS) with **source chips** when several players are on the bus
  (click to switch which one the media centre controls), volume slider, mute, output switcher (PipeWire).
- **Network** - three boxes: a status box showing what you're connected to (Wired or the Wi-Fi
  SSID), a Wi-Fi box with its own radio toggle + settings, and Bluetooth (toggle + paired devices).
- **Notifications** - history, do-not-disturb, clear-all (HyprSlob is the notification daemon).
- **Power** - lock, sleep/hibernate, log out, restart, shut down (all configurable commands).
  Bind a key (e.g. `Super+Escape`) to the `power` IPC to open it as a quick power menu;
  `q`/`w`/`e`/`r`/`t` trigger the five actions.
- **Weather** - a 5-day forecast (today large with current conditions + wind/humidity/precip and
  sunrise/sunset, then four compact days), theme-coloured like everything else. Data is from
  [Open-Meteo](https://open-meteo.com) (free, **no API key**); settings live in a separate
  `~/.config/hyprslob/weather.jsonc` (location, units, model - see `weather.default.jsonc`, Danish
  defaults). It has no hub button by default: open it from the **Menu** with an action
  `{ "label": "Weather", "panel": "weather" }`, or bind a key to `select weather`.

<table align="center">
  <tr>
    <td align="center"><img src="screenshots/panels/00-launcher.png" width="250"><br><sub>Launcher</sub></td>
    <td align="center"><img src="screenshots/panels/02-system.png" width="250"><br><sub>System</sub></td>
    <td align="center"><img src="screenshots/panels/04-audio.png" width="250"><br><sub>Audio</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/panels/05-connections.png" width="250"><br><sub>Network</sub></td>
    <td align="center"><img src="screenshots/panels/06-notifications.png" width="250"><br><sub>Notifications</sub></td>
    <td align="center"><img src="screenshots/panels/07-power.png" width="250"><br><sub>Power</sub></td>
  </tr>
</table>

## Custom menus & dmenu

HyprSlob ships a generic, themed picker you can drive two ways.

**The menu button** - add an `actions` list to your config; each entry appears in the bar's menu
button and runs its command via `sh -c`:

```jsonc
"actions": [
  { "label": "Power menu", "cmd": "wlogout" },
  { "label": "Clipboard",  "cmd": "cliphist list | qs-dmenu -p 'Clip:' | cliphist decode | wl-copy" }
]
```

The menu button only appears once `actions` is non-empty.

**`qs-dmenu`** is a drop-in `fuzzel --dmenu` replacement (`install.sh` puts it in `~/.local/bin`).
Pipe newline-separated choices in, get the selection on stdout - the picker renders right in the bar:

```sh
choice=$(printf '%s\n' Alpha Bravo Charlie | qs-dmenu --prompt 'Pick: ')
```

<p align="center"><img src="screenshots/panels/01-dmenu.png" width="440" alt="The dmenu picker rendered in the bar"></p>

Items may carry an **image + colour preview** (tab-separated, shown in a side pane):

```
label <TAB> /path/to/preview.png <TAB> #rrggbb,#rrggbb,...
```

Under the hood it calls `qs -c hyprslob ipc call hyprslob menu <choicesFile> <resultFile> <prompt>`;
the wrapper just handles the temp-file plumbing and waits for the result.

**Wallpaper grid.** A sibling `wallpapers` IPC opens a scrollable thumbnail *grid* (arrow keys +
Enter) instead of a list - handy for picking an image. Feed it tab-separated
`label <TAB> /path/to/thumbnail <TAB> /path/to/wallpaper` lines; the chosen wallpaper's path is
written to the result file:

```sh
qs -c hyprslob ipc call hyprslob wallpapers <choicesFile> <resultFile>
```

## Make it yours

Appearance is **fully config-driven** - colors, rainbow gradient, corner radius, border, bloom,
font, opacity - live-reloaded from a single JSONC file. No theme system required. Every pill below
is the same bar - only the config differs:

<table align="center">
  <tr>
    <td align="center"><img src="screenshots/bar/themes/Synthwave.png" width="370"><br><sub>Synthwave</sub></td>
    <td align="center"><img src="screenshots/bar/themes/colorPuke.png" width="370"><br><sub>Color Puke</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/bar/themes/trueBlackOrange.png" width="370"><br><sub>True Black Orange</sub></td>
    <td align="center"><img src="screenshots/bar/themes/blackGold.png" width="370"><br><sub>Black Gold</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/bar/themes/purplePalette.png" width="370"><br><sub>Purple</sub></td>
    <td align="center"><img src="screenshots/bar/themes/hacker.png" width="370"><br><sub>Hacker</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/bar/themes/glacier.png" width="370"><br><sub>Glacier</sub></td>
    <td align="center"><img src="screenshots/bar/themes/forrestZen.png" width="370"><br><sub>Forrest Zen</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/bar/themes/Cachyboo.png" width="370"><br><sub>Cachyboo</sub></td>
    <td align="center"><img src="screenshots/bar/themes/Dweeb.png" width="370"><br><sub>Dweeb</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/bar/themes/archBtw.png" width="370"><br><sub>Arch BTW</sub></td>
    <td align="center"><img src="screenshots/bar/themes/neutral.png" width="370"><br><sub>Neutral</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/bar/themes/monochromeMinimalism.png" width="370"><br><sub>Monochrome</sub></td>
    <td></td>
  </tr>
</table>

Also: **zero-cost static mode** (turn off rainbow, bloom and the visualizer and there are no
animation repaint loops at all), per-monitor, auto-hides in fullscreen, and it reserves space like
a normal bar.

### Dynamic colors from an external tool

Set `"colors"` to a file path and the bar's colors can be driven **live from outside** — perfect
for pywal/matugen or a wallpaper-color watcher:

```jsonc
"color":  { "text": "#7fe3c3", "accent": "#7fe3c3" },        // static fallback
"colors": "/home/you/.cache/wal/hyprslob-colors.json"        // live override (wins, per slot; absolute path)
```

The file holds any subset of the color slots (`{ "text": "#...", "accent": "#...", ... }`) and may
also carry `"stops": ["#...", "#..."]` to recolor the **rolling rainbow band** itself — so even in
rainbow mode the bar can follow your wallpaper's palette. Whenever your tool rewrites it, the bar
recolors immediately — no restart, no IPC. Keys the file doesn't define fall back to the inline
config, and a malformed write keeps the last valid colors, so the bar never flashes back to theme
colors mid-update.

And the same bar living on a few different desktops:

<table align="center">
  <tr>
    <td align="center"><img src="screenshots/desktop/blackGold.jpg" width="380"></td>
    <td align="center"><img src="screenshots/desktop/colorPuke.jpg" width="380"></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/desktop/purple.jpg" width="380"></td>
    <td align="center"><img src="screenshots/desktop/btw.jpg" width="380"></td>
  </tr>
</table>

## Requirements

Arch (and derivatives):

```sh
# core
yay -S quickshell-git cava pavucontrol blueman \
       networkmanager nm-connection-editor pipewire python \
       ttf-nerd-fonts-symbols
# UI font used by default (or change "font.family" in the config)
yay -S ttf-poppins
```

Optional:
- `hyprlock` - the default lock command (override `commands.lock` to use something else).
- `nvidia-utils` - the GPU panel uses `nvidia-smi`; on AMD/Intel it just shows `-`.
- `brightnessctl` - enables the brightness slider (laptops with a backlight).
- `power-profiles-daemon` - enables the power-profile switcher (Saver / Balanced / Performance).

`hyprctl`, `systemctl`, `busctl`, `pactl` come with Hyprland / systemd / PipeWire.

## Install

```sh
git clone https://github.com/Waltherion/hyprslob.git
cd hyprslob
./install.sh
```

Then add the Hyprland integration and launch:

```sh
qs -n -c hyprslob
```

The `-n` (`--no-duplicate`) flag makes a second launch of the **same config** exit immediately,
so an autostart + a manual run (or a flaky theme-switch restart) can't leave you with two bars
stacked on top of each other. It's per-config, so it never touches your other Quickshell instances.
To force-clear a stuck instance, use Quickshell's own registry: `qs kill -c hyprslob`.

## Hyprland integration

HyprSlob targets Hyprland's **Lua config** (the classic `hyprlang` config is being retired).
Copy the autostart, layer-blur and keybind lines from **`hyprland/hyprslob.lua`** into your
`hyprland.lua`. They start `qs -c hyprslob`, blur the `quickshell-hyprslob` layer, add a toggle
keybind, and bind `Super+Ctrl+1..5` to open each panel directly.

## Configuration

All appearance lives in **`~/.config/hyprslob/config.jsonc`** and live-reloads on save.
The shipped **`config.default.jsonc`** is a fully-commented template - every option is listed
(commented out) with its default, so you can see exactly what's tweakable: colors, `stops`
(rainbow gradient), `cornerRadius`, `borderWidth`, `bloom`, `rainbow`, `font`, `commands`, and more.

## Notes

- Built for Hyprland's **Lua config** - the power buttons (logout) use Lua dispatch
  (`hl.dsp.exit()`), and the integration snippet is Lua. The classic `hyprlang` config is being
  retired and isn't a supported target.
- GPU stats auto-detect the vendor: **NVIDIA** (via `nvidia-smi`) reports power-based load -
  its `utilization.gpu` is a time-occupancy metric that over-reports light workloads, so power
  draw vs the card's limit tracks real work better; **AMD** (via the amdgpu sysfs
  `gpu_busy_percent`) reports real utilization. Intel iGPUs aren't covered yet (shown as `-`).

## Disclaimer

HyprSlob was built mostly with **Claude** (Anthropic's AI agent, via [Zed](https://zed.dev/)) by
someone with little coding experience - the "Slob" in the name is a deliberate, tongue-in-cheek nod
to that (a riff on "AI slop"); I'm not trying to hide it. It started purely as a personal project:
I like a minimal top bar, but I genuinely needed the modules a status bar gives you. Packed across
the top they made Waybar feel cluttered, and with two monitors at different resolutions a layout
that looked balanced on one screen came out cramped on the other. So the modules I actually use are
tucked into this bar's pop-down panels instead, keeping the top itself minimal. It's shared in case it's useful to someone else, but it is provided **as
is** - use it, and deal with any problems that come up, **at your own risk**.

Not affiliated with, or endorsed by, the **Hyprland** project. The "Hypr" in the name only reflects
that it's built with Hyprland users in mind.

## License

Copyright (C) 2026 Martin Walther.
Licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later) -
a strong copyleft license: any distributed copy or derivative must also be free software
under the same terms. See [LICENSE](LICENSE).
