// Level 2 - audio panel. Media controls (MPRIS) + volume slider + mute (default sink)
// + output selector (click = set default).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Column {
    id: ap
    property var skin
    width: 320; spacing: 9
    readonly property color fg: skin ? skin.text : "#ffffff"
    readonly property color ac: skin ? skin.accent : "#ffffff"
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property string fam: skin ? skin.fontFamily : "Poppins"

    // Active media player. A browser can expose several MPRIS players for the SAME tab: its native
    // one (app-shell metadata - title is the app name, no artist, a generic browser-icon artUrl) and
    // plasma-browser-integration (the real song title, artist and cover). They all report CanGoNext,
    // so we can't pick by transport alone - rank by metadata richness (a real artist wins) and prefer
    // a currently-playing one. The playerctld proxy just mirrors another player, so we drop it.
    readonly property var player: {
        if (!Mpris.players || !Mpris.players.values.length) return null;
        const v = Mpris.players.values.filter(p => p && (p.dbusName || "").indexOf("playerctld") < 0);
        if (!v.length) return null;
        const pool = v.some(p => p.isPlaying) ? v.filter(p => p.isPlaying) : v;
        const score = p => (p.trackArtist && p.trackArtist.length ? 2 : 0) + (p.canGoNext ? 1 : 0);
        return pool.slice().sort((a, b) => score(b) - score(a))[0];
    }

    // Live position for the seek bar (MPRIS doesn't push position; poll while the panel is open).
    property real pos: 0

    // Album art is flaky over MPRIS. The browser's native player exposes a generic browser-icon
    // artUrl while plasma-browser-integration caches the real cover to a local file (but only
    // populates it after a play-state event, so it's briefly absent on a track change). We take the
    // selected player's art first, else fall back to art from any player WITH a real artist (never
    // the app-shell's icon), and KEEP the last good one until a new one arrives (no mid-song blank).
    property string artUrl: ""
    function refreshArt() {
        let u = (ap.player && ap.player.trackArtUrl) ? ap.player.trackArtUrl : "";
        if (!u && Mpris.players) {
            const v = Mpris.players.values;
            let best = v.find(p => p && p.trackArtUrl && p.trackArtist && p.trackArtist.length);
            if (!best) best = v.find(p => p && p.trackArtUrl);
            if (best) u = best.trackArtUrl;
        }
        if (u && u !== ap.artUrl) ap.artUrl = u;
    }

    Timer {
        interval: 1000; repeat: true; running: ap.player !== null; triggeredOnStart: true
        onTriggered: { ap.pos = ap.player ? ap.player.position : 0; ap.refreshArt(); }
    }
    function fmtTime(s) {
        if (!s || s < 0) return "0:00";
        s = Math.floor(s);
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }
    // accent sampled from the rolling rainbow band at a global x (solid accent when rainbow off)
    function acAt(px) { return ap.skin ? ap.skin.bandAt(px) : ap.ac; }

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: ap.sink ? [ap.sink] : [] }
    readonly property bool muted: ap.sink && ap.sink.audio ? ap.sink.audio.muted : false
    readonly property real vol: ap.sink && ap.sink.audio ? ap.sink.audio.volume : 0

    // ---- Media player (MPRIS). Hidden when nothing is playing -> panel shrinks. ----
    Rectangle {
        id: mediaCard
        visible: ap.player !== null
        width: ap.width
        implicitHeight: mediaCol.implicitHeight + 16
        radius: 10
        color: Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.06)
        Column {
            id: mediaCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 8

            // cover + title/artist + controls
            RowLayout {
                width: parent.width; spacing: 10
                // cover art (fallback: music-note glyph)
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    radius: 6; clip: true
                    color: Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.10)
                    Image {
                        id: art
                        anchors.fill: parent
                        source: ap.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        visible: ap.artUrl.length > 0 && status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent; visible: !art.visible
                        text: String.fromCharCode(0xf001)   // music note
                        font.family: "Symbols Nerd Font"; font.pixelSize: 16; color: ap.dim
                    }
                }
                // title / artist
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text {
                        text: ap.player ? (ap.player.trackTitle || "Unknown") : ""
                        color: ap.fg; font.family: ap.fam; font.pixelSize: 12; font.weight: 600
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: ap.player ? (ap.player.trackArtist || "") : ""
                        color: ap.dim; font.family: ap.fam; font.pixelSize: 10
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
                // repeat toggle: None -> Track (shows "1") -> Playlist
                Text {
                    visible: ap.player && ap.player.loopSupported
                    text: String.fromCharCode(0xf01e)   // repeat
                    font.family: "Symbols Nerd Font"; font.pixelSize: 13
                    color: (ap.player && ap.player.loopState !== MprisLoopState.None) ? ap.acAt(mapToItem(null, width / 2, 0).x) : ap.dim
                    Text {
                        anchors.centerIn: parent
                        visible: ap.player && ap.player.loopState === MprisLoopState.Track
                        text: "1"; font.family: ap.fam; font.pixelSize: 7; font.weight: 700; color: parent.color
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!ap.player) return;
                            const s = ap.player.loopState;
                            ap.player.loopState = s === MprisLoopState.None ? MprisLoopState.Track
                                : s === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None;
                        }
                    }
                }
                // prev / play-pause / next
                Repeater {
                    model: ["prev", "play", "next"]
                    delegate: Text {
                        required property var modelData
                        readonly property bool dimmed: ap.player
                            ? (modelData === "prev" ? !ap.player.canGoPrevious
                               : modelData === "next" ? !ap.player.canGoNext : false)
                            : true
                        text: modelData === "prev" ? String.fromCharCode(0xf048)
                            : modelData === "next" ? String.fromCharCode(0xf051)
                            : String.fromCharCode(ap.player && ap.player.isPlaying ? 0xf04c : 0xf04b)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: modelData === "play" ? 18 : 14
                        color: dimmed ? ap.dim : ap.acAt(mapToItem(null, width / 2, 0).x)
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!ap.player) return;
                                if (modelData === "prev") ap.player.previous();
                                else if (modelData === "next") ap.player.next();
                                else ap.player.togglePlaying();
                            }
                        }
                    }
                }
            }

            // seek bar + time labels
            RowLayout {
                width: parent.width; spacing: 8
                Text {
                    text: ap.fmtTime(ap.pos); color: ap.dim; font.family: ap.fam
                    font.pixelSize: 9; Layout.preferredWidth: 30
                }
                Rectangle {
                    id: seek
                    Layout.fillWidth: true; implicitHeight: 5; radius: 2.5
                    color: Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.15)
                    readonly property real frac: (ap.player && ap.player.length > 0)
                        ? Math.max(0, Math.min(1, ap.pos / ap.player.length)) : 0
                    BandRect { width: parent.width * parent.frac; height: parent.height; skin: ap.skin }
                    MouseArea {
                        anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
                        enabled: ap.player && ap.player.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function seekTo(x) {
                            if (!ap.player || !ap.player.length) return;
                            const f = Math.max(0, Math.min(1, x / seek.width));
                            ap.player.position = f * ap.player.length;
                            ap.pos = f * ap.player.length;
                        }
                        onPressed: (m) => seekTo(m.x)
                        onPositionChanged: (m) => { if (pressed) seekTo(m.x); }
                    }
                }
                Text {
                    text: ap.player ? ap.fmtTime(ap.player.length) : "0:00"
                    color: ap.dim; font.family: ap.fam; font.pixelSize: 9
                    Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
    Rectangle { visible: ap.player !== null; width: parent.width; height: 1; color: Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.12) }

    // ---- Volume ----
    Row {
        width: ap.width; spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter; width: 22
            text: String.fromCharCode(ap.muted ? 0xf026 : 0xf028)   // mute / speaker
            font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: ap.muted ? ap.dim : ap.fg
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (ap.sink && ap.sink.audio) ap.sink.audio.muted = !ap.sink.audio.muted }
        }
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: ap.width - 22 - 50; height: 8; radius: 4
            color: Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.12)
            Item {
                width: track.width * Math.max(0, Math.min(1, ap.vol)); height: parent.height; clip: true
                BandRect { anchors.fill: parent; skin: ap.skin; visible: !ap.muted && ap.skin && ap.skin.rainbow }
                Rectangle { anchors.fill: parent; radius: 4; visible: ap.muted || !(ap.skin && ap.skin.rainbow)
                    color: ap.muted ? ap.dim : ap.ac }
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -7
                function setv(x) { if (ap.sink && ap.sink.audio) ap.sink.audio.volume = Math.max(0, Math.min(1, x / track.width)); }
                onPressed: (m) => setv(m.x)
                onPositionChanged: (m) => { if (pressed) setv(m.x); }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter; width: 40; horizontalAlignment: Text.AlignRight
            text: Math.round(ap.vol * 100) + "%"; color: ap.fg; font.family: ap.fam; font.pixelSize: 12
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.12) }
    Row {
        width: ap.width
        Text { text: "Output"; color: ap.dim; font.family: ap.fam; font.pixelSize: 11; font.weight: 600; width: ap.width - 22 }
        Text {
            text: String.fromCharCode(0xf013)   // gear -> pavucontrol
            font.family: "Symbols Nerd Font"; font.pixelSize: 14; color: ap.dim
            MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["pavucontrol"]) }
        }
    }

    // ---- Output selector ----
    Repeater {
        model: Pipewire.nodes
        delegate: Rectangle {
            required property var modelData
            readonly property bool isOut: modelData && modelData.isSink && !modelData.isStream && modelData.audio
            readonly property bool isDefault: modelData === Pipewire.defaultAudioSink
            visible: isOut
            width: ap.width; height: isOut ? 28 : 0; radius: 7
            color: isDefault ? Qt.rgba(ap.ac.r, ap.ac.g, ap.ac.b, 0.20)
                             : (sma.containsMouse ? Qt.rgba(ap.fg.r, ap.fg.g, ap.fg.b, 0.10) : "transparent")
            Text {
                anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20; elide: Text.ElideRight
                text: modelData ? (modelData.description || modelData.nickname || modelData.name || "") : ""
                color: ap.fg; font.family: ap.fam; font.pixelSize: 12
                font.weight: parent.isDefault ? 600 : 400
            }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: if (parent.isOut) Pipewire.preferredDefaultAudioSink = modelData }
        }
    }
}
