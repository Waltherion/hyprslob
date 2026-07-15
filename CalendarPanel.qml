// Level 2 - calendar panel. A month grid (ISO week numbers, Monday-start by default, today ringed,
// a dot on days that have events) plus the selected day's event list. Theme-driven via `skin`: header
// labels + event text are per-character coloured by the rolling band (RainbowLabel, like the clock);
// the many grid numbers use a single band sample each (visually identical for 1-2 digits, far lighter).
// Settings + events come from appcfg (calendar.jsonc) - for now the events are dummy/hand-edited; this
// is the file a future Outlook/Betterbird sync would populate. All dates use Danish conventions.
import QtQuick

Column {
    id: cp
    property var skin
    property var appcfg
    width: 320; spacing: 8

    readonly property color fg:  skin ? skin.text       : "#ffffff"
    readonly property color ac:  skin ? skin.accent     : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    readonly property string wfont: "Symbols Nerd Font"
    function acAt(px) { return cp.skin ? cp.skin.bandAt(px) : cp.ac; }
    // single-sample text colour: band when the theme's text is rainbow, else solid text
    function txtAt(px) { return (cp.skin && cp.skin.isRainbow("text")) ? cp.skin.bandAt(px) : cp.fg; }

    // Per-character band text for multi-char labels (rides the stops like the clock).
    component WText: RainbowLabel {
        family: cp.fam
        stops: cp.skin ? cp.skin.stops : []
        phase: cp.skin ? cp.skin.phase : 0
        period: cp.skin ? cp.skin.bandPeriod : 420
        rainbow: cp.skin ? cp.skin.isRainbow("text") : false
        solid: cp.fg
    }

    // ---- settings ----
    readonly property string weekStart: appcfg ? appcfg.calWeekStart : "monday"
    readonly property bool showWk: appcfg ? appcfg.calShowWeekNumbers : true
    readonly property string dateFormat: appcfg ? appcfg.calDateFormat : "dd-mm-yyyy"
    readonly property var wdLabels: cp.weekStart === "sunday"
        ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                       "July", "August", "September", "October", "November", "December"]
    readonly property var wdFull: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    // ---- state ----
    readonly property var _today: new Date()
    property int viewYear: _today.getFullYear()
    property int viewMonth: _today.getMonth()          // 0-11
    property string selectedIso: cp.isoDate(_today)
    readonly property string todayIso: cp.isoDate(_today)

    // ---- date helpers ----
    function pad2(x) { return (x < 10 ? "0" : "") + x; }
    function isoDate(d) { return d.getFullYear() + "-" + cp.pad2(d.getMonth() + 1) + "-" + cp.pad2(d.getDate()); }
    function isoWeek(d) {   // ISO-8601 week number
        var t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        var dayNr = (t.getDay() + 6) % 7;
        t.setDate(t.getDate() - dayNr + 3);              // Thursday of this week
        var firstThu = new Date(t.getFullYear(), 0, 4);
        var fdn = (firstThu.getDay() + 6) % 7;
        firstThu.setDate(firstThu.getDate() - fdn + 3);
        return 1 + Math.round((t - firstThu) / 604800000);
    }
    function fmtDate(iso, fmt) {
        var p = ("" + iso).split("-");                    // [yyyy, mm, dd]
        if (p.length < 3) return iso;
        return ("" + fmt).replace("yyyy", p[0]).replace("mm", p[1]).replace("dd", p[2]);
    }
    function weekdayFull(iso) {
        var p = ("" + iso).split("-");
        if (p.length < 3) return "";
        return cp.wdFull[(new Date(p[0], p[1] - 1, p[2])).getDay()];
    }
    function shiftMonth(delta) {
        var m = cp.viewMonth + delta, y = cp.viewYear;
        while (m < 0) { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        cp.viewMonth = m; cp.viewYear = y;
    }
    function goToday() {
        var n = new Date();
        cp.viewYear = n.getFullYear(); cp.viewMonth = n.getMonth(); cp.selectedIso = cp.isoDate(n);
    }

    // ---- 6-week grid for the displayed month ----
    readonly property var weeks: {
        var first = new Date(cp.viewYear, cp.viewMonth, 1);
        var off = cp.weekStart === "sunday" ? first.getDay() : (first.getDay() + 6) % 7;
        var out = [];
        for (var w = 0; w < 6; w++) {
            var days = [], wn = 0;
            for (var d = 0; d < 7; d++) {
                var cur = new Date(cp.viewYear, cp.viewMonth, 1 - off + w * 7 + d);
                if (d === 0) wn = cp.isoWeek(cur);
                days.push({ n: cur.getDate(), iso: cp.isoDate(cur), inMonth: cur.getMonth() === cp.viewMonth });
            }
            out.push({ wk: wn, days: days });
        }
        return out;
    }

    // ---- events (from config; dummy for now) ----
    readonly property var eventsByDate: {
        var m = ({});
        var evs = (appcfg && appcfg.calEvents) ? appcfg.calEvents : [];
        for (var i = 0; i < evs.length; i++) {
            var e = evs[i]; if (!e || !e.date) continue;
            if (!m[e.date]) m[e.date] = [];
            m[e.date].push(e);
        }
        return m;
    }
    function hasEvents(iso) { var a = cp.eventsByDate[iso]; return !!(a && a.length); }
    readonly property var selectedEvents: {
        var a = (cp.eventsByDate[cp.selectedIso] || []).slice();
        a.sort(function (x, y) { return ("" + (x.time || "")).localeCompare("" + (y.time || "")); });
        return a;
    }

    readonly property int wkW: cp.showWk ? 24 : 0
    readonly property real cellW: (width - wkW) / 7

    // ================= header: ‹  Month Year  › =================
    Item {
        width: parent.width; height: 24
        Text {
            id: prevBtn
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: String.fromCharCode(0xf053)          // chevron-left
            font.family: cp.wfont; font.pixelSize: 14
            color: cp.acAt(mapToItem(null, width / 2, 0).x)
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                        onClicked: cp.shiftMonth(-1) }
        }
        Item {   // wrapper so the click handler is a SIBLING of the RainbowLabel (a Row), not a child
            anchors.centerIn: parent
            width: monthLbl.width; height: monthLbl.height
            WText { id: monthLbl; content: cp.monthNames[cp.viewMonth] + " " + cp.viewYear
                    pixelSize: 14; fontWeight: Font.DemiBold }
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                        onClicked: cp.goToday() }   // click the title to jump back to today
        }
        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: String.fromCharCode(0xf054)          // chevron-right
            font.family: cp.wfont; font.pixelSize: 14
            color: cp.acAt(mapToItem(null, width / 2, 0).x)
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                        onClicked: cp.shiftMonth(1) }
        }
    }

    // ================= weekday header =================
    Row {
        width: parent.width
        Item { width: cp.wkW; height: 16 }
        Repeater {
            model: 7
            delegate: Item {
                required property int index
                width: cp.cellW; height: 16
                WText {
                    anchors.centerIn: parent
                    content: cp.wdLabels[index]; pixelSize: 10; fontWeight: Font.Medium; opacity: 0.7
                }
            }
        }
    }

    // ================= 6 week rows =================
    Column {
        width: parent.width; spacing: 2
        Repeater {
            model: cp.weeks
            delegate: Row {
                id: wrow
                required property var modelData
                width: cp.width
                // week number
                Item {
                    width: cp.wkW; height: 28; visible: cp.showWk
                    Text {
                        anchors.centerIn: parent
                        text: wrow.modelData.wk
                        color: cp.txtAt(mapToItem(null, width / 2, 0).x)
                        font.family: cp.fam; font.pixelSize: 9; opacity: 0.55
                    }
                }
                // 7 day cells
                Repeater {
                    model: wrow.modelData.days
                    delegate: Item {
                        id: cell
                        required property var modelData
                        width: cp.cellW; height: 28
                        readonly property bool isToday: modelData.iso === cp.todayIso
                        readonly property bool isSel: modelData.iso === cp.selectedIso
                        // selection fill / today ring
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: cell.isSel ? Qt.rgba(cp.ac.r, cp.ac.g, cp.ac.b, 0.22) : "transparent"
                            border.width: cell.isToday ? 1.5 : 0
                            border.color: cp.acAt(mapToItem(null, width / 2, 0).x)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.n
                            color: cp.txtAt(mapToItem(null, width / 2, 0).x)
                            opacity: cell.modelData.inMonth ? 1.0 : 0.32
                            font.family: cp.fam; font.pixelSize: 12
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                        }
                        // event dot
                        Rectangle {
                            visible: cp.hasEvents(cell.modelData.iso)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                            width: 4; height: 4; radius: 2
                            color: cp.acAt(mapToItem(null, width / 2, 0).x)
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: cp.selectedIso = cell.modelData.iso }
                    }
                }
            }
        }
    }

    // ================= selected day + its events =================
    Rectangle { width: parent.width; height: 1; color: Qt.rgba(cp.fg.r, cp.fg.g, cp.fg.b, 0.12) }

    WText {
        content: cp.weekdayFull(cp.selectedIso) + "  " + cp.fmtDate(cp.selectedIso, cp.dateFormat)
        pixelSize: 12; fontWeight: Font.DemiBold
    }

    Column {
        width: parent.width; spacing: 4
        Repeater {
            model: cp.selectedEvents
            delegate: Row {
                required property var modelData
                width: cp.width; spacing: 8
                WText { content: modelData.time || "•"; pixelSize: 11; fontWeight: Font.Medium
                        width: 42 }
                WText { content: modelData.title || ""; pixelSize: 11 }
            }
        }
        WText {
            visible: cp.selectedEvents.length === 0
            content: "No events"; pixelSize: 11; opacity: 0.55
        }
    }
}
