// Level 2 - system panel (unfolds under the system button). Best-shot v1:
// OS logo + kernel, CPU/RAM/GPU usage+temp, active window, tray (scrollbar).
// Theme-driven via `skin` (Skin resolver - NOT "pal", see the Level1Bar trap).

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Column {
    id: sp
    property var skin
    property var hostWin: null  // the PanelWindow - needed to anchor tray context menus.
                                // NOTE: must NOT be named "win" - that shadows the root id `win`
                                // (the binding `win: win` would self-reference -> null). Old trap.
    property int cpu: -1
    property int ram: -1
    property int gpu: -1
    property int cpuTemp: -1
    property int gpuTemp: -1
    property int disk: -1        // root filesystem used % (-1 = unknown -> bar shows "—")
    property int bat: -1         // laptop battery %, -1 = no battery (desktop) -> indicator hidden
    property bool batCharging: false
    // Font Awesome battery glyph by level: full / three-quarters / half / quarter / empty
    readonly property int batGlyph: bat >= 90 ? 0xf240 : bat >= 65 ? 0xf241
                                  : bat >= 40 ? 0xf242 : bat >= 15 ? 0xf243 : 0xf244
    readonly property color batColor: (bat >= 0 && bat <= 15 && !batCharging) ? "#ff5555"
                                    : batCharging ? "#7cfc72" : sp.fg
    property int batMin: -1       // minutes to empty (discharging) or full (charging)
    property int batHealth: -1    // battery health % (full / design-full)
    property int bright: -1       // screen backlight % (-1 = no backlight -> slider hidden)
    property string profile: ""    // active power profile ("" = no ppd -> switcher hidden)
    // UI mirrors: the slider/buttons set these for instant feedback; the 2s stream re-syncs them
    // (writing the streamed properties directly would break their bindings).
    property int brightUi: 0
    property string profileUi: ""
    onBrightChanged: if (bright >= 0) brightUi = bright;
    onProfileChanged: profileUi = profile;
    function batTime(m) {
        if (m < 0) return "";
        const h = Math.floor(m / 60), mm = m % 60;
        return h > 0 ? h + "h" + (mm < 10 ? "0" : "") + mm + "m" : mm + "m";
    }
    property string kernel: ""
    property string osName: "Linux"
    property string activeApp: ""
    property bool caffeine: false       // keep-awake state (owned by shell.qml)
    signal caffeineToggled()

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color hl: skin ? skin.highlight : "#ffffff"
    readonly property color bg: skin ? skin.background : "#000000"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"

    width: 320
    spacing: 9

    function usageColor(v) {
        if (v < 0) return sp.dim;
        if (v > 88) return "#ff5555";
        if (v > 65) return "#ffb454";
        return sp.ac;
    }
    // accent sampled from the rolling rainbow band at a global x (solid accent when rainbow off)
    function acAt(px) { return sp.skin ? sp.skin.bandAt(px) : sp.ac; }

    // Open a tray item's context menu, anchored to the window just below the icon. Renders via the
    // window's custom TrayMenu (not item.display(), whose clicks don't land on Hyprland layer-shell).
    function openTrayMenu(item, anchorItem) {
        if (!item.hasMenu || !sp.hostWin) return;
        const p = anchorItem.mapToItem(null, 0, anchorItem.height);
        sp.hostWin.showTrayMenu(item.menu, p.x, p.y, 1);
    }

    // ---- Header: OS logo + name + kernel  (battery right-aligned, laptop only) ----
    Item {
        width: sp.width
        height: hdrLeft.height
        Row {
            id: hdrLeft
            spacing: 10
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCharCode(0xf303)   // Arch logo (Nerd Font)
                font.family: "Symbols Nerd Font"; font.pixelSize: 26
                color: sp.acAt(mapToItem(null, width / 2, 0).x)
            }
            Column {
                spacing: 1
                Text { text: sp.osName; color: sp.fg; font.family: sp.fam; font.pixelSize: 14; font.weight: 600 }
                Text { text: sp.kernel; color: sp.dim; font.family: sp.fam; font.pixelSize: 11 }
            }
        }
        // Caffeine (keep-awake) toggle - small round coffee button just right of the OS info.
        Rectangle {
            id: caffeineBtn
            // right-aligned (big gap from the OS info); sits left of the battery when it's shown (laptop)
            anchors.right: batRow.visible ? batRow.left : parent.right
            anchors.rightMargin: batRow.visible ? 12 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26; radius: width / 2
            readonly property bool on: sp.caffeine
            color: caffeineBtn.on ? sp.acAt(mapToItem(null, width / 2, 0).x)
                                  : Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, cma.containsMouse ? 0.16 : 0.07)
            border.width: 1
            border.color: caffeineBtn.on ? "transparent"
                                         : Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, cma.containsMouse ? 0.35 : 0.18)
            Behavior on color { ColorAnimation { duration: 130 } }
            scale: cma.containsMouse ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Text {
                anchors.centerIn: parent
                text: String.fromCharCode(0xf0f4)   // coffee mug (Nerd Font) = keep-awake
                font.family: "Symbols Nerd Font"; font.pixelSize: 13
                color: caffeineBtn.on ? Qt.rgba(sp.bg.r, sp.bg.g, sp.bg.b, 1) : sp.fg
            }
            MouseArea {
                id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: sp.caffeineToggled()
            }
        }
        // Battery: hidden on machines without one (sp.bat stays -1). Bolt shows while charging.
        Row {
            id: batRow
            visible: sp.bat >= 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: sp.batCharging
                text: String.fromCharCode(0xf0e7)   // bolt
                font.family: "Symbols Nerd Font"; font.pixelSize: 11; color: "#7cfc72"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCharCode(sp.batGlyph)
                font.family: "Symbols Nerd Font"; font.pixelSize: 16; color: sp.batColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sp.bat + "%"
                color: sp.fg; font.family: sp.fam; font.pixelSize: 12
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.12) }

    // ---- CPU / RAM / GPU rows ----
    Repeater {
        model: [
            { l: "CPU", v: sp.cpu, t: sp.cpuTemp },
            { l: "RAM", v: sp.ram, t: -1 },
            { l: "GPU", v: sp.gpu, t: sp.gpuTemp },
            { l: "DISK", v: sp.disk, t: -1 }
        ]
        delegate: Row {
            required property var modelData
            width: sp.width
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.l; color: sp.dim
                font.family: sp.fam; font.pixelSize: 12; font.weight: 600
                width: 34
            }
            Rectangle {   // usage bar (track)
                anchors.verticalCenter: parent.verticalCenter
                width: 150; height: 8; radius: 4
                color: Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.12)
                Item {
                    id: fill
                    width: parent.width * Math.max(0, Math.min(100, modelData.v)) / 100
                    height: parent.height; clip: true
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    readonly property bool hot: modelData.v > 65
                    // rolling rainbow on normal load; solid warning colour when hot (or no rainbow)
                    BandRect { anchors.fill: parent; skin: sp.skin; visible: sp.skin && sp.skin.rainbow && !fill.hot }
                    Rectangle { anchors.fill: parent; radius: 4; color: sp.usageColor(modelData.v)
                        visible: !(sp.skin && sp.skin.rainbow) || fill.hot }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (modelData.v >= 0 ? modelData.v + "%" : "—")
                      + (modelData.t >= 0 ? "  " + modelData.t + "°" : "")
                color: sp.fg; font.family: sp.fam; font.pixelSize: 12
            }
        }
    }

    // ---- Laptop controls (each shows only when its hardware / daemon is present) ----
    // Battery detail: % + time to empty/full + health.
    Text {
        visible: sp.bat >= 0
        width: sp.width
        color: sp.dim; font.family: sp.fam; font.pixelSize: 11
        text: {
            let s = sp.bat + "%";
            const t = sp.batTime(sp.batMin);
            if (t.length) s += "  ·  " + t + (sp.batCharging ? " until full" : " left");
            if (sp.batHealth >= 0) s += "  ·  health " + sp.batHealth + "%";
            return s;
        }
    }
    // Brightness slider (needs a backlight; set via brightnessctl).
    Row {
        visible: sp.bright >= 0
        width: sp.width; spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter; width: 22
            text: String.fromCharCode(0xf185)   // sun
            font.family: "Symbols Nerd Font"; font.pixelSize: 16; color: sp.fg
        }
        Rectangle {
            id: brTrack
            anchors.verticalCenter: parent.verticalCenter
            width: sp.width - 22 - 50; height: 8; radius: 4
            color: Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.12)
            Item {
                width: brTrack.width * Math.max(0, Math.min(1, sp.brightUi / 100))
                height: parent.height; clip: true
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                BandRect { anchors.fill: parent; skin: sp.skin; visible: sp.skin && sp.skin.rainbow }
                Rectangle { anchors.fill: parent; radius: 4; visible: !(sp.skin && sp.skin.rainbow); color: sp.ac }
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -7
                function setb(x) {
                    const pct = Math.max(1, Math.min(100, Math.round(x / brTrack.width * 100)));
                    sp.brightUi = pct;   // instant feedback; stream confirms within 2s
                    Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
                }
                onPressed: (m) => setb(m.x)
                onPositionChanged: (m) => { if (pressed) setb(m.x); }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter; width: 40; horizontalAlignment: Text.AlignRight
            text: sp.brightUi + "%"; color: sp.fg; font.family: sp.fam; font.pixelSize: 12
        }
    }
    // Power-profile switcher (needs power-profiles-daemon; set via powerprofilesctl).
    Row {
        visible: sp.profile !== ""
        width: sp.width; spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter; width: 22
            text: String.fromCharCode(0xf0e7)   // bolt
            font.family: "Symbols Nerd Font"; font.pixelSize: 15; color: sp.dim
        }
        Repeater {
            model: [
                { id: "power-saver", l: "Saver" },
                { id: "balanced",    l: "Balanced" },
                { id: "performance", l: "Perf" }
            ]
            delegate: Rectangle {
                required property var modelData
                readonly property bool active: sp.profileUi === modelData.id
                width: (sp.width - 22 - 18) / 3; height: 24; radius: 7
                color: active ? Qt.rgba(sp.ac.r, sp.ac.g, sp.ac.b, 0.22)
                              : (pma.containsMouse ? Qt.rgba(sp.hl.r, sp.hl.g, sp.hl.b, 0.10) : "transparent")
                border.width: active ? 0 : 1
                border.color: Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.15)
                Text {
                    anchors.centerIn: parent
                    text: modelData.l
                    color: sp.fg; font.family: sp.fam; font.pixelSize: 11
                    font.weight: parent.active ? 600 : 400
                }
                MouseArea {
                    id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sp.profileUi = modelData.id;   // instant feedback; stream confirms within 2s
                        Quickshell.execDetached(["powerprofilesctl", "set", modelData.id]);
                    }
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.12) }

    // ---- Active window ----
    Row {
        spacing: 8
        width: sp.width
        Text { text: "Focus"; color: sp.dim; font.family: sp.fam; font.pixelSize: 12; font.weight: 600; width: 34 }
        Text {
            text: sp.activeApp.length ? sp.activeApp : "—"
            color: sp.fg; font.family: sp.fam; font.pixelSize: 12; elide: Text.ElideRight
            width: sp.width - 50
        }
    }

    // ---- Tray (plain Row, NOT a Flickable - a Flickable under the transparent hover
    //      overlay swallows the clicks; the Level 1 buttons work because they're a plain Row).
    //      left = activate, middle = secondary, right = context menu (anchored to the window). ----
    Row {
        id: trayRow
        spacing: 12; height: 26
        visible: SystemTray.items && SystemTray.items.values.length > 0
        Repeater {
            model: SystemTray.items
            delegate: Item {
                id: trayItem
                required property var modelData
                width: 22; height: 26
                Image {
                    anchors.centerIn: parent
                    width: 18; height: 18; sourceSize.width: 18; sourceSize.height: 18
                    source: trayItem.modelData.icon; smooth: true
                    scale: trayMA.containsMouse ? 1.18 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: trayMA
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => {
                        const it = trayItem.modelData;
                        try {
                            if (m.button === Qt.LeftButton) {
                                if (it.onlyMenu) sp.openTrayMenu(it, trayItem);   // appindicator: no activate, menu only
                                else it.activate();                               // raise/toggle the app window
                            } else if (m.button === Qt.MiddleButton) {
                                // hard-close: resolve the app's PID via D-Bus and terminate it (SIGTERM->SIGKILL)
                                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/hyprslob/tray-kill.sh",
                                                         it.id || "", it.title || ""]);
                            } else if (m.button === Qt.RightButton) {
                                sp.openTrayMenu(it, trayItem);                    // some apps export a broken/empty menu (e.g. Betterbird) -> nothing to show
                            }
                        } catch (e) {
                            console.log("[hyprslob tray] action failed:", e);
                        }
                    }
                }
            }
        }
    }
}
