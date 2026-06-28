// DmenuPanel.qml - generic themed fuzzy picker rendered as a morph-down hub panel (like the
// launcher), with an OPTIONAL preview pane (image + a pill of theme colors). Driven by shell.qml's
// `menu` IPC (script choices) or by the menu button (config actions). Reuses the launcher's fuzzy
// matching + rainbow-band look. Emits chosen(label)/cancelled - shell.qml writes the result + collapses.
import QtQuick
import Quickshell

Row {
    id: dp
    property var skin
    property var entries: []        // [{ label, image, colors:[hex] }]
    property string prompt: ""
    property int maxResults: 12
    property int plainW: 520        // panel width when no previews
    property int previewListW: 380  // list width when previews are shown
    property int previewPaneW: 280  // preview pane width
    signal chosen(string label)
    signal cancelled()

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    readonly property int rowH: 32
    function acAt(px) { return dp.skin ? dp.skin.bandAt(px) : dp.ac; }

    readonly property bool hasPreviews: {
        for (let i = 0; i < entries.length; i++) if (entries[i] && entries[i].image && entries[i].image.length) return true;
        return false;
    }
    readonly property int listW: hasPreviews ? previewListW : plainW

    property string query: ""
    property int sel: 0
    spacing: hasPreviews ? 12 : 0

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
        const q = dp.query.toLowerCase().trim();
        const out = [];
        for (let i = 0; i < dp.entries.length; i++) {
            const e = dp.entries[i];
            const m = dp.matchScore((e.label || "").toLowerCase(), q);
            if (m < 0) continue;
            out.push({ e: e, m: m, i: i });
        }
        out.sort((a, b) => (b.m - a.m) || (a.i - b.i));   // best match, else original order
        return out.map(o => o.e);
    }
    onFilteredChanged: if (dp.sel >= filtered.length) dp.sel = Math.max(0, filtered.length - 1);
    readonly property var current: (sel >= 0 && sel < filtered.length) ? filtered[sel] : null

    function commit() {
        if (dp.filtered.length > 0 && dp.sel >= 0 && dp.sel < dp.filtered.length) dp.chosen(dp.filtered[dp.sel].label);
        else dp.cancelled();
    }
    property bool searchable: true   // false -> no search field / cursor (e.g. the menu palette)
    function navKey(e) {
        if (e.key === Qt.Key_Down) { dp.sel = Math.min(dp.sel + 1, dp.filtered.length - 1); e.accepted = true; }
        else if (e.key === Qt.Key_Up) { dp.sel = Math.max(dp.sel - 1, 0); e.accepted = true; }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { dp.commit(); e.accepted = true; }
        else if (e.key === Qt.Key_Escape) { dp.cancelled(); e.accepted = true; }
    }
    Component.onCompleted: (dp.searchable ? input : resultsArea).forceActiveFocus()

    // ---- Left: search + results ----
    Column {
        id: listCol
        width: dp.listW
        spacing: 8

        // Header: search field (searchable) OR a plain title (non-searchable, e.g. the menu palette)
        Item {
            width: parent.width
            height: dp.searchable ? 38 : (dp.prompt.length ? 26 : 0)
            Rectangle {   // search field
                visible: dp.searchable
                anchors.fill: parent; radius: 9
                color: Qt.rgba(dp.fg.r, dp.fg.g, dp.fg.b, 0.06)
                border.width: 1; border.color: Qt.rgba(dp.fg.r, dp.fg.g, dp.fg.b, 0.12)
                RainbowLabel {
                    id: promptT
                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    content: dp.prompt.length ? dp.prompt : "❯"
                    family: dp.fam; pixelSize: 15; fontWeight: 700
                    rainbow: !!(dp.skin && dp.skin.isRainbow("text"))
                    stops: dp.skin ? dp.skin.stops : []
                    phase: dp.skin ? dp.skin.phase : 0
                    period: dp.skin ? dp.skin.bandPeriod : 420
                    solid: dp.ac
                }
                Text {
                    id: countT
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    text: dp.filtered.length; color: dp.dim; font.family: dp.fam; font.pixelSize: 12
                }
                TextInput {
                    id: input
                    anchors.left: promptT.right; anchors.leftMargin: 8
                    anchors.right: countT.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: dp.fg; font.family: dp.fam; font.pixelSize: 14
                    clip: true
                    onTextChanged: { dp.query = text; dp.sel = 0; }
                    Keys.onPressed: (e) => dp.navKey(e)
                    cursorDelegate: Rectangle {
                        width: 2; height: input.cursorRectangle.height
                        color: dp.acAt(mapToItem(null, width / 2, 0).x)
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: input.cursorVisible
                            NumberAnimation { to: 0; duration: 480 }
                            NumberAnimation { to: 1; duration: 480 }
                        }
                    }
                }
            }
            RainbowLabel {   // plain title (non-searchable)
                visible: !dp.searchable && dp.prompt.length > 0
                anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter
                content: dp.prompt
                family: dp.fam; pixelSize: 13; fontWeight: 600
                rainbow: !!(dp.skin && dp.skin.isRainbow("text"))
                stops: dp.skin ? dp.skin.stops : []
                phase: dp.skin ? dp.skin.phase : 0
                period: dp.skin ? dp.skin.bandPeriod : 420
                solid: dp.ac
            }
        }

        // results - fixed height (based on entry count, not filtered) so the box doesn't jump while typing
        Item {
            id: resultsArea
            width: parent.width
            height: Math.max(1, Math.min(dp.entries.length, dp.maxResults)) * dp.rowH
            focus: !dp.searchable             // when there's no search field, the list captures keys
            Keys.onPressed: (e) => dp.navKey(e)
            ListView {
                id: lv
                anchors.fill: parent; clip: true
                model: dp.filtered
                currentIndex: dp.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width; height: dp.rowH; radius: 7
                    color: index === dp.sel ? Qt.rgba(dp.ac.r, dp.ac.g, dp.ac.b, 0.20) : "transparent"
                    Rectangle {
                        visible: index === dp.sel
                        width: 3; radius: 2; color: dp.acAt(mapToItem(null, width / 2, 0).x)
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6; leftMargin: 4 }
                    }
                    Item {   // label as a window into the rolling rainbow band (like the launcher)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 12
                        height: lbl.height; clip: true
                        RainbowLabel {
                            id: lbl
                            content: modelData.label
                            family: dp.fam; pixelSize: 13; fontWeight: 400
                            rainbow: !!(dp.skin && dp.skin.isRainbow("text"))
                            stops: dp.skin ? dp.skin.stops : []
                            phase: dp.skin ? dp.skin.phase : 0
                            period: dp.skin ? dp.skin.bandPeriod : 420
                            solid: dp.fg
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: dp.sel = index
                        onClicked: { dp.sel = index; dp.commit(); }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: dp.filtered.length === 0
                text: dp.query.length ? "No matches" : ""
                color: dp.dim; font.family: dp.fam; font.pixelSize: 13
            }
        }
    }

    // ---- Right: preview pane (image with a theme-colour pill overlaid) ----
    Item {
        id: previewPane
        visible: dp.hasPreviews
        width: dp.previewPaneW
        height: listCol.height
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: Math.round(width * 9 / 16)   // 16:9 preview
            radius: 10; clip: true
            color: Qt.rgba(dp.fg.r, dp.fg.g, dp.fg.b, 0.05)
            border.width: 1; border.color: Qt.rgba(dp.fg.r, dp.fg.g, dp.fg.b, 0.12)
            Image {
                anchors.fill: parent
                source: (dp.current && dp.current.image) ? ("file://" + dp.current.image) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; cache: true
                visible: status === Image.Ready
            }
            Rectangle {   // colour pill
                visible: !!(dp.current && dp.current.colors && dp.current.colors.length > 0)
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 10
                width: pillRow.width + 16; height: 22; radius: 11
                color: Qt.rgba(0, 0, 0, 0.55)
                Row {
                    id: pillRow
                    anchors.centerIn: parent; spacing: 5
                    Repeater {
                        model: dp.current ? dp.current.colors : []
                        delegate: Rectangle {
                            width: 12; height: 12; radius: 6; color: modelData
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }
                }
            }
        }
    }
}
