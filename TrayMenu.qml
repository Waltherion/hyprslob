// TrayMenu.qml - in-window tray context menu overlay. Rendered INSIDE the bar window, not as a
// separate popup: popup surfaces don't receive pointer clicks on this layer-shell setup, but the
// bar window does (the tray icons get clicks). The host grows the window to full height and drops
// the input mask while this is open, so a tall menu can be reached and clicked. Closes on: a leaf
// selection, a click outside the box, or the hub collapsing.
import QtQuick
import Quickshell

Item {
    id: menu
    property var skin
    property var handle: null     // QsMenuHandle to show; null = hidden
    property real menuX: 0
    property real menuY: 0
    signal dismissed()

    anchors.fill: parent
    z: 1000
    visible: handle !== null

    readonly property real menuW: 230

    function open(h, x, y) { menu.menuX = x; menu.menuY = y; menu.handle = h; }
    function close() { if (menu.handle) { menu.handle = null; menu.dismissed(); } }

    // Backdrop: transparent (the hub stays visible behind it); a click outside the box closes.
    MouseArea { anchors.fill: parent; onClicked: menu.close() }

    Rectangle {
        id: box
        width: menu.menuW
        x: Math.max(6, Math.min(menu.menuX, menu.width - menu.menuW - 6))
        y: Math.max(6, Math.min(menu.menuY, menu.height - height - 6))
        implicitHeight: list.implicitHeight + 10
        height: implicitHeight
        radius: 10
        color: menu.skin ? menu.skin.background : "#1e1e2e"
        border.width: 1
        border.color: menu.skin ? Qt.rgba(menu.skin.text.r, menu.skin.text.g, menu.skin.text.b, 0.18) : "#444"

        // swallow clicks on the box background so they don't fall through to the backdrop
        MouseArea { anchors.fill: parent }

        MenuList {
            id: list
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 5 }
            skin: menu.skin
            handle: menu.handle
            onRequestClose: menu.close()
        }
    }
}
