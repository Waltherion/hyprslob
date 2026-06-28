// ThemePickerPanel.qml - a scrollable thumbnail GRID for picking a theme, modelled on
// WallpaperPanel but with a search field (themes are named/searchable), the theme name under each
// tile, and the theme's colour palette as a small pill overlaid on the preview image. Driven by
// shell.qml's `themes` IPC (theme-pick.sh feeds it label\timage\tcolors\tdir lines). Emits
// chosen(dir)/cancelled - shell.qml writes the result + collapses.
import QtQuick
import Quickshell

Item {
    id: tp
    property var skin
    property var entries: []        // [{ label, image, colors:[hex], dir }]
    property string prompt: "Theme: "
    signal chosen(string dir)
    signal cancelled()

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    function acAt(px) { return tp.skin ? tp.skin.bandAt(px) : tp.ac; }

    property int cols: 3
    property int cellW: 230
    readonly property int thumbH: Math.round(cellW * 9 / 16)
    readonly property int labelH: 22
    readonly property int cellSpacing: 4
    readonly property int cellH: thumbH + cellSpacing + labelH
    property int maxRows: 5
    readonly property int headerH: 38

    property string query: ""
    property int sel: 0

    // ---- fuzzy filtering (same scoring as DmenuPanel) ----
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
        const q = tp.query.toLowerCase().trim();
        const out = [];
        for (let i = 0; i < tp.entries.length; i++) {
            const e = tp.entries[i];
            const m = tp.matchScore((e.label || "").toLowerCase(), q);
            if (m < 0) continue;
            out.push({ e: e, m: m, i: i });
        }
        out.sort((a, b) => (b.m - a.m) || (a.i - b.i));   // best match, else original order
        return out.map(o => o.e);
    }
    onFilteredChanged: if (tp.sel >= filtered.length) tp.sel = Math.max(0, filtered.length - 1);

    readonly property int gridRows: Math.max(1, Math.min(Math.ceil(filtered.length / cols), maxRows))
    implicitWidth: cols * cellW + 8
    implicitHeight: headerH + 8 + gridRows * cellH

    function commit() {
        if (tp.sel >= 0 && tp.sel < tp.filtered.length) tp.chosen(tp.filtered[tp.sel].dir);
        else tp.cancelled();
    }
    function navKey(e) {
        if (e.key === Qt.Key_Escape) { tp.cancelled(); e.accepted = true; }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { tp.commit(); e.accepted = true; }
        else if (e.key === Qt.Key_Right) { tp.sel = Math.min(tp.sel + 1, tp.filtered.length - 1); e.accepted = true; }
        else if (e.key === Qt.Key_Left) { tp.sel = Math.max(tp.sel - 1, 0); e.accepted = true; }
        else if (e.key === Qt.Key_Down) { tp.sel = Math.min(tp.sel + tp.cols, tp.filtered.length - 1); e.accepted = true; }
        else if (e.key === Qt.Key_Up) { tp.sel = Math.max(tp.sel - tp.cols, 0); e.accepted = true; }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // Header: search field (reused from DmenuPanel) with rainbow prompt, live count, blinking cursor.
        Item {
            width: parent.width
            height: tp.headerH
            Rectangle {
                anchors.fill: parent; radius: 9
                color: Qt.rgba(tp.fg.r, tp.fg.g, tp.fg.b, 0.06)
                border.width: 1; border.color: Qt.rgba(tp.fg.r, tp.fg.g, tp.fg.b, 0.12)
                RainbowLabel {
                    id: promptT
                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    content: tp.prompt.length ? tp.prompt : "❯"
                    family: tp.fam; pixelSize: 15; fontWeight: 700
                    rainbow: !!(tp.skin && tp.skin.isRainbow("text"))
                    stops: tp.skin ? tp.skin.stops : []
                    phase: tp.skin ? tp.skin.phase : 0
                    period: tp.skin ? tp.skin.bandPeriod : 420
                    solid: tp.ac
                }
                Text {
                    id: countT
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    text: tp.filtered.length; color: tp.dim; font.family: tp.fam; font.pixelSize: 12
                }
                TextInput {
                    id: input
                    anchors.left: promptT.right; anchors.leftMargin: 8
                    anchors.right: countT.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: tp.fg; font.family: tp.fam; font.pixelSize: 14
                    clip: true
                    onTextChanged: { tp.query = text; tp.sel = 0; }
                    Keys.onPressed: (e) => tp.navKey(e)
                    cursorDelegate: Rectangle {
                        width: 2; height: input.cursorRectangle.height
                        color: tp.acAt(mapToItem(null, width / 2, 0).x)
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: input.cursorVisible
                            NumberAnimation { to: 0; duration: 480 }
                            NumberAnimation { to: 1; duration: 480 }
                        }
                    }
                }
            }
        }

        // Grid
        Item {
            id: gridArea
            width: parent.width
            height: tp.gridRows * tp.cellH
            GridView {
                id: gv
                anchors.fill: parent; clip: true
                cellWidth: tp.cellW; cellHeight: tp.cellH
                model: tp.filtered
                currentIndex: tp.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: tp.cellW; height: tp.cellH
                    Column {
                        anchors.fill: parent; anchors.margins: 4; spacing: tp.cellSpacing
                        // Thumbnail card with colour pill overlay
                        Rectangle {
                            width: parent.width; height: tp.thumbH; radius: 8; clip: true
                            color: Qt.rgba(tp.fg.r, tp.fg.g, tp.fg.b, 0.05)
                            border.width: index === tp.sel ? 2 : 1
                            border.color: index === tp.sel ? tp.acAt(mapToItem(null, width / 2, 0).x)
                                                           : Qt.rgba(tp.fg.r, tp.fg.g, tp.fg.b, 0.10)
                            Image {
                                anchors.fill: parent; anchors.margins: index === tp.sel ? 2 : 1
                                source: modelData.image ? ("file://" + modelData.image) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true; cache: true
                                visible: status === Image.Ready
                            }
                            Rectangle {   // subtle accent tint on the selected cell
                                anchors.fill: parent; visible: index === tp.sel
                                color: Qt.rgba(tp.ac.r, tp.ac.g, tp.ac.b, 0.12)
                            }
                            Rectangle {   // colour pill (theme palette) overlaid bottom-centre
                                visible: !!(modelData.colors && modelData.colors.length > 0)
                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 8
                                width: pillRow.width + 14; height: 20; radius: 10
                                color: Qt.rgba(0, 0, 0, 0.55)
                                Row {
                                    id: pillRow
                                    anchors.centerIn: parent; spacing: 5
                                    Repeater {
                                        model: modelData.colors
                                        delegate: Rectangle {
                                            width: 10; height: 10; radius: 5; color: modelData
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                                        }
                                    }
                                }
                            }
                        }
                        // Theme name
                        Item {
                            width: parent.width; height: tp.labelH; clip: true
                            opacity: index === tp.sel ? 1 : 0.75
                            RainbowLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                content: modelData.label
                                family: tp.fam; pixelSize: 13; fontWeight: index === tp.sel ? 600 : 400
                                rainbow: !!(tp.skin && tp.skin.isRainbow("text"))
                                stops: tp.skin ? tp.skin.stops : []
                                phase: tp.skin ? tp.skin.phase : 0
                                period: tp.skin ? tp.skin.bandPeriod : 420
                                solid: tp.fg
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: tp.sel = index
                        onClicked: { tp.sel = index; tp.commit(); }
                    }
                }
            }
        }
    }
    Component.onCompleted: input.forceActiveFocus()
}
