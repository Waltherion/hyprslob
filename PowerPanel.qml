// Level 2 - power panel. 5 action buttons (lock/sleep/log out/restart/shut down).
// Commands are config-driven (cfg.commands); each runs via `sh -c` so any shell
// command works. Logout defaults to Hyprland's Lua dispatch (hl.dsp.exit()) run as a
// direct argv (no shell, so the "()" isn't mangled) - the old hyprlang `exit` dispatcher
// is being retired. Override any action with commands.{lock,suspend,logout,reboot,poweroff}.
import QtQuick
import Quickshell

Row {
    id: pp
    property var skin
    property var commands: ({})         // {lock,suspend,logout,reboot,poweroff} from config (overrides defaults)
    property string sleepLabel: "Sleep" // label for the suspend button (e.g. "Hibernate")
    spacing: 8
    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property string fam: skin ? skin.fontFamily : "Poppins"
    readonly property var keyHints: ["q", "w", "e", "r", "t"]   // q/w/e/r/t hotkeys (routed from shell.qml)
    signal requestClose()

    // Run the config command via sh -c (override), else the action's direct argv default; then close the hub.
    function _act(a) {
        if (a.cmd && a.cmd.length) Quickshell.execDetached(["sh", "-c", a.cmd]);
        else if (a.argv) Quickshell.execDetached(a.argv);
        pp.requestClose();
    }
    // Trigger action i (0-based) - used by the q/w/e/r/t keyboard shortcuts.
    function activate(i) { if (i >= 0 && i < pp.acts.length) pp._act(pp.acts[i]); }

    readonly property var acts: [
        { ic: 0xf023, l: "Lock",          cmd: (pp.commands.lock     || "hyprlock") },
        { ic: 0xf186, l: pp.sleepLabel,   cmd: (pp.commands.suspend  || "systemctl suspend") },
        { ic: 0xf08b, l: "Log out",       cmd: (pp.commands.logout   || ""), argv: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { ic: 0xf021, l: "Restart",       cmd: (pp.commands.reboot   || "systemctl reboot") },
        { ic: 0xf011, l: "Shut down",     cmd: (pp.commands.poweroff || "systemctl poweroff") }
    ]

    Repeater {
        model: pp.acts
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: 58; height: 56
            radius: Math.min(12, (pp.skin ? Math.max(pp.skin.radius, 8) : 8))
            color: ma.containsMouse ? Qt.rgba(pp.ac.r, pp.ac.g, pp.ac.b, 0.22)
                                    : Qt.rgba(pp.fg.r, pp.fg.g, pp.fg.b, 0.07)
            border.width: 1
            border.color: Qt.rgba(pp.fg.r, pp.fg.g, pp.fg.b, ma.containsMouse ? 0.30 : 0.13)
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: ma.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Column {
                anchors.centerIn: parent; spacing: 3
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCharCode(modelData.ic)
                    font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: pp.fg }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.l
                    font.family: pp.fam; font.pixelSize: 10; color: pp.fg }
            }
            Text {   // q/w/e/r/t hotkey hint
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 5
                text: pp.keyHints[index] || ""
                font.family: pp.fam; font.pixelSize: 9; font.weight: Font.Bold
                color: Qt.rgba(pp.fg.r, pp.fg.g, pp.fg.b, 0.5)
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: pp._act(modelData) }
        }
    }
}
