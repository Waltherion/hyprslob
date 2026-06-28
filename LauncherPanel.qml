// LauncherPanel.qml - in-bar app launcher (morph mode). Fuzzel-like: instant, keyboard-first,
// no flashy motion. Reuses Quickshell's DesktopEntries (app list + execute) and iconPath; adds
// subsequence-fuzzy matching + frecency ranking, persisted to ~/.local/state/hyprslob/launcher.json.
// Rendered inside the bar window (like the other panels) so keyboard + clicks land on layer-shell.
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: lp
    property var skin
    property int maxResults: 8
    signal panelClose()              // emitted on Esc / after launch -> shell collapses the hub

    spacing: 8

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    readonly property int rowH: 40
    // accent sampled from the rolling rainbow band at a global x (solid accent when rainbow is off)
    function acAt(px) { return lp.skin ? lp.skin.bandAt(px) : lp.ac; }

    property string query: ""
    property int sel: 0

    // ---- Frecency store (usage count + last-used, decayed by recency) ----
    property var freq: ({})
    FileView {
        id: freqFile
        path: Quickshell.env("HOME") + "/.local/state/hyprslob/launcher.json"
        onLoaded: { try { lp.freq = JSON.parse(freqFile.text() || "{}") || ({}); } catch (e) { lp.freq = ({}); } }
        onLoadFailed: lp.freq = ({})
    }
    function freqKey(a) { return (a && (a.id || a.name)) || ""; }
    function freqScore(a) {
        const e = lp.freq[lp.freqKey(a)];
        if (!e) return 0;
        const days = (Date.now() - (e.t || 0)) / 86400000;
        return (e.c || 0) / (1 + days);
    }
    function bump(a) {
        const k = lp.freqKey(a); if (!k) return;
        const e = lp.freq[k] || { c: 0, t: 0 };
        e.c = (e.c || 0) + 1; e.t = Date.now();
        lp.freq[k] = e; lp.freq = lp.freq;          // reassign to notify
        freqFile.setText(JSON.stringify(lp.freq));
    }

    // ---- Fuzzy match: prefix(3) > substring(2) > subsequence(1); -1 = no match ----
    function matchScore(hay, q) {
        if (!q.length) return 0;
        const i = hay.indexOf(q);
        if (i === 0) return 3;
        if (i > 0) return 2;
        let j = 0;
        for (let k = 0; k < hay.length && j < q.length; k++) if (hay[k] === q[j]) j++;
        return j === q.length ? 1 : -1;
    }

    readonly property var filtered: {
        const all = DesktopEntries.applications.values;
        const q = lp.query.toLowerCase().trim();
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const a = all[i];
            if (!a || a.noDisplay) continue;
            const hay = ((a.name || "") + " " + (a.genericName || "")).toLowerCase();
            const m = lp.matchScore(hay, q);
            if (m < 0) continue;
            out.push({ a: a, m: m, f: lp.freqScore(a) });
        }
        // rank: match quality, then frecency, then name
        out.sort((x, y) => (y.m - x.m) || (y.f - x.f) || (x.a.name || "").localeCompare(y.a.name || ""));
        return out.map(o => o.a);
    }
    onFilteredChanged: if (lp.sel >= filtered.length) lp.sel = Math.max(0, filtered.length - 1);

    // Terminal-apps (Terminal=true, fx btop/htop) har ingen GUI — Quickshells execute() kan
    // ikke vise dem uden en terminal. Pak dem i $TERMINAL (fallback kitty) så de åbner i et vindue.
    function launch(a) {
        if (!a) return;
        lp.bump(a);
        if (a.runInTerminal) {
            const term = Quickshell.env("TERMINAL") || "kitty";
            const cmd = (a.command && a.command.length) ? a.command.join(" ") : (a.exec || a.name);
            Quickshell.execDetached([term, "-e", "sh", "-c", cmd]);
        } else {
            a.execute();
        }
        lp.panelClose();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/hyprslob"]);
        input.forceActiveFocus();   // text field ready immediately - type while the box morphs open
    }

    // ---- Search field ----
    Rectangle {
        width: parent.width
        height: 40
        radius: 10
        color: Qt.rgba(lp.fg.r, lp.fg.g, lp.fg.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(lp.fg.r, lp.fg.g, lp.fg.b, 0.12)
        Row {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "❯"   // heavy right angle (prompt)
                color: lp.acAt(mapToItem(null, width / 2, 0).x)
                font.family: lp.fam; font.pixelSize: 16; font.bold: true
            }
            TextInput {
                id: input
                width: parent.width - 22 - 38
                anchors.verticalCenter: parent.verticalCenter
                color: lp.fg; font.family: lp.fam; font.pixelSize: 15
                clip: true; focus: true
                cursorDelegate: Rectangle {
                    width: 2
                    height: input.cursorRectangle.height
                    color: lp.acAt(mapToItem(null, width / 2, 0).x)   // rainbow-band cursor
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite; running: input.cursorVisible
                        NumberAnimation { to: 0; duration: 480 }
                        NumberAnimation { to: 1; duration: 480 }
                    }
                }
                onTextChanged: { lp.query = text; lp.sel = 0; }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) { lp.sel = Math.min(lp.sel + 1, lp.filtered.length - 1); e.accepted = true; }
                    else if (e.key === Qt.Key_Up) { lp.sel = Math.max(lp.sel - 1, 0); e.accepted = true; }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { lp.launch(lp.filtered[lp.sel]); e.accepted = true; }
                    else if (e.key === Qt.Key_Escape) { lp.panelClose(); e.accepted = true; }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: "Search apps…"; color: lp.dim; font: input.font
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 30; horizontalAlignment: Text.AlignRight
                text: lp.filtered.length; color: lp.dim; font.family: lp.fam; font.pixelSize: 12
            }
        }
    }

    // ---- Results: fixed height (no resize while typing -> snappy), scrolls past maxResults ----
    Item {
        width: parent.width
        height: lp.maxResults * lp.rowH
        ListView {
            id: listv
            anchors.fill: parent
            clip: true
            model: lp.filtered
            currentIndex: lp.sel
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            boundsBehavior: Flickable.StopAtBounds
            visible: lp.filtered.length > 0
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: lp.rowH
                radius: 8
                color: index === lp.sel ? Qt.rgba(lp.ac.r, lp.ac.g, lp.ac.b, 0.20) : "transparent"
                Rectangle {
                    visible: index === lp.sel
                    width: 3; radius: 2; color: lp.acAt(mapToItem(null, width / 2, 0).x)
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom
                        topMargin: 7; bottomMargin: 7; leftMargin: 4 }
                }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 11
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; sourceSize.width: 24; sourceSize.height: 24
                        source: Quickshell.iconPath(modelData.icon || "", "application-x-executable")
                        smooth: true
                    }
                    // App name as a "window" into the rolling rainbow band (each glyph colored by
                    // its own global x), continuous with the clock - not one flat rotating color.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 - 11
                        height: nameLabel.height
                        clip: true
                        RainbowLabel {
                            id: nameLabel
                            content: modelData.name || ""
                            family: lp.fam; pixelSize: 14; fontWeight: 400
                            rainbow: !!(lp.skin && lp.skin.isRainbow("text"))
                            stops: lp.skin ? lp.skin.stops : []
                            phase: lp.skin ? lp.skin.phase : 0
                            period: lp.skin ? lp.skin.bandPeriod : 420
                            solid: lp.fg
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: lp.sel = index
                    onClicked: { lp.sel = index; lp.launch(modelData); }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: lp.filtered.length === 0
            text: lp.query.length ? "No matches" : "Type to search"
            color: lp.dim; font.family: lp.fam; font.pixelSize: 13
        }
    }
}
