// Appearance resolver. EVERYTHING comes from the config file (Config -> cfg); the
// built-in defaults below are the ONLY fallback - used when a key is absent or the
// config fails to load entirely. No external theme dependency. Pure, computed props.
//
// Color slot priority (low->high):
//   1. built-in default (below)
//   2. inline cfg.color{}  (the theme's static palette)
//   3. external color file (cfg.colors path) -- wins, per slot. The live override
//      channel: an external tool (pywal/matugen/wallpaper-colour watcher) rewrites
//      the file and the bar recolours immediately; inline colours are the fallback
//      for slots the file doesn't define (or when the file is missing).

import QtQuick

QtObject {
    id: pal
    property var cfg              // Config instance

    // ---- Built-in default palette (the single fallback if config is gone) ----
    // Matches the "monochrome-minimalism" look: opaque black box, white text/accent/border.
    readonly property color defBackground: "#000000"
    readonly property color defText: "#ffffff"
    readonly property color defAccent: "#ffffff"
    readonly property color defBorder: "#ffffff"
    readonly property color defHighlight: "#ffffff"

    function _raw(slot) {                        // raw override value (a hex, or the string "rainbow"), or null
        var ext = cfg ? cfg.extColor : null;    // external color file (highest -- live override)
        var inl = cfg ? cfg.color : null;       // inline cfg.color{}  (the theme's fallback)
        if (ext && ext[slot]) return ext[slot];
        if (inl && inl[slot]) return inl[slot];
        return null;
    }
    function _pick(slot, def) {
        var v = _raw(slot);
        if (v && v !== "rainbow") return v;     // a real colour override
        return def;                             // "rainbow" or unset -> built-in default (the SOLID fallback)
    }
    // Per-element rainbow: a colour slot set to "rainbow" rides the band; the global "rainbow": true is a
    // shorthand for ALL slots (backwards compatible). Elements sample the band when isRainbow(theirSlot).
    function isRainbow(slot) { return rainbow || _raw(slot) === "rainbow"; }
    readonly property bool anyRainbow: rainbow || isRainbow("text") || isRainbow("accent")
                                       || isRainbow("border") || isRainbow("highlight")

    readonly property color background: _pick("background", defBackground)
    readonly property color text:       _pick("text",       defText)
    readonly property color accent:     _pick("accent",     defAccent)
    readonly property color border:     _pick("border",     defBorder)
    readonly property color highlight:  _pick("highlight",  text)   // hover/focus tint; defaults to text (look unchanged unless set)
    readonly property color separator:  Qt.rgba(text.r, text.g, text.b, 0.35)

    // Rainbow gradient stops - drives rainbow text, visualizer curve, active ws dot,
    // and the selected hub button. Needs >=2 hex stops; otherwise no rainbow.
    // The external color file (cfg.colors) may also carry "stops": [...] -- it wins over
    // the config's stops, so a wallpaper-colour tool can recolour the rolling band live.
    // Entries are validated (#rrggbb) so a bad write can't feed NaN into the band math.
    function _validStops(a) {
        if (!a || !Array.isArray(a)) return null;
        var out = a.filter(function (s) {
            return typeof s === "string" && /^#[0-9a-fA-F]{6}$/.test(s);
        });
        return out.length >= 2 ? out : null;
    }
    readonly property var stops: {
        var ext = (cfg && cfg.extColor) ? _validStops(cfg.extColor.stops) : null;
        if (ext) return ext;
        return (cfg && cfg.stops && cfg.stops.length >= 2) ? cfg.stops : [];
    }
    // Pre-parsed stops as {r,g,b} floats (0..1). The band is sampled ~16x/s at every accent
    // surface, so we parse the hex ONCE here (only when stops changes) and keep _band's per-tick
    // math to plain float lerps -- no slice()/parseInt() in the hot loop.
    readonly property var stopsRgb: {
        var s = stops, out = [];
        for (var i = 0; i < s.length; i++) {
            var h = s[i];
            out.push({ r: parseInt(h.slice(1, 3), 16) / 255,
                       g: parseInt(h.slice(3, 5), 16) / 255,
                       b: parseInt(h.slice(5, 7), 16) / 255 });
        }
        return out;
    }

    // ---- Rolling rainbow band ----
    // The whole UI reads as "windows" into ONE rolling rainbow band: every accent surface samples
    // bandAt(globalX) at its own screen position, so they show different hues at once and the band
    // rolls across them (same period as the clock). `phase` is bound to the bar's animation.
    property real phase: 0
    readonly property real bandPeriod: cfg ? cfg.rainbowPeriod : 420   // px per full rainbow (config: rainbowPeriod)

    function _band(px) {   // -> [r,g,b] floats 0..1 sampled from the band at global x, or null (no rainbow)
        const s = stopsRgb;
        if (!rainbow || !s || s.length < 2) return null;
        const t = (((px / bandPeriod + phase) % 1) + 1) % 1;
        const n = s.length, f = t * n;
        const i = Math.floor(f) % n, j = (i + 1) % n, fr = f - Math.floor(f);
        const a = s[i], b = s[j];
        return [a.r + (b.r - a.r) * fr, a.g + (b.g - a.g) * fr, a.b + (b.b - a.b) * fr];
    }
    function bandAt(px) {   // color at global x; solid accent when rainbow is off
        const c = _band(px);
        return c ? Qt.rgba(c[0], c[1], c[2], 1) : accent;
    }
    // "#rrggbb" forms for Canvas (createLinearGradient.addColorStop needs strings, not color objects)
    readonly property string accentHex: { const s = accent.toString(); return s.length === 9 ? "#" + s.slice(3) : s; }
    function bandHex(px) {
        const c = _band(px);
        if (!c) return accentHex;
        const h = v => ("0" + Math.max(0, Math.min(255, Math.round(v * 255))).toString(16)).slice(-2);
        return "#" + h(c[0]) + h(c[1]) + h(c[2]);
    }

    // ---- Shape / glow / opacity / font (all from config, with defaults) ----
    readonly property real radius:      (cfg && typeof cfg.cornerRadius === "number") ? cfg.cornerRadius : 0
    readonly property bool rainbow:     cfg ? (cfg.rainbow === true) : false
    readonly property real bloom:       (cfg && typeof cfg.bloom === "number") ? Math.max(0, Math.min(1, cfg.bloom)) : 0
    // bloom style: "blur" = soft spread (fades at high values); "glow" = tighter + brighter/saturated (intensifies)
    readonly property string bloomMode: (cfg && cfg.bloomMode === "glow") ? "glow" : "blur"
    readonly property real uiOpacity:   cfg ? cfg.uiOpacity : 1
    readonly property real borderWidth: (cfg && typeof cfg.borderWidth === "number") ? cfg.borderWidth : 1
    readonly property bool hasBox:      cfg ? cfg.hasBox : true

    readonly property string fontFamily: (cfg && cfg.font && cfg.font.family) ? cfg.font.family : "Poppins"
    readonly property int    fontSize:   (cfg && cfg.font && cfg.font.size)   ? cfg.font.size   : 14
    readonly property int    fontWeight: (cfg && cfg.font && cfg.font.weight) ? cfg.font.weight : 300
}
