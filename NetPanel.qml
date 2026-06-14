// Level 2 - net/BT panel. Wifi toggle + gear->nm-connection-editor;
// Bluetooth toggle + device list (click = connect/disconnect) + gear->blueman.
// (Walther is on wired -> wifi network list omitted; the gear opens the full manager.)
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

Column {
    id: np
    property var skin
    width: 320; spacing: 8
    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color hl: skin ? skin.highlight : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    // accent sampled from the rolling rainbow band at a global x (solid accent when rainbow off)
    function acAt(px) { return np.skin ? np.skin.bandAt(px) : np.ac; }

    // small toggle pill
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled()
        width: 36; height: 19; radius: 10
        color: on ? np.acAt(mapToItem(null, width / 2, 0).x) : Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.18)
        Behavior on color { ColorAnimation { duration: 130 } }
        Rectangle {
            width: 15; height: 15; radius: 8; y: 2
            x: tg.on ? tg.width - width - 2 : 2
            color: tg.on ? Qt.rgba(np.skin ? np.skin.background.r : 0, np.skin ? np.skin.background.g : 0, np.skin ? np.skin.background.b : 0, 1) : np.fg
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }
    component Gear: Text {
        property var act
        text: String.fromCharCode(0xf013)
        font.family: "Symbols Nerd Font"; font.pixelSize: 14; color: np.dim
        MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: parent.act() }
    }

    // ---- Network ----
    Item {
        width: np.width; height: 22
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: "Network"; color: np.dim; font.family: np.fam; font.pixelSize: 12; font.weight: 600 }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 12
            Toggle { anchors.verticalCenter: parent.verticalCenter; on: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled }
            Gear { anchors.verticalCenter: parent.verticalCenter; act: function () { Quickshell.execDetached(["nm-connection-editor"]); } }
        }
    }
    Text { text: Networking.wifiEnabled ? "WiFi on" : "WiFi off (wired)"; color: np.dim; font.family: np.fam; font.pixelSize: 11 }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.12) }

    // ---- Bluetooth ----
    Item {
        width: np.width; height: 22
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"; color: np.dim; font.family: np.fam; font.pixelSize: 12; font.weight: 600 }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 12
            Toggle { anchors.verticalCenter: parent.verticalCenter
                on: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                onToggled: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
            Gear { anchors.verticalCenter: parent.verticalCenter; act: function () { Quickshell.execDetached(["blueman-manager"]); } }
        }
    }

    Repeater {
        model: Bluetooth.devices
        delegate: Rectangle {
            required property var modelData
            readonly property bool show: modelData && (modelData.paired || modelData.connected)
            visible: show
            width: np.width; height: show ? 28 : 0; radius: 7
            color: dma.containsMouse ? Qt.rgba(np.hl.r, np.hl.g, np.hl.b, 0.10) : "transparent"
            Text {
                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80; elide: Text.ElideRight
                text: modelData ? (modelData.name || modelData.address || "") : ""
                color: np.fg; font.family: np.fam; font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: modelData && modelData.connected ? "connected" : "connect"
                color: modelData && modelData.connected ? np.acAt(mapToItem(null, width / 2, 0).x) : np.dim
                font.family: np.fam; font.pixelSize: 11
            }
            MouseArea {
                id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { if (!parent.modelData) return;
                    if (parent.modelData.connected) parent.modelData.disconnect(); else parent.modelData.connect(); }
            }
        }
    }
    Text {
        visible: !Bluetooth.devices || Bluetooth.devices.values.length === 0
        text: "No paired devices"; color: np.dim; font.family: np.fam; font.pixelSize: 11
    }
}
