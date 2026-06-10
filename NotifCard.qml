// Reusable notification card (popups + history). appName, summary, body, close.
import QtQuick

Rectangle {
    id: card
    property var notif
    property var skin
    property bool popup: false
    signal closed()

    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color bg: skin ? skin.background : "#000000"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color fgDim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"

    radius: 12
    color: popup ? Qt.rgba(bg.r, bg.g, bg.b, 0.98) : Qt.rgba(fg.r, fg.g, fg.b, 0.07)
    border.width: popup ? 1 : 0
    border.color: Qt.rgba(ac.r, ac.g, ac.b, 0.5)
    implicitHeight: col.implicitHeight + 18

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9 }
        spacing: 3
        Row {
            width: parent.width
            Text {
                width: parent.width - 18; elide: Text.ElideRight
                text: (card.notif && card.notif.appName) ? card.notif.appName : ""
                color: card.ac; font.family: card.fam; font.pixelSize: 10; font.weight: 600
            }
            Text {
                text: String.fromCharCode(0xf00d); font.family: "Symbols Nerd Font"; font.pixelSize: 11; color: card.fgDim
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (card.notif) { try { card.notif.dismiss(); } catch (e) {} } card.closed(); } }
            }
        }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            visible: text.length > 0
            text: (card.notif && card.notif.summary) ? card.notif.summary : ""
            color: card.fg; font.family: card.fam; font.pixelSize: 13; font.weight: 600
        }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            visible: text.length > 0
            maximumLineCount: card.popup ? 3 : 6; elide: Text.ElideRight
            text: (card.notif && card.notif.body) ? card.notif.body : ""
            color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.72); font.family: card.fam; font.pixelSize: 12
        }
    }
}
