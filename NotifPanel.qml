// Level 2 - notification panel: history + DnD toggle + clear-all.
import QtQuick

Column {
    id: nfp
    property var skin
    property var srv          // NotificationServer instance
    property bool dnd: false
    signal dndToggled()
    signal clearAllRequested()

    width: 320; spacing: 8
    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    readonly property int count: (srv && srv.trackedNotifications) ? srv.trackedNotifications.values.length : 0
    // accent sampled from the rolling rainbow band at a global x (solid accent when rainbow off)
    function acAt(px) { return nfp.skin ? nfp.skin.bandAt(px) : nfp.ac; }

    // ---- Header: title + DnD + clear all ----
    Item {
        width: nfp.width; height: 24
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"; color: nfp.dim; font.family: nfp.fam; font.pixelSize: 12; font.weight: 600 }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 12
            Rectangle {   // DnD toggle pill
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 19; radius: 10
                color: nfp.dnd ? nfp.acAt(mapToItem(null, width / 2, 0).x) : Qt.rgba(nfp.fg.r, nfp.fg.g, nfp.fg.b, 0.18)
                Behavior on color { ColorAnimation { duration: 130 } }
                Rectangle { width: 15; height: 15; radius: 8; y: 2; x: nfp.dnd ? parent.width - width - 2 : 2
                    color: nfp.dnd ? (nfp.skin ? nfp.skin.background : "#000") : nfp.fg
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nfp.dndToggled() }
            }
            Text {   // clear all
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCharCode(0xf1f8); font.family: "Symbols Nerd Font"; font.pixelSize: 14; color: nfp.dim
                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: nfp.clearAllRequested() }
            }
        }
    }

    // ---- History ----
    Flickable {
        width: nfp.width; height: Math.min(336, histCol.implicitHeight)
        contentHeight: histCol.implicitHeight; clip: true
        flickableDirection: Flickable.VerticalFlick
        visible: nfp.count > 0
        Column {
            id: histCol; width: nfp.width; spacing: 6
            Repeater {
                model: nfp.srv ? nfp.srv.trackedNotifications : null
                delegate: NotifCard { required property var modelData; notif: modelData; skin: nfp.skin; width: nfp.width }
            }
        }
    }
    Text {
        visible: nfp.count === 0
        text: nfp.dnd ? "Do not disturb (DnD on)" : "No notifications"
        color: nfp.dim; font.family: nfp.fam; font.pixelSize: 11
    }
}
