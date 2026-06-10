//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// HyprSlob Center Bar - standalone, config-driven center pill (qs -c hyprslob).
// v0.1 base: Time | Day | Date - 3 equal-width fields + center-anchored morph slot
// (copied from the bar's proven jitter-free layout). Appearance is driven by
// ~/.config/hyprslob/config.jsonc via Config/Skin (fully self-contained - no theme dependency).

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
    }

    Config { id: cfg }
    Skin { id: pal; cfg: cfg; phase: root.rainbowPhase }

    // Hide/show (Super+B). Hub state (expandLevel/hubActive) is PER-MONITOR (on win) - hover controls
    // per screen; IPC sends a signal that ONLY the focused screen reacts to.
    property bool barVisible: true
    signal hubIpc(string action, string key)
    IpcHandler {
        target: "hyprslob"
        function toggle(): void { root.barVisible = !root.barVisible }
        function show(): void { root.barVisible = true }
        function hide(): void { root.barVisible = false }
        function toggleHub(): void { root.hubIpc("toggle", "") }
        function expand(): void { root.hubIpc("expand", "") }
        function collapse(): void { root.hubIpc("collapse", "") }
        function select(key: string): void { root.hubIpc("select", key) }
    }

    // ---- Clock ----
    property string dayStr: ""
    property string dateStr: ""
    property string timeStr: ""
    function updateClock() {
        const loc = Qt.locale("en_GB");      // Day in English (Saturday); the rest numeric
        const now = new Date();
        root.dayStr = now.toLocaleString(loc, "dddd");
        root.dateStr = now.toLocaleString(loc, "dd-MM-yyyy");
        root.timeStr = now.toLocaleString(loc, "HH:mm:ss");
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.updateClock() }

    // ---- Visualizer (cava). Process runs ONLY when showVisualizer is enabled (zero-cost otherwise) ----
    readonly property bool showVisualizer: cfg.showVisualizer
    property bool audioActive: false
    property var levels: []
    Timer { id: holdTimer; interval: 900; onTriggered: root.audioActive = false }   // hold so the morph doesn't flicker
    Process {
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/hyprslob/cava-stream.py"]
        running: root.barVisible && root.showVisualizer
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.split(";");
                const arr = [];
                let amp = 0;
                for (let i = 0; i < parts.length; i++) {
                    const s = parts[i].trim();
                    if (!s.length) continue;
                    const v = parseInt(s, 10);
                    if (isNaN(v)) continue;
                    const f = v / 1000;
                    arr.push(f);
                    if (f > amp) amp = f;
                }
                if (arr.length > 1) root.levels = arr;
                if (amp > 0.04) { root.audioActive = true; holdTimer.restart(); }
            }
        }
    }

    // ---- Flowing rainbow phase. Zero-cost: the timer runs ONLY when rainbow=true ----
    property real rainbowPhase: 0
    Timer {
        interval: 60; repeat: true
        running: pal.rainbow
        // ~12s/cycle at speed 1; cfg.rainbowSpeed scales it (0 = frozen, <0 = reverse). Normalized to [0,1).
        onTriggered: root.rainbowPhase = ((root.rainbowPhase + 0.005 * cfg.rainbowSpeed) % 1 + 1) % 1
    }

    // ---- Level 2 system data (CPU/RAM/GPU/temp, active window, OS/kernel) ----
    property int sysCpu: -1
    property int sysRam: -1
    property int sysGpu: -1       // power-based load % (power.draw / power.limit), not util.gpu
    property int sysCpuTemp: -1
    property int sysGpuTemp: -1
    property int sysBat: -1          // laptop battery % (-1 = no battery -> indicator hidden)
    property bool sysBatCharging: false
    Process {
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/hyprslob/sysinfo-stream.py"]
        running: root.barVisible
        stdout: SplitParser { splitMarker: "\n"; onRead: data => {
            const p = data.split(";");
            if (p.length >= 5) { root.sysCpu = parseInt(p[0]); root.sysRam = parseInt(p[1]); root.sysGpu = parseInt(p[2]);
                root.sysCpuTemp = parseInt(p[3]); root.sysGpuTemp = parseInt(p[4]); }
            if (p.length >= 7) { root.sysBat = parseInt(p[5]); root.sysBatCharging = p[6].trim() === "1"; }
        } }
    }
    property string activeApp: ""
    Process { id: winProc; command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector { id: winCol; onStreamFinished: {
            try { const o = JSON.parse(winCol.text); root.activeApp = (o && o.class) ? o.class : ""; }
            catch (e) { root.activeApp = ""; } } } }
    Timer { interval: 1500; running: root.barVisible; repeat: true; triggeredOnStart: true; onTriggered: winProc.running = true }
    property string kernel: ""
    property string osName: "Linux"
    Process { command: ["uname", "-r"]; running: true
        stdout: StdioCollector { id: kCol; onStreamFinished: root.kernel = kCol.text.trim() } }
    Process { command: ["sh", "-c", ". /etc/os-release 2>/dev/null; printf %s \"${NAME:-Linux}\""]; running: true
        stdout: StdioCollector { id: osCol; onStreamFinished: root.osName = osCol.text.trim() || "Linux" } }

    // ---- Notifications (hyprslob takes over from the control center) ----
    property bool dnd: false
    property int unread: 0          // unread notifications (badge on notif button); reset when the panel is opened
    property var popups: []
    function dropPopup(n) { root.popups = root.popups.filter(x => x !== n); }
    function clearAllNotifs() {
        const arr = server.trackedNotifications.values.slice();
        for (let i = 0; i < arr.length; i++) { try { arr[i].dismiss(); } catch (e) {} }
        root.popups = [];
    }
    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: (n) => {
            n.tracked = true;
            root.unread++;
            if (!root.dnd) root.popups = [n].concat(root.popups).slice(0, 4);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell-hyprslob"   // own namespace (!= quickshell-bar)
            WlrLayershell.layer: WlrLayer.Overlay            // the morph expansion sits ON TOP of windows
            // grab keyboard focus ONLY when the hub is open (so Esc can collapse); release it again on collapse
            WlrLayershell.keyboardFocus: win.expandLevel > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            visible: root.barVisible && !win.monitorFullscreen   // hide in fullscreen (like waybar)
            color: "transparent"
            mask: Region { item: clockBox }                 // ONLY the box captures input; the rest passes through

            // Full-bar themes (neon, no waybar) reserve ONLY the base height (exclusiveZone, constant);
            // the window is tall enough for the hub but the morph does NOT reserve more. Other themes: overlap waybar.
            // hyprslob is the bar in ALL themes (waybar retired) -> ALWAYS reserve the base height;
            // full-width transparent window + center pill + input mask. The morph reserves no more.
            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: 0
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Math.ceil(win.contentH)

            // ---- Geometry ----
            readonly property int boxPadH: 15
            readonly property int boxPadV: 2
            readonly property int boxTop: 5      // margin above/below the bar (5px - the bar takes up more)
            readonly property int textNudge: -1
            readonly property int sz: pal.fontSize
            readonly property int boxH: Math.round(sz * 1.55) + boxPadV * 2 + Math.round(pal.borderWidth) * 2 + 6   // +6: fills the freed-up margin (reserves no more)
            readonly property real contentW: clockRow.implicitWidth + (pal.hasBox ? (boxPadH + pal.borderWidth) * 2 : 0) + 20
            readonly property real contentH: boxTop + boxH + boxTop
            // Hub expansion: the window is ALWAYS large enough for Level 1 (fixed width+height), the box morphs inside.
            // Width must accommodate the EXPANDED box (the buttons are wider than the clock) otherwise the side borders get clipped.
            readonly property int level1H: 42      // = Level1Bar.btnSize (square buttons)
            readonly property int expandGap: 8
            readonly property int expandExtra: level1H + expandGap * 2
            readonly property int level2W: 320      // Level-2 panel width
            readonly property int level2H: 390      // Level-2 reserved height (room for ~4 notifications)
            readonly property int level2PadBottom: 16   // extra space BELOW the panel -> bottom text doesn't crowd the rounded corners

            // ---- Hub state PER MONITOR (hover controls this screen; IPC only if focused) ----
            property int expandLevel: 0
            property string hubActive: ""
            onExpandLevelChanged: if (win.expandLevel === 0) win.hubActive = ""
            onHubActiveChanged: if (win.hubActive === "notif") root.unread = 0   // opened -> read
            property bool holdOpen: false   // a tray menu is open -> don't auto-collapse the hub
            function holdHubOpen() { win.holdOpen = true; holdTimer.restart(); }
            Timer { id: expandDelay; interval: 40; onTriggered: win.expandLevel = 1 }   // snappy expand (tiny delay avoids triggering on a quick mouse pass)
            Timer { id: collapseDelay; interval: 400; onTriggered: if (!win.holdOpen) win.expandLevel = 0 }   // keep a forgiving collapse delay (don't lose it on an over-shoot)
            Timer { id: holdTimer; interval: 6000; onTriggered: { win.holdOpen = false; if (!hoverMA.containsMouse) win.expandLevel = 0 } }
            readonly property bool isFocused: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === win.screen.name
            Connections {
                target: root
                function onHubIpc(action, key) {
                    if (!win.isFocused) return;
                    if (action === "select") { win.expandLevel = 1; win.hubActive = (win.hubActive === key ? "" : key); }
                    else if (action === "expand") win.expandLevel = 1;
                    else if (action === "collapse") win.expandLevel = 0;
                    else if (action === "toggle") win.expandLevel = win.expandLevel > 0 ? 0 : 1;
                }
            }
            readonly property real expandedBoxW: boxPadH * 2 + Math.max(clockRow.implicitWidth, level1.implicitWidth, level2W) + 16
            implicitWidth: Math.ceil(Math.max(contentW, expandedBoxW) * pal.uiScale)
            implicitHeight: Math.ceil((contentH + expandExtra + expandGap + level2H) * pal.uiScale)

            readonly property string fam: pal.fontFamily
            readonly property int wt: pal.fontWeight
            readonly property var feat: ({ "tnum": 1 })   // tabular figures -> the clock doesn't jitter horizontally
            readonly property int anim: 380
            readonly property real rbPeriod: cfg.rainbowPeriod   // config: rainbowPeriod (clock + accents in sync)

            // ---- Workspace indicator: per-monitor active id; transient reveal on change ----
            property int activeWsId: -1
            property bool monitorFullscreen: false   // this screen's active ws has a fullscreen window
            property bool wsRevealActive: false
            property bool wsHover: false
            property bool _ready: false
            Timer { interval: 1000; running: true; repeat: false; onTriggered: win._ready = true }   // startup grace (no flash on launch)
            Timer { id: wsHold; interval: 1500; onTriggered: win.wsRevealActive = false }
            // Poll this monitor's active ws id (the model updates, but top-level binding/events were
            // unreliable here). 250ms = CPU only (no repaint) -> preserves zero-cost.
            Timer {
                interval: 250; running: true; repeat: true
                onTriggered: {
                    const arr = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                    let active = null;
                    for (let i = 0; i < arr.length; i++) { const w = arr[i];
                        if (w && w.monitor && w.monitor.name === win.screen.name
                            && w.monitor.activeWorkspace && w.monitor.activeWorkspace.id === w.id) { active = w; break; } }
                    win.monitorFullscreen = active ? !!active.hasFullscreen : false;
                    const id = active ? active.id : -1;
                    if (id === win.activeWsId) return;
                    win.activeWsId = id;
                    if (!win._ready) return;
                    win.wsRevealActive = true; wsHold.restart();
                }
            }
            // 0 = label shown, 1 = dots shown (depends on cfg.wsTrigger)
            property real wsShown: {
                const t = cfg.wsTrigger;
                if (t === "always") return 1;
                if (t === "hover") return win.wsHover ? 1 : 0;
                if (t === "both") return (win.wsHover || win.wsRevealActive) ? 1 : 0;
                return win.wsRevealActive ? 1 : 0;   // "change"
            }
            // Asymmetric: reveal (date->dots) fast/instant; return (dots->date) soft/slow.
            Behavior on wsShown {
                NumberAnimation {
                    duration: win.wsRevealActive ? 0 : 450
                    easing.type: win.wsRevealActive ? Easing.OutCubic : Easing.InOutCubic
                }
            }

            // Fullscreen reacts ~instantly via rawEvent (the 250ms poll is only a backstop).
            Connections {
                target: Hyprland
                function onRawEvent(event) {
                    const n = `${event && event.name ? event.name : ""}`;
                    if (n.indexOf("fullscreen") < 0) return;
                    const arr = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                    for (let i = 0; i < arr.length; i++) { const w = arr[i];
                        if (w && w.monitor && w.monitor.name === win.screen.name
                            && w.monitor.activeWorkspace && w.monitor.activeWorkspace.id === w.id) {
                            win.monitorFullscreen = !!w.hasFullscreen; return; } }
                    win.monitorFullscreen = false;
                }
            }

            FontMetrics { id: fm; font.family: win.fam; font.pixelSize: win.sz; font.weight: win.wt }

            // Pill wrapper: carries config-driven opacity + scaling (about the pill center)
            Item {
                id: pille
                anchors.fill: parent
                transformOrigin: Item.Center
                opacity: pal.uiOpacity
                scale: pal.uiScale
                focus: true
                Keys.onEscapePressed: win.expandLevel = 0   // Esc collapses the hub

                // ---- Box behind the pill ----
                Rectangle {
                    id: clockBox
                    visible: pal.hasBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.boxTop
                    height: win.boxH + (win.expandLevel > 0 ? win.expandExtra : 0)
                            + (win.hubActive !== "" ? (win.expandGap + (l2.item ? l2.item.implicitHeight : win.level2H) + win.level2PadBottom) : 0)
                    // width tracks the CONTENT directly (no Behavior) -> follows the visualizer morph precisely.
                    width: win.boxPadH * 2 + Math.max(clockRow.width,
                                                      win.expandLevel > 0 ? level1.implicitWidth : 0,
                                                      win.hubActive !== "" ? win.level2W : 0)
                    color: pal.background
                    radius: pal.radius
                    border.width: pal.borderWidth
                    border.color: pal.border
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }

                    // Clip Level 1+2 in an INNER Item (not on clockBox itself -> the border isn't clipped,
                    // Qt's clip quirk that otherwise cut off the bottom/right border in Level 0/1).
                    Item {
                        id: clipper
                        anchors.fill: parent
                        clip: true

                        // ---- Level 1 (hub): revealed when the box grows downward ----
                        Level1Bar {
                            id: level1
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: win.boxH + win.expandGap          // relative to the box's top (boxTop)
                            skin: pal
                            rainbow: pal.rainbow
                            stops: pal.stops
                            phase: root.rainbowPhase
                            period: win.rbPeriod
                            notifUnread: root.unread > 0
                            activeKey: win.hubActive
                            onToggle: (key) => { win.hubActive = (win.hubActive === key ? "" : key); }
                        }

                        // ---- Level 2: panel that unfolds beneath the buttons ----
                        Loader {
                            id: l2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: win.boxH + win.expandGap + win.level1H + win.expandGap
                            active: win.hubActive !== ""
                            opacity: win.hubActive !== "" ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            sourceComponent: win.hubActive === "system" ? sysPanelComp
                                           : win.hubActive === "audio" ? audioPanelComp
                                           : win.hubActive === "net" ? netPanelComp
                                           : win.hubActive === "notif" ? notifPanelComp
                                           : win.hubActive === "power" ? powerPanelComp
                                           : comingSoonComp
                        }
                    }
                    Component {
                        id: sysPanelComp
                        SystemPanel {
                            skin: pal
                            hostWin: win
                            cpu: root.sysCpu; ram: root.sysRam; gpu: root.sysGpu
                            cpuTemp: root.sysCpuTemp; gpuTemp: root.sysGpuTemp
                            bat: root.sysBat; batCharging: root.sysBatCharging
                            kernel: root.kernel; osName: root.osName; activeApp: root.activeApp
                        }
                    }
                    Component { id: audioPanelComp; AudioPanel { skin: pal } }
                    Component { id: netPanelComp; NetPanel { skin: pal } }
                    Component { id: notifPanelComp; NotifPanel { skin: pal; srv: server; dnd: root.dnd
                        onDndToggled: root.dnd = !root.dnd; onClearAllRequested: root.clearAllNotifs() } }
                    Component { id: powerPanelComp; PowerPanel { skin: pal; commands: cfg.commands; sleepLabel: cfg.sleepLabel } }
                    Component {
                        id: comingSoonComp
                        Text {
                            text: (win.hubActive ? win.hubActive : "") + " - panel coming soon"
                            color: pal.text; font.family: pal.fontFamily; font.pixelSize: 13
                        }
                    }
                }

                // ---- Bloom: blurred copy of the clock BEHIND the sharp text -> glow.
                //      Zero-cost: the Loader does NOT create the MultiEffect object at all when bloom=0. ----
                Loader {
                    id: bloomLoader
                    active: pal.bloom > 0.0
                    x: clockRow.x; y: clockRow.y
                    width: clockRow.width; height: clockRow.height
                    sourceComponent: MultiEffect {
                        source: clockRow
                        anchors.fill: parent
                        autoPaddingEnabled: true
                        blurEnabled: true
                        blur: 1.0
                        blurMax: Math.round(48 * pal.bloom)
                    }
                }

                // ---- Center pill: Time | Day | Date. 3 equal fields (fieldW) -> no jitter;
                //      symmetric layout -> the middle is always screen-centered. ----
                Row {
                    id: clockRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.boxTop + Math.round((win.boxH - fm.height) / 2 + win.textNudge)
                    spacing: 0   // spacing is baked into the separators ("  |  ")

                    // dots widths included in fieldW -> the side field is always wide enough for the dots (no reflow)
                    // +12: a touch of space in the fields so time/date don't crowd the rounded corners in Level 1
                    property real fieldW: Math.max(timeText.implicitWidth, dayText.implicitWidth, dateText.implicitWidth,
                                                   timeDots.implicitWidth || 0, dateDots.implicitWidth || 0) + 12
                    property real vizW: Math.round(clockRow.fieldW * 1.7)

                    // optional left icon (config.icon.left) - 0 width when empty -> no layout change
                    Item {
                        visible: (cfg.icon.left || "") !== ""
                        width: visible ? leftIcon.size + 6 : 0
                        height: dayText.implicitHeight
                        SvgIcon { id: leftIcon; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; path: cfg.icon.left || ""; size: Math.round(win.sz * 1.05) }
                    }
                    // Time (left field) - host for ws dots if wsSide=="time"
                    Item {
                        id: timeSlot
                        width: clockRow.fieldW; height: dayText.implicitHeight
                        readonly property bool wsHere: cfg.wsSide === "time"
                        RainbowLabel { id: timeText; anchors.centerIn: parent; content: root.timeStr; family: win.fam; pixelSize: win.sz; fontWeight: win.wt; features: win.feat; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod; rainbow: pal.rainbow; solid: pal.text
                            opacity: timeSlot.wsHere ? (1 - win.wsShown) : 1 }
                        WorkspaceDots {
                            id: timeDots
                            anchors.centerIn: parent
                            visible: timeSlot.wsHere && win.wsShown > 0.01
                            opacity: timeSlot.wsHere ? win.wsShown : 0
                            screenName: win.screen.name
                            activeColor: pal.accent; dimColor: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.5)
                            dotSize: Math.max(8, Math.round(win.sz * 0.62))
                            rainbow: pal.rainbow; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod
                        }
                    }
                    // separator
                    RainbowLabel { content: "  |  "; family: win.fam; pixelSize: win.sz; fontWeight: win.wt; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod; rainbow: pal.rainbow; solid: pal.separator }
                    // Middle: Day (morph slot - visualizer added behind showVisualizer in a later phase)
                    Item {
                        id: midSlot
                        width: (root.showVisualizer && root.audioActive) ? clockRow.vizW : clockRow.fieldW
                        height: dayText.implicitHeight
                        Behavior on width { NumberAnimation { duration: win.anim; easing.type: Easing.InOutCubic } }
                        Item {
                            id: dayWrap
                            anchors.centerIn: parent
                            width: dayText.implicitWidth; height: dayText.implicitHeight
                            opacity: (root.showVisualizer && root.audioActive) ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: win.anim; easing.type: Easing.InOutCubic } }
                            RainbowLabel { id: dayText; content: root.dayStr; family: win.fam; pixelSize: win.sz; fontWeight: win.wt; features: win.feat; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod; rainbow: pal.rainbow; solid: pal.text }
                        }
                        // Visualizer curve (unfolds symmetrically out of the middle when audio is playing)
                        Item {
                            id: vizWrap
                            anchors.fill: parent
                            visible: root.showVisualizer
                            opacity: (root.showVisualizer && root.audioActive) ? 1 : 0
                            clip: true
                            Behavior on opacity { NumberAnimation { duration: win.anim; easing.type: Easing.InOutCubic } }
                            Canvas {
                                id: viz
                                anchors.fill: parent
                                antialiasing: true
                                property var rainbow: pal.stops
                                property var lv: root.levels
                                onLvChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                function trace(ctx, pts) {
                                    ctx.moveTo(pts[0].x, pts[0].y);
                                    let i;
                                    for (i = 1; i < pts.length - 1; i++) {
                                        const xc = (pts[i].x + pts[i + 1].x) / 2;
                                        const yc = (pts[i].y + pts[i + 1].y) / 2;
                                        ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc);
                                    }
                                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, pts[i].x, pts[i].y);
                                }
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    const w = width, h = height;
                                    const arr = lv;
                                    if (w < 2 || !arr || arr.length < 2) return;
                                    const n = arr.length;
                                    const pad = w * 0.012;
                                    const span = w - pad * 2;
                                    const pts = [];
                                    pts.push({ x: 0, y: h });
                                    for (let i = 0; i < n; i++)
                                        pts.push({ x: pad + (i / (n - 1)) * span, y: h - Math.max(0, Math.min(1, arr[i])) * h });
                                    pts.push({ x: w, y: h });
                                    const grad = ctx.createLinearGradient(0, 0, w, 0);
                                    const rb = viz.rainbow && viz.rainbow.length > 1 ? viz.rainbow : [pal.text, pal.text];
                                    for (let k = 0; k < rb.length; k++)
                                        grad.addColorStop(k / (rb.length - 1), rb[k]);
                                    ctx.beginPath();
                                    trace(ctx, pts);
                                    ctx.closePath();
                                    ctx.globalAlpha = 0.38;
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    ctx.globalAlpha = 1.0;
                                    ctx.beginPath();
                                    trace(ctx, pts);
                                    ctx.lineWidth = 2;
                                    ctx.lineJoin = "round";
                                    ctx.lineCap = "round";
                                    ctx.strokeStyle = grad;
                                    ctx.stroke();
                                }
                            }
                        }
                    }
                    // separator
                    RainbowLabel { content: "  |  "; family: win.fam; pixelSize: win.sz; fontWeight: win.wt; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod; rainbow: pal.rainbow; solid: pal.separator }
                    // Date (right field) - host for ws dots if wsSide=="date"
                    Item {
                        id: dateSlot
                        width: clockRow.fieldW; height: dayText.implicitHeight
                        readonly property bool wsHere: cfg.wsSide === "date"
                        RainbowLabel { id: dateText; anchors.centerIn: parent; content: root.dateStr; family: win.fam; pixelSize: win.sz; fontWeight: win.wt; features: win.feat; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod; rainbow: pal.rainbow; solid: pal.text
                            opacity: dateSlot.wsHere ? (1 - win.wsShown) : 1 }
                        WorkspaceDots {
                            id: dateDots
                            anchors.centerIn: parent
                            visible: dateSlot.wsHere && win.wsShown > 0.01
                            opacity: dateSlot.wsHere ? win.wsShown : 0
                            screenName: win.screen.name
                            activeColor: pal.accent; dimColor: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.5)
                            dotSize: Math.max(8, Math.round(win.sz * 0.62))
                            rainbow: pal.rainbow; stops: pal.stops; phase: root.rainbowPhase; period: win.rbPeriod
                        }
                    }
                    // optional right icon (config.icon.right)
                    Item {
                        visible: (cfg.icon.right || "") !== ""
                        width: visible ? rightIcon.size + 6 : 0
                        height: dayText.implicitHeight
                        SvgIcon { id: rightIcon; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; path: cfg.icon.right || ""; size: Math.round(win.sz * 1.05) }
                    }
                }

                // Hover zone over the WHOLE box: drives ws dots ("hover"/"both") AND the hub morph.
                // Follows clockBox (grows on expand -> hovering the buttons keeps the hub open). NoButton
                // -> clicks pass through to the dot/button MouseAreas underneath.
                MouseArea {
                    id: hoverMA
                    x: clockBox.x; y: clockBox.y; width: clockBox.width; height: clockBox.height
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: {
                        win.wsHover = containsMouse;
                        if (containsMouse) { holdTimer.stop(); win.holdOpen = false; collapseDelay.stop(); expandDelay.restart(); }
                        else { expandDelay.stop(); collapseDelay.restart(); }
                    }
                }
            }
        }
    }

    // ---- Notification popups (Overlay, top-right on the focused screen; auto-expire 5s) ----
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: pw
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell-hyprslob-popups"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            margins.top: 52; margins.right: 10
            readonly property bool onThis: Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === pw.screen.name
            visible: onThis && root.popups.length > 0
            implicitWidth: 312
            implicitHeight: Math.max(1, popCol.implicitHeight + 8)
            Column {
                id: popCol
                anchors { top: parent.top; left: parent.left; right: parent.right }
                spacing: 8
                Repeater {
                    model: root.popups
                    delegate: NotifCard {
                        required property var modelData
                        width: parent.width
                        notif: modelData; skin: pal; popup: true
                        onClosed: root.dropPopup(modelData)
                        Timer { interval: 5000; running: true; onTriggered: root.dropPopup(modelData) }
                    }
                }
            }
        }
    }
}
