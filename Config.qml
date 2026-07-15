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
        "bloom": 0.0,               // glow strength 0..1; 0 = off (free)
        "bloomMode": "blur",        // "blur" = soft spread (fades at high values); "glow" = tighter + brighter (intensifies)
        "opacity": 1.0,             // whole-pill opacity 0..1
        "cornerRadius": 0,          // pill corner radius (px); 0 = sharp box (monochrome-minimalism default)
        "borderWidth": 1,           // pill border width (px); 0 = no border
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
        "sleepLabel": "Sleep",      // label on the suspend button (set "Hibernate" if you hibernate)
        "lowBatteryThreshold": 15,  // notify once when the battery falls to this % while discharging (laptops)
        "launcherWidth": 520,       // app-launcher mode width in px (wider than the 320 panels)
        "launcherMaxResults": 8,    // app rows shown in the launcher before it scrolls
        "dmenuWidth": 560,          // generic dmenu picker width in px
        "dmenuMaxResults": 12,      // dmenu rows shown before it scrolls
        "dmenuPreviewWidth": 820,   // dmenu width when items carry a preview (list + preview pane)
        "menuWidth": 420,           // the menu-button action-palette width
        "actions": []               // menu-button entries: [{ "label": "...", "cmd": "..." }]
    })

    property var d: defaults          // merged result (defaults <- theme config <- local override)
    property var themeObj: ({})       // parsed per-theme config (themes/current/hyprslob.jsonc)
    property var localObj: ({})       // parsed shared override (~/.config/hyprslob/local.jsonc)
    property var extColor: ({})       // external color file (cfg.colors), if set

    // ---- Reactive convenience aliases ----
    readonly property bool   rainbow: d.rainbow === true
    readonly property real   bloom: typeof d.bloom === "number" ? d.bloom : 0
    readonly property string bloomMode: d.bloomMode || "blur"
    readonly property real   uiOpacity: d.opacity === undefined ? 1 : Number(d.opacity)
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
    readonly property int    lowBatteryThreshold: (typeof d.lowBatteryThreshold === "number" && d.lowBatteryThreshold > 0) ? d.lowBatteryThreshold : 15
    readonly property int    launcherWidth: (typeof d.launcherWidth === "number" && d.launcherWidth > 0) ? d.launcherWidth : 520
    readonly property int    launcherMaxResults: (typeof d.launcherMaxResults === "number" && d.launcherMaxResults > 0) ? d.launcherMaxResults : 8
    readonly property int    dmenuWidth: (typeof d.dmenuWidth === "number" && d.dmenuWidth > 0) ? d.dmenuWidth : 560
    readonly property int    dmenuMaxResults: (typeof d.dmenuMaxResults === "number" && d.dmenuMaxResults > 0) ? d.dmenuMaxResults : 12
    readonly property int    dmenuPreviewWidth: (typeof d.dmenuPreviewWidth === "number" && d.dmenuPreviewWidth > 0) ? d.dmenuPreviewWidth : 820
    readonly property int    menuWidth: (typeof d.menuWidth === "number" && d.menuWidth > 0) ? d.menuWidth : 420
    readonly property var    actions: Array.isArray(d.actions) ? d.actions : []

    // ---- Weather module (separate ~/.config/hyprslob/weather.jsonc, live-watched) ----
    // Kept out of the appearance config on purpose: location/units/API are behaviour+data, not
    // theme. A neutral default (Copenhagen) means the panel works out of the box; a per-user
    // weather.jsonc overrides it. See weather-fetch.py / WeatherPanel.qml.
    readonly property var weatherDefaults: ({
        "latitude": null,           // set both lat+lon to pin an exact spot (wins over "location")
        "longitude": null,
        "location": "Copenhagen",   // else this name is geocoded ("country" disambiguates duplicates)
        "country": "DK",
        "units": "metric",          // "metric" (C, mm) | "imperial" (F, inch)
        "windUnit": "ms",           // "ms" | "kmh" | "mph" | "kn"
        "model": "best_match",      // best_match auto-picks DMI/MetNo near DK; or pin a model
        "refreshMinutes": 30,       // how often to refetch while the bar is visible
        "hourFormat": 24            // 24 | 12 - sunrise/sunset clock
    })
    property var weatherObj: ({})   // parsed weather.jsonc (keeps last-good on parse error)
    readonly property var weather: cfg._merge(cfg.weatherDefaults, cfg.weatherObj)
    readonly property var    weatherLat: (typeof weather.latitude === "number") ? weather.latitude : null
    readonly property var    weatherLon: (typeof weather.longitude === "number") ? weather.longitude : null
    readonly property string weatherLocation: weather.location || ""
    readonly property string weatherCountry: weather.country || ""
    readonly property string weatherUnits: (weather.units === "imperial") ? "imperial" : "metric"
    readonly property string weatherWindUnit: (["ms", "kmh", "mph", "kn"].indexOf(weather.windUnit) >= 0) ? weather.windUnit : "ms"
    readonly property string weatherModel: weather.model || "best_match"
    readonly property int    weatherRefreshMinutes: (typeof weather.refreshMinutes === "number" && weather.refreshMinutes > 0) ? weather.refreshMinutes : 30
    readonly property int    weatherHourFormat: (weather.hourFormat === 12) ? 12 : 24

    // ---- Calendar module (separate ~/.config/hyprslob/calendar.jsonc, live-watched) ----
    // Settings + (for now) dummy events; this is the file a future Outlook/Betterbird sync writes to.
    readonly property var calendarDefaults: ({
        "weekStart": "monday",        // "monday" | "sunday" - which day the grid starts on
        "showWeekNumbers": true,      // show the ISO week number column
        "dateFormat": "dd-mm-yyyy",   // how the selected day's date reads (tokens dd/mm/yyyy)
        "events": []                  // [{ "date": "2026-07-16", "time": "14:00", "title": "..." }]
    })
    property var calendarObj: ({})    // parsed calendar.jsonc (keeps last-good on parse error)
    readonly property var calendar: cfg._merge(cfg.calendarDefaults, cfg.calendarObj)
    readonly property string calWeekStart: (calendar.weekStart === "sunday") ? "sunday" : "monday"
    readonly property bool   calShowWeekNumbers: calendar.showWeekNumbers !== false
    readonly property string calDateFormat: calendar.dateFormat || "dd-mm-yyyy"
    readonly property var    calEvents: Array.isArray(calendar.events) ? calendar.events : []

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
    // Parse a JSONC string -> object, or null on error (so the caller keeps the last good value).
    function _parseJsonc(txt) {
        if (!txt || !txt.trim().length) return ({});
        try { return JSON.parse(cfg._stripJsonc(txt)) || ({}); }
        catch (e) { console.warn("hyprslob: config parse error (keeping last valid):", e); return null; }
    }
    // Merge order: built-in defaults <- per-theme appearance <- shared local override (behaviour).
    function _recompute() { cfg.d = cfg._merge(cfg._merge(cfg.defaults, cfg.themeObj), cfg.localObj); }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.config/hyprslob/config.jsonc"
        watchChanges: true
        onLoaded: { var o = cfg._parseJsonc(view.text()); if (o !== null) { cfg.themeObj = o; cfg._recompute(); } }
        onFileChanged: reload()
        onLoadFailed: (err) => { console.warn("hyprslob: cannot load config:", err); cfg.themeObj = ({}); cfg._recompute(); }
    }

    // Shared override - behaviour that should persist across theme switches (e.g. menu actions).
    // Merged ON TOP of the per-theme config, so it wins. Optional; absent is fine.
    FileView {
        id: localView
        path: Quickshell.env("HOME") + "/.config/hyprslob/local.jsonc"
        watchChanges: true
        onLoaded: { var o = cfg._parseJsonc(localView.text()); if (o !== null) { cfg.localObj = o; cfg._recompute(); } }
        onFileChanged: reload()
        onLoadFailed: (err) => { cfg.localObj = ({}); cfg._recompute(); }
    }

    // External color file: the LIVE override channel (wins over the inline "color"
    // block, per slot -- see Skin.qml). An external tool (pywal/matugen/wallpaper-
    // colour watcher) rewrites it and the bar recolours on the fly. JSONC-tolerant;
    // a parse error keeps the last valid colours (so partial/in-place writes never
    // flash back to theme colours). A MISSING file clears the overrides.
    FileView {
        id: extView
        path: cfg.colorsPath
        watchChanges: true
        onLoaded: { var o = cfg._parseJsonc(extView.text()); if (o !== null) cfg.extColor = o; }
        onFileChanged: reload()
        onLoadFailed: (err) => cfg.extColor = ({})
    }

    // Weather module config - separate fixed-path file, live-watched. Absent is fine
    // (neutral defaults apply); a parse error keeps the last valid settings.
    FileView {
        id: weatherView
        path: Quickshell.env("HOME") + "/.config/hyprslob/weather.jsonc"
        watchChanges: true
        onLoaded: { var o = cfg._parseJsonc(weatherView.text()); if (o !== null) cfg.weatherObj = o; }
        onFileChanged: reload()
        onLoadFailed: (err) => cfg.weatherObj = ({})
    }

    // Calendar module config + events - separate fixed-path file, live-watched.
    FileView {
        id: calendarView
        path: Quickshell.env("HOME") + "/.config/hyprslob/calendar.jsonc"
        watchChanges: true
        onLoaded: { var o = cfg._parseJsonc(calendarView.text()); if (o !== null) cfg.calendarObj = o; }
        onFileChanged: reload()
        onLoadFailed: (err) => cfg.calendarObj = ({})
    }
}
