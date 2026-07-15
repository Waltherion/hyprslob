// Level 2 - weather panel. A 5-day forecast: today shown large (current conditions + details),
// the next 4 days as compact cards. Theme-driven via `skin`: ALL text is per-character coloured by
// the rolling rainbow band (via RainbowLabel, exactly like the clock), glyphs ride the band too.
// Data comes from weather-fetch.py (Open-Meteo, no API key) which writes ~/.cache/hyprslob/weather.json;
// this panel WATCHES that cache (instant + offline display) and re-runs the fetcher to refresh it.
// Settings come from appcfg (weather.jsonc, Danish defaults).
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: wp
    property var skin
    property var appcfg            // the Config object (reads appcfg.weatherLat/Lon/Location/... )
    width: 320; spacing: 10

    readonly property color fg:  skin ? skin.text       : "#ffffff"
    readonly property color ac:  skin ? skin.accent     : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    function acAt(px) { return wp.skin ? wp.skin.bandAt(px) : wp.ac; }

    readonly property string wfont: "Symbols Nerd Font"
    readonly property int hourFmt: appcfg ? appcfg.weatherHourFormat : 24

    // Per-character band text (rides the stops like the clock); falls back to solid `fg` when the
    // theme's text is not rainbow. Set opacity < 1 on an instance for secondary/dim text.
    component WText: RainbowLabel {
        family: wp.fam
        stops: wp.skin ? wp.skin.stops : []
        phase: wp.skin ? wp.skin.phase : 0
        period: wp.skin ? wp.skin.bandPeriod : 420
        rainbow: wp.skin ? wp.skin.isRainbow("text") : false
        solid: wp.fg
    }
    // A single condition/detail glyph (Nerd Font) that also rides the band.
    component WGlyph: Text {
        font.family: wp.wfont
        color: wp.acAt(mapToItem(null, width / 2, 0).x)
    }
    // A glyph + band-text pair (wind, humidity, sunrise, ...).
    component Stat: Row {
        property string ic: ""
        property string val: ""
        property int gap: 4
        spacing: gap
        WGlyph { text: parent.ic; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        WText { content: parent.val; pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
    }

    // ---- data (parsed from the watched cache file; null until first load) ----
    // Incubation-race guard (see notif popups in shell.qml): applying data changes the models of the
    // day Repeater AND every RainbowLabel's per-character Repeater. If that happens while this panel
    // is still being incubated (a cache file present at open fires onLoaded mid-build), Qt crashes in
    // QQuickRepeater::regenerate. So parse into _wxRaw immediately but only EXPOSE it as `wx` once the
    // panel has finished building (ready), keeping every model empty during incubation.
    property var _wxRaw: null
    property bool ready: false
    readonly property var wx: ready ? _wxRaw : null
    readonly property var cur: wx && wx.current ? wx.current : null
    readonly property var days: wx && wx.days ? wx.days : []
    readonly property string windU: wx && wx.units ? wx.units.wind : "m/s"
    readonly property string precU: wx && wx.units ? wx.units.precip : "mm"

    // ---- formatting helpers ----
    function glyph(cp) { return cp ? String.fromCharCode(cp) : ""; }
    function t(v) { return (v === undefined || v === null) ? "–" : (Math.round(v) + "°"); }
    function n1(v) { return (v === undefined || v === null) ? "–" : (Math.round(v * 10) / 10); }
    function pad2(x) { return (x < 10 ? "0" : "") + x; }
    function wday(dateStr) {
        if (!dateStr) return "";
        var d = new Date(dateStr + "T00:00:00");
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()];
    }
    function dm(dateStr) {   // dd/mm
        if (!dateStr) return "";
        var p = ("" + dateStr).split("-");
        return p.length >= 3 ? (p[2] + "/" + p[1]) : dateStr;
    }
    function hm(iso) {       // ISO local time -> HH:MM (honours 12/24)
        if (!iso) return "–";
        var tm = ("" + iso).split("T")[1] || "";
        var hhmm = tm.substring(0, 5);
        if (wp.hourFmt === 24 || hhmm.length < 5) return hhmm;
        var h = parseInt(hhmm.substring(0, 2));
        var m = hhmm.substring(3, 5);
        var ap = h >= 12 ? "pm" : "am";
        var h12 = h % 12; if (h12 === 0) h12 = 12;
        return h12 + ":" + m + ap;
    }
    function agoStr(epoch) {
        if (!epoch) return "";
        var d = new Date(epoch * 1000);
        return "updated " + wp.pad2(d.getHours()) + ":" + wp.pad2(d.getMinutes());
    }

    // ---- fetch: refresh the cache file, which the FileView below watches ----
    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/hyprslob/weather-fetch.py"
    function _args() {
        var a = ["python3", wp._script];
        if (appcfg && appcfg.weatherLat !== null && appcfg.weatherLon !== null) {
            a.push("--lat", "" + appcfg.weatherLat, "--lon", "" + appcfg.weatherLon);
        } else {
            a.push("--location", appcfg ? appcfg.weatherLocation : "Copenhagen");
            if (appcfg && appcfg.weatherCountry) a.push("--country", appcfg.weatherCountry);
        }
        a.push("--units", appcfg ? appcfg.weatherUnits : "metric");
        a.push("--wind", appcfg ? appcfg.weatherWindUnit : "ms");
        a.push("--model", appcfg ? appcfg.weatherModel : "best_match");
        a.push("--days", "5");
        return a;
    }
    function refresh() { fetchProc.command = wp._args(); fetchProc.running = true; }
    function refreshIfStale() {
        var maxAge = (appcfg ? appcfg.weatherRefreshMinutes : 30) * 60;
        var age = wp._wxRaw ? (Date.now() / 1000 - (wp._wxRaw.fetched || 0)) : 1e9;
        if (age >= maxAge) wp.refresh();
    }

    Process { id: fetchProc }   // command set in refresh(); rewrites the cache the FileView watches

    // Watch the cache: instant display on open, and live update when the fetcher rewrites it.
    FileView {
        id: cacheView
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hyprslob/weather.json"
        watchChanges: true
        onLoaded: { try { var o = JSON.parse(cacheView.text()); if (o) wp._wxRaw = o; } catch (e) {} }
        onFileChanged: reload()
    }

    Timer {   // slow refresh while the panel is open (it exists only while shown)
        interval: Math.max(5, appcfg ? appcfg.weatherRefreshMinutes : 30) * 60000
        running: true; repeat: true
        onTriggered: wp.refresh()
    }
    // expose data only AFTER the panel has finished incubating (avoids the Repeater-regenerate crash)
    Timer { id: readyTimer; interval: 250; onTriggered: wp.ready = true }
    Component.onCompleted: { readyTimer.start(); wp.refreshIfStale(); }

    // ================= header =================
    Item {
        width: parent.width; height: 16
        WText {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            content: (wp.wx && wp.wx.location && wp.wx.location.length) ? wp.wx.location
                     : (wp.appcfg ? wp.appcfg.weatherLocation : "")
            pixelSize: 12; fontWeight: Font.DemiBold
        }
        WText {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            content: wp.wx ? wp.agoStr(wp.wx.fetched) : "loading…"
            pixelSize: 10; opacity: 0.6
        }
    }

    // ================= today (large) =================
    Rectangle {
        width: parent.width; height: 138; radius: wp.skin ? Math.max(wp.skin.radius, 8) : 10
        color: Qt.rgba(wp.fg.r, wp.fg.g, wp.fg.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(wp.ac.r, wp.ac.g, wp.ac.b, 0.45)

        // big condition glyph (rides the band) + text
        Column {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.top: parent.top; anchors.topMargin: 12
            spacing: 3; width: 132
            WGlyph { text: wp.cur ? wp.glyph(wp.cur.glyph) : ""; font.pixelSize: 52 }
            WText { content: wp.cur ? wp.cur.text : ""; pixelSize: 13; fontWeight: Font.Medium }
        }

        // big temperature + feels-like + H/L
        Column {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.top: parent.top; anchors.topMargin: 10
            spacing: 1
            WText {
                anchors.right: parent.right
                content: wp.cur ? (Math.round(wp.cur.temp) + "°") : "–"
                pixelSize: 44; fontWeight: Font.Bold
            }
            WText {
                anchors.right: parent.right
                content: wp.cur ? ("feels " + wp.t(wp.cur.feels)) : ""
                pixelSize: 11; opacity: 0.6
            }
            WText {
                anchors.right: parent.right
                content: wp.days.length ? ("H " + wp.t(wp.days[0].tmax) + "   L " + wp.t(wp.days[0].tmin)) : ""
                pixelSize: 12; fontWeight: Font.Medium
            }
        }

        // details strip: wind / humidity / precip
        Row {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.bottom: parent.bottom; anchors.bottomMargin: 11
            spacing: 12
            Stat { ic: wp.glyph(0xe34b); val: wp.cur ? (wp.n1(wp.cur.wind) + " " + wp.windU) : "" }             // wind
            Stat { ic: wp.glyph(0xe373); val: wp.cur ? (wp.cur.humidity + "%") : "" }                            // humidity
            Stat { ic: wp.glyph(0xe371); val: (wp.days.length ? (wp.n1(wp.days[0].precip) + wp.precU
                          + (wp.days[0].precip_prob != null ? " " + wp.days[0].precip_prob + "%" : "")) : "") }   // precip
        }
    }

    // sunrise / sunset / UV line
    Item {
        width: parent.width; height: 15
        Row {
            anchors.centerIn: parent; spacing: 16
            Stat { gap: 5; ic: wp.glyph(0xe34c); val: wp.days.length ? wp.hm(wp.days[0].sunrise) : "–" }   // sunrise
            Stat { gap: 5; ic: wp.glyph(0xe34d); val: wp.days.length ? wp.hm(wp.days[0].sunset) : "–" }    // sunset
            Stat { gap: 5; ic: wp.glyph(0xe30d); val: (wp.days.length && wp.days[0].uv != null)            // UV index
                       ? ("UV " + Math.round(wp.days[0].uv)) : "UV –" }
        }
    }

    // ================= next 4 days (compact) =================
    Row {
        width: parent.width
        spacing: 8
        Repeater {
            model: Math.max(0, wp.days.length - 1)
            delegate: Rectangle {
                id: dcard
                required property int index
                readonly property var day: wp.days[index + 1]
                width: (wp.width - 3 * 8) / 4
                height: 92
                radius: wp.skin ? Math.max(wp.skin.radius, 6) : 8
                color: Qt.rgba(wp.fg.r, wp.fg.g, wp.fg.b, 0.05)
                border.width: 1
                border.color: Qt.rgba(wp.fg.r, wp.fg.g, wp.fg.b, 0.10)
                Column {
                    anchors.centerIn: parent; spacing: 3; width: parent.width
                    WText { anchors.horizontalCenter: parent.horizontalCenter
                            content: wp.wday(dcard.day ? dcard.day.date : ""); pixelSize: 11; fontWeight: Font.DemiBold }
                    WText { anchors.horizontalCenter: parent.horizontalCenter
                            content: wp.dm(dcard.day ? dcard.day.date : ""); pixelSize: 9; opacity: 0.6 }
                    WGlyph { anchors.horizontalCenter: parent.horizontalCenter
                             text: dcard.day ? wp.glyph(dcard.day.glyph) : ""; font.pixelSize: 20 }
                    WText { anchors.horizontalCenter: parent.horizontalCenter
                            content: dcard.day ? (wp.t(dcard.day.tmax) + " " + wp.t(dcard.day.tmin)) : ""; pixelSize: 10 }
                    WText { anchors.horizontalCenter: parent.horizontalCenter
                            content: (dcard.day && dcard.day.precip > 0) ? (wp.n1(dcard.day.precip) + wp.precU) : ""
                            pixelSize: 9; opacity: 0.6 }
                }
            }
        }
    }
}
