// MenuList.qml - renders a system-tray menu's entries from a QsMenuHandle, recursively.
// Submenus expand INLINE (indented) so the whole menu lives in one popup surface - this is
// what makes clicks land on Hyprland layer-shell, where SystemTrayItem.display() does not.
import QtQuick
import Quickshell

Column {
    id: list
    property var skin
    property var handle: null      // QsMenuHandle (an item's .menu, or a submenu entry)
    property int depth: 0
    signal requestClose()          // a leaf entry was triggered -> close the whole menu

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#8aadf4"
    readonly property string fam: skin ? skin.fontFamily : "Poppins"

    spacing: 1

    QsMenuOpener { id: opener; menu: list.handle }

    Repeater {
        model: opener.children
        delegate: Column {
            id: row
            required property var modelData
            width: list.width
            spacing: 1
            property bool expanded: false

            // separator
            Item {
                width: parent.width
                height: (row.modelData && row.modelData.isSeparator) ? 7 : 0
                visible: height > 0
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6; height: 1
                    color: Qt.rgba(list.fg.r, list.fg.g, list.fg.b, 0.15)
                }
            }
            // entry
            Rectangle {
                width: parent.width
                height: (row.modelData && !row.modelData.isSeparator) ? 28 : 0
                visible: height > 0
                radius: 6
                color: (rowMA.containsMouse && row.modelData && row.modelData.enabled)
                       ? Qt.rgba(list.ac.r, list.ac.g, list.ac.b, 0.22) : "transparent"
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 9 + list.depth * 11
                    anchors.right: chev.left; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData ? (row.modelData.text || "") : ""
                    color: (row.modelData && row.modelData.enabled)
                           ? list.fg : Qt.rgba(list.fg.r, list.fg.g, list.fg.b, 0.4)
                    font.family: list.fam; font.pixelSize: 12
                }
                Text {
                    id: chev
                    anchors.right: parent.right; anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!(row.modelData && row.modelData.hasChildren)
                    width: visible ? implicitWidth : 0
                    text: row.expanded ? "⌄" : "›"   // chevron down / right
                    color: list.fg; font.family: list.fam; font.pixelSize: 13
                }
                MouseArea {
                    id: rowMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: (row.modelData && row.modelData.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!row.modelData || !row.modelData.enabled) return;
                        if (row.modelData.hasChildren) row.expanded = !row.expanded;
                        else { row.modelData.triggered(); list.requestClose(); }
                    }
                }
            }
            // inline submenu (lazy). Loaded by URL string, not by the MenuList type, so the QML
            // engine doesn't reject it as static recursion; properties are wired in onLoaded.
            Loader {
                id: subLoader
                width: list.width
                active: row.expanded && !!(row.modelData && row.modelData.hasChildren)
                visible: active
                source: active ? Qt.resolvedUrl("MenuList.qml") : ""
                onLoaded: {
                    item.skin = Qt.binding(function() { return list.skin; });
                    item.width = Qt.binding(function() { return list.width; });
                    item.depth = list.depth + 1;
                    item.handle = row.modelData;
                    item.requestClose.connect(list.requestClose);
                }
            }
        }
    }
}
