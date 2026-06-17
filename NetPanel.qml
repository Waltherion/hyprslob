// Level 2 - net panel, three separate boxes:
//   1) Network  - status only (what you're connected to: Wired / Wi-Fi SSID / Not connected). No toggle.
//   2) Wi-Fi    - radio toggle + gear (nm-connection-editor), on equal footing with Bluetooth.
//   3) Bluetooth- radio toggle + gear (blueman) + paired/connected device list.
// Theme-driven via `skin`. Connection status comes reactively from Quickshell.Networking.devices
// (each NetworkDevice has type [DeviceType.Wired/Wifi/None], connected, and networks).
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

    // ---- connection status (reactive, from NetworkManager via Quickshell.Networking) ----
    readonly property var _devs: (Networking.devices && Networking.devices.values) ? Networking.devices.values : []
    function _connName(d) {
        if (!d) return "";
        if (d.network && d.network.name) return d.network.name;
        var nets = (d.networks && d.networks.values) ? d.networks.values : [];
        for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].connected) return nets[i].name;
        return "";
    }
    readonly property var _wired: {
        for (var i = 0; i < _devs.length; i++) { var d = _devs[i];
            if (d && d.connected && d.type === DeviceType.Wired) return d; }
        return null;
    }
    readonly property var _wifiConn: {
        for (var i = 0; i < _devs.length; i++) { var d = _devs[i];
            if (d && d.connected && d.type === DeviceType.Wifi) return d; }
        return null;
    }
    readonly property string netTitle: _wired ? "Wired"
                                      : (_wifiConn ? (_connName(_wifiConn) || "Wi-Fi") : "Not connected")
    readonly property string netIcon: _wired ? String.fromCharCode(0xf0e8)        // sitemap (wired)
                                      : (_wifiConn ? String.fromCharCode(0xf1eb)   // wifi
                                                   : String.fromCharCode(0xf127))  // unlink (offline)
    readonly property bool   netUp: !!(_wired || _wifiConn)

    // ---- shared bits ----
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

    // =========================== Box 1: Network (status) ===========================
    Rectangle {
        width: np.width; radius: 10
        color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.05)
        border.width: 1; border.color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.09)
        implicitHeight: netRow.implicitHeight + 20
        Row {
            id: netRow
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12; topMargin: 10 }
            spacing: 11
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: np.netIcon; font.family: "Symbols Nerd Font"; font.pixelSize: 20
                color: np.netUp ? np.acAt(mapToItem(null, width / 2, 0).x) : np.dim
            }
            Column {
                spacing: 1
                Text { text: "Network"; color: np.dim; font.family: np.fam; font.pixelSize: 12; font.weight: 600 }
                Text { text: np.netTitle; color: np.fg; font.family: np.fam; font.pixelSize: 13 }
            }
        }
    }

    // =========================== Box 2: Wi-Fi (toggle) ===========================
    Rectangle {
        width: np.width; radius: 10
        color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.05)
        border.width: 1; border.color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.09)
        implicitHeight: wifiCol.implicitHeight + 20
        Column {
            id: wifiCol
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12; topMargin: 10 }
            spacing: 4
            Item {
                width: parent.width; height: 22
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"; color: np.fg; font.family: np.fam; font.pixelSize: 12; font.weight: 600 }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Toggle { anchors.verticalCenter: parent.verticalCenter; on: Networking.wifiEnabled
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled }
                    Gear { anchors.verticalCenter: parent.verticalCenter; act: function () { Quickshell.execDetached(["nm-connection-editor"]); } }
                }
            }
            Text {
                text: Networking.wifiEnabled ? (np._wifiConn ? ("Connected to " + (np._connName(np._wifiConn) || "Wi-Fi")) : "On") : "Off"
                color: np.dim; font.family: np.fam; font.pixelSize: 11
            }
        }
    }

    // =========================== Box 3: Bluetooth (toggle + devices) ===========================
    Rectangle {
        width: np.width; radius: 10
        color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.05)
        border.width: 1; border.color: Qt.rgba(np.fg.r, np.fg.g, np.fg.b, 0.09)
        implicitHeight: btCol.implicitHeight + 20
        Column {
            id: btCol
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12; topMargin: 10 }
            spacing: 4
            Item {
                width: parent.width; height: 22
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"; color: np.fg; font.family: np.fam; font.pixelSize: 12; font.weight: 600 }
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
                    width: btCol.width; height: show ? 28 : 0; radius: 7
                    color: dma.containsMouse ? Qt.rgba(np.hl.r, np.hl.g, np.hl.b, 0.10) : "transparent"
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 78; elide: Text.ElideRight
                        text: modelData ? (modelData.name || modelData.address || "") : ""
                        color: np.fg; font.family: np.fam; font.pixelSize: 12
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
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
    }
}
