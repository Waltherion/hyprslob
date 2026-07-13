// Workspace dots for ONE monitor. Reuses the bar's Hyprland.workspaces pattern
// (filter per monitor + active detection). Active = large filled accent dot; others = small dimmed.
// Used as an overlay in a side field; crossfaded in/out by shell.qml (preserves symmetry).

import QtQuick
import Quickshell.Hyprland

Row {
    id: dots
    property string screenName: ""
    property color activeColor: "#ffffff"
    property color dimColor: "#808080"
    property int dotSize: 7
    property bool rainbow: false        // active dot samples the band when true, otherwise solid activeColor
    property var  stops: []             // rainbow stops (#rrggbb)
    property real phase: 0              // animated 0..1 (shared with the text)
    property real period: 420           // px per full rainbow
    spacing: Math.round(dotSize * 0.9)

    // stops parsed to {r,g,b} floats once (only when stops changes); colAt stays plain lerps.
    readonly property var _rgb: {
        var s = dots.stops, out = [];
        for (var i = 0; i < (s ? s.length : 0); i++) {
            var h = s[i];
            if (typeof h !== "string" || h.length < 7) continue;
            out.push({ r: parseInt(h.slice(1, 3), 16) / 255,
                       g: parseInt(h.slice(3, 5), 16) / 255,
                       b: parseInt(h.slice(5, 7), 16) / 255 });
        }
        return out;
    }

    // active-dot color: window into the scrolling band at global x (like RainbowLabel), otherwise solid
    function colAt(px) {
        const s = dots._rgb;
        if (!dots.rainbow || !s || s.length < 2) return dots.activeColor;
        let t = (((px / dots.period + dots.phase) % 1) + 1) % 1;
        const n = s.length, f = t * n;
        const i = Math.floor(f) % n, j = (i + 1) % n, fr = f - Math.floor(f);
        const a = s[i], b = s[j];
        return Qt.rgba(a.r + (b.r - a.r) * fr, a.g + (b.g - a.g) * fr, a.b + (b.b - a.b) * fr, 1);
    }

    Repeater {
        model: Hyprland.workspaces
        delegate: Item {
            id: wsd
            required property var modelData
            readonly property bool onThis: modelData && modelData.id >= 1 && modelData.monitor
                                           && dots.screenName && modelData.monitor.name === dots.screenName
            readonly property bool isActive: modelData && modelData.monitor && modelData.monitor.activeWorkspace
                                             && modelData.monitor.activeWorkspace.id === modelData.id
            visible: onThis                 // not-this-screen workspaces are omitted from the Row layout
            width: dots.dotSize
            height: dots.dotSize

            Rectangle {
                anchors.centerIn: parent
                width: wsd.isActive ? dots.dotSize : Math.round(dots.dotSize * 0.72)
                height: width
                radius: width / 2
                color: wsd.isActive ? dots.colAt(mapToItem(null, width / 2, 0).x) : dots.dimColor
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (wsd.onThis) Hyprland.dispatch("workspace " + wsd.modelData.id)
            }
        }
    }
}
