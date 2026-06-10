// Central appearance config for HyprSlob. Reads ~/.config/hyprslob/config.jsonc
// (JSON with comments), live-reload via FileView.watchChanges. Controls ONLY appearance,
// never structure. Missing keys fall back to `defaults` (deeply merged).
//
// Limitation: no `//` sequences inside string values (local paths use single-slash).

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cfg

    readonly property var defaults: ({
        "rainbow": false,           // true = rolling rainbow text (needs "stops"); false = static (free)
        "bloom": 0.0,               // glow strength 0..1 (x48px blur); 0 = off (free)
        "opacity": 1.0,             // whole-pill opacity 0..1
        "scale": 1.0,               // whole-pill scale
        "cornerRadius": 14,         // pill corner radius (px)
        "borderWidth": 0,           // pill border width (px); 0 = no border
        "hasBox": true,             // false = no pill background box (text only)
        "showVisualizer": false,    // true = Day morphs to the cava visualizer when audio plays
        "wsSide": "date",           // which side field shows the workspace dots: "time" | "date"
        "wsTrigger": "both",        // "change" | "hover" | "both" | "always"
        "stops": [],                // rainbow gradient hex stops, e.g. ["#ff0000","#00ff00","#0000ff"]
        "rainbowPeriod": 420,       // px per full rainbow across the bar: lower = tighter/more, higher = stretched
        "rainbowSpeed": 1.0,        // roll speed: 1 = ~12s/cycle, 2 = faster, 0.5 = slower, 0 = frozen, <0 = reverse
        "colors": "",               // optional path to an external color file (same shape as "color")
        "color": {},                // {background,text,accent,border,highlight} - omit a slot for the default
        "icon": {},                 // {left,right} SVG icon paths
        "font": {},                 // {family,size,weight}
        "commands": {},             // {lock,suspend,logout,reboot,poweroff} power-button commands (sh -c)
        "sleepLabel": "Sleep"       // label on the suspend button (set "Hibernate" if you hibernate)
    })

    property var d: defaults          // merged result (defaults <- user config)
    property var extColor: ({})       // external color file (cfg.colors), if set

    // ---- Reactive convenience aliases ----
    readonly property bool   rainbow: d.rainbow === true
    readonly property real   bloom: typeof d.bloom === "number" ? d.bloom : 0
    readonly property real   uiOpacity: d.opacity === undefined ? 1 : Number(d.opacity)
    readonly property real   uiScale: d.scale === undefined ? 1 : Number(d.scale)
    readonly property var    cornerRadius: d.cornerRadius   // raw number (Skin applies default if absent)
    readonly property var    borderWidth: d.borderWidth     // raw number (0 = no border)
    readonly property bool   hasBox: d.hasBox === undefined ? true : !!d.hasBox
    readonly property bool   showVisualizer: !!d.showVisualizer
    readonly property string wsSide: d.wsSide || "date"
    readonly property string wsTrigger: d.wsTrigger || "both"
    readonly property var    stops: Array.isArray(d.stops) ? d.stops : []
    readonly property real   rainbowPeriod: (typeof d.rainbowPeriod === "number" && d.rainbowPeriod > 0) ? d.rainbowPeriod : 420
    readonly property real   rainbowSpeed: typeof d.rainbowSpeed === "number" ? d.rainbowSpeed : 1
    readonly property string colorsPath: d.colors || ""
    readonly property var    color: d.color || ({})
    readonly property var    icon: d.icon || ({})
    readonly property var    font: d.font || ({})
    readonly property var    commands: d.commands || ({})
    readonly property string sleepLabel: d.sleepLabel || "Sleep"

    function _stripJsonc(s) {
        // remove /* */ blocks, then // line comments (not `://`/after quote),
        // finally trailing commas (,} and ,]) -> proper JSONC; safe to comment lines out
        return s.replace(/\/\*[\s\S]*?\*\//g, "")
                .replace(/(^|[^:"'\\])\/\/[^\n\r]*/g, "$1")
                .replace(/,(\s*[}\]])/g, "$1");
    }
    function _merge(base, over) {
        var out = {};
        for (var k in base) out[k] = base[k];
        for (var k2 in over) {
            if (over[k2] && typeof over[k2] === "object" && !Array.isArray(over[k2])
                && base[k2] && typeof base[k2] === "object" && !Array.isArray(base[k2]))
                out[k2] = cfg._merge(base[k2], over[k2]);
            else out[k2] = over[k2];
        }
        return out;
    }
    function _parse() {
        try {
            var txt = view.text();
            if (!txt || !txt.trim().length) { cfg.d = cfg.defaults; return; }
            var obj = JSON.parse(cfg._stripJsonc(txt));
            cfg.d = cfg._merge(cfg.defaults, obj || {});
        } catch (e) {
            console.warn("hyprslob: config parse error (keeping last valid):", e);
        }
    }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.config/hyprslob/config.jsonc"
        watchChanges: true
        onLoaded: cfg._parse()
        onFileChanged: reload()
        onLoadFailed: (err) => { console.warn("hyprslob: cannot load config:", err); cfg.d = cfg.defaults; }
    }

    // External color file (optional theme bridge). Loaded only when cfg.colors is set.
    FileView {
        id: extView
        path: cfg.colorsPath
        watchChanges: true
        onLoaded: { try { cfg.extColor = JSON.parse(extView.text()) || ({}); } catch (e) { cfg.extColor = ({}); } }
        onFileChanged: reload()
        onLoadFailed: (err) => cfg.extColor = ({})
    }
}
