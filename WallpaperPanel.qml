// WallpaperPanel.qml - a scrollable thumbnail GRID for picking a wallpaper from the
// current theme. Driven by shell.qml's `wallpapers` IPC (wallpaper-pick.sh feeds it
// label\tthumbnail\tpath lines). Emits chosen(path)/cancelled - shell.qml writes the
// result + collapses. No search: images aren't named anything searchable.
import QtQuick
import Quickshell

Item {
    id: wp
    property var skin
    property var entries: []        // [{ label, image, path }]
    signal chosen(string path)
    signal cancelled()

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    function acAt(px) { return wp.skin ? wp.skin.bandAt(px) : wp.ac; }

    property int cols: 3
    property int cellW: 230
    readonly property int thumbH: Math.round(cellW * 9 / 16)
    readonly property int cellH: thumbH
    property int maxRows: 4
    property int sel: 0

    readonly property int gridRows: Math.max(1, Math.min(Math.ceil(entries.length / cols), maxRows))
    implicitWidth: cols * cellW + 8
    implicitHeight: 26 + 8 + gridRows * cellH

    function commit() {
        if (sel >= 0 && sel < entries.length) wp.chosen(entries[sel].path);
        else wp.cancelled();
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // Title + count
        Item {
            width: parent.width
            height: 26
            RainbowLabel {
                anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter
                content: "Wallpapers"
                family: wp.fam; pixelSize: 14; fontWeight: 600
                rainbow: !!(wp.skin && wp.skin.isRainbow("text"))
                stops: wp.skin ? wp.skin.stops : []
                phase: wp.skin ? wp.skin.phase : 0
                period: wp.skin ? wp.skin.bandPeriod : 420
                solid: wp.ac
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                text: wp.entries.length; color: wp.dim; font.family: wp.fam; font.pixelSize: 12
            }
        }

        // Grid
        Item {
            id: gridArea
            width: parent.width
            height: wp.gridRows * wp.cellH
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { wp.cancelled(); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { wp.commit(); e.accepted = true; }
                else if (e.key === Qt.Key_Right) { wp.sel = Math.min(wp.sel + 1, wp.entries.length - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Left) { wp.sel = Math.max(wp.sel - 1, 0); e.accepted = true; }
                else if (e.key === Qt.Key_Down) { wp.sel = Math.min(wp.sel + wp.cols, wp.entries.length - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Up) { wp.sel = Math.max(wp.sel - wp.cols, 0); e.accepted = true; }
            }
            GridView {
                id: gv
                anchors.fill: parent; clip: true
                cellWidth: wp.cellW; cellHeight: wp.cellH
                model: wp.entries
                currentIndex: wp.sel
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: wp.cellW; height: wp.cellH
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4; radius: 8; clip: true
                        color: Qt.rgba(wp.fg.r, wp.fg.g, wp.fg.b, 0.05)
                        border.width: index === wp.sel ? 2 : 1
                        border.color: index === wp.sel ? wp.acAt(mapToItem(null, width / 2, 0).x)
                                                       : Qt.rgba(wp.fg.r, wp.fg.g, wp.fg.b, 0.10)
                        Image {
                            anchors.fill: parent; anchors.margins: index === wp.sel ? 2 : 1
                            source: modelData.image ? ("file://" + modelData.image) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            visible: status === Image.Ready
                        }
                        Rectangle {   // subtle accent tint on the selected cell
                            anchors.fill: parent; visible: index === wp.sel
                            color: Qt.rgba(wp.ac.r, wp.ac.g, wp.ac.b, 0.12)
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: wp.sel = index
                            onClicked: { wp.sel = index; wp.commit(); }
                        }
                    }
                }
            }
        }
    }
    Component.onCompleted: gridArea.forceActiveFocus()
}
