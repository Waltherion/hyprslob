// Level 1 (hub) - row of SQUARE icon buttons that expand below Level 0.
// The selected button (its Level 2 panel is expanded) gets the "text color" as fill: rainbow-band
// sample when rainbow is on, otherwise solid pal.text - with a dark icon for contrast (like the ws dot).
// v0.2: the panels (Level 2) are wired later; here a click only toggles the selected state.
// Icons via String.fromCharCode (Symbols Nerd Font, FA range) - avoids lost raw glyphs.

import QtQuick

Row {
    id: l1
    property var skin                   // Skin resolver (NOT "pal" -> would shadow the root pal id)
    property bool rainbow: false
    property var  stops: []             // from pal.stops (rainbow stops)
    property real phase: 0              // root.rainbowPhase (rainbow animation)
    property real period: 420           // px per full rainbow
    property string activeKey: ""       // which button is selected (bound to root.hubActive)
    property bool notifUnread: false    // badge on the notif button when unread
    signal toggle(string key)

    property int btnSize: 42
    spacing: 10

    property bool showMenu: true   // include the menu (action-palette) button; hidden when no actions
    readonly property var entries: {
        var e = [
            { key: "launcher", icon: String.fromCharCode(0xf002) },  // magnifier (app launcher / search)
            { key: "menu",     icon: String.fromCharCode(0xf0c9) },  // bars (config-driven action palette)
            { key: "system",   icon: String.fromCharCode(0xf2db) },  // microchip (CPU/GPU/RAM/tray -> level 2)
            { key: "audio",    icon: String.fromCharCode(0xf028) },  // speaker
            { key: "net",      icon: String.fromCharCode(0xf1eb) },  // wifi (net/bt panel)
            { key: "notif",    icon: String.fromCharCode(0xf0f3) },  // bell
            { key: "power",    icon: String.fromCharCode(0xf011) }   // power
        ];
        return l1.showMenu ? e : e.filter(x => x.key !== "menu");
    }

    // text color at global x: rainbow-band sample (like RainbowLabel), otherwise solid pal.text
    function colAt(px) {
        const s = l1.stops;
        if (!l1.rainbow || !s || s.length < 2) return l1.skin ? l1.skin.text : "#ffffff";
        let t = (((px / l1.period + l1.phase) % 1) + 1) % 1;
        const n = s.length, f = t * n;
        const i = Math.floor(f) % n, j = (i + 1) % n, fr = f - Math.floor(f);
        const ch = (h, k) => parseInt(h.slice(1 + k * 2, 3 + k * 2), 16);
        const a = s[i], b = s[j];
        return Qt.rgba((ch(a, 0) + (ch(b, 0) - ch(a, 0)) * fr) / 255,
                       (ch(a, 1) + (ch(b, 1) - ch(a, 1)) * fr) / 255,
                       (ch(a, 2) + (ch(b, 2) - ch(a, 2)) * fr) / 255, 1);
    }

    Repeater {
        model: l1.entries
        delegate: Rectangle {
            id: btn
            required property var modelData
            readonly property bool selected: l1.activeKey === btn.modelData.key
            readonly property color fg: l1.skin ? l1.skin.text : "#ffffff"
            readonly property color bg: l1.skin ? l1.skin.background : "#000000"
            readonly property color hl: l1.skin ? l1.skin.highlight : "#ffffff"

            width: l1.btnSize; height: l1.btnSize
            radius: Math.min(width / 2, (l1.skin ? Math.max(l1.skin.radius, 10) : 10))
            color: selected ? l1.colAt(mapToItem(null, width / 2, 0).x)
                            : (ma.containsMouse ? Qt.rgba(hl.r, hl.g, hl.b, 0.16)
                                                : Qt.rgba(fg.r, fg.g, fg.b, 0.07))
            border.width: 1
            border.color: selected ? l1.colAt(mapToItem(null, width / 2, 0).x)
                                   : Qt.rgba(fg.r, fg.g, fg.b, ma.containsMouse ? 0.30 : 0.13)
            Behavior on color { ColorAnimation { duration: 130 } }

            scale: (ma.containsMouse && !selected) ? 1.07 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            Text {
                anchors.centerIn: parent
                text: btn.modelData.icon
                font.family: "Symbols Nerd Font"
                font.pixelSize: Math.round(l1.btnSize * 0.5)              // larger icon (~21px)
                // inverse rainbow: the SELECTED button is a band fill with a dark icon; UNSELECTED buttons
                // are a solid/mat fill with a BAND icon (colAt -> rolling band, or solid pal.text when rainbow off).
                color: btn.selected ? Qt.rgba(btn.bg.r, btn.bg.g, btn.bg.b, 1)
                                    : l1.colAt(btn.mapToItem(null, btn.width / 2, 0).x)
            }
            Rectangle {   // unread badge (notif button only)
                visible: btn.modelData.key === "notif" && l1.notifUnread
                width: 9; height: 9; radius: 4.5
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 5
                color: l1.skin ? l1.skin.accent : "#ff5555"
                border.width: 1.5; border.color: l1.skin ? l1.skin.background : "#000000"
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: l1.toggle(btn.modelData.key)   // Level 2 panel wired later
            }
        }
    }
}
