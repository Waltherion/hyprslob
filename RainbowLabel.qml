import QtQuick

// Text where EACH character is colored based on its GLOBAL x-position in the bar (via mapToItem)
// + an animated phase. Multiple RainbowLabels with the same `phase`/`period`/`stops` form one
// continuous rainbow band running across all modules (the text = the "window" into the band).
// rainbow=false -> single-color `solid` (used by non-neon themes).
Row {
    id: rl

    property string content: ""
    property string family: "sans"
    property int pixelSize: 16
    property int fontWeight: 400
    property bool upper: false
    property real letterSpacing: 0
    property var features: ({})

    property bool rainbow: true
    property color solid: Qt.rgba(1, 1, 1, 1)
    property var stops: []           // rainbow colors (#rrggbb)
    property real phase: 0           // animated 0..1
    property real period: 800        // px per full rainbow

    // stops parsed to {r,g,b} floats ONCE (only when stops changes) so colAt -- called per
    // character every phase tick (~16x/s) -- stays plain float lerps, no slice()/parseInt().
    readonly property var _rgb: {
        var s = rl.stops, out = [];
        for (var i = 0; i < (s ? s.length : 0); i++) {
            var h = s[i];
            if (typeof h !== "string" || h.length < 7) continue;
            out.push({ r: parseInt(h.slice(1, 3), 16) / 255,
                       g: parseInt(h.slice(3, 5), 16) / 255,
                       b: parseInt(h.slice(5, 7), 16) / 255 });
        }
        return out;
    }

    function colAt(px) {
        const s = rl._rgb;
        if (!s || s.length < 2) return rl.solid;
        let t = (((px / rl.period + rl.phase) % 1) + 1) % 1;
        const n = s.length, f = t * n;
        const i = Math.floor(f) % n, j = (i + 1) % n, fr = f - Math.floor(f);
        const a = s[i], b = s[j];
        return Qt.rgba(a.r + (b.r - a.r) * fr, a.g + (b.g - a.g) * fr, a.b + (b.b - a.b) * fr, 1);
    }

    // code-point iteration (Array.from) so nerd-font icons (including outside BMP) aren't split
    readonly property var chars: rl.content ? Array.from(rl.content) : []

    Repeater {
        model: rl.chars.length
        delegate: Text {
            required property int index
            text: rl.chars[index]
            font.family: rl.family
            font.pixelSize: rl.pixelSize
            font.weight: rl.fontWeight
            font.capitalization: rl.upper ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: rl.letterSpacing
            font.features: rl.features
            // global character center in window coordinates; recomputes every phase tick (also during morph)
            color: rl.rainbow ? rl.colAt(mapToItem(null, x + width / 2, 0).x) : rl.solid
        }
    }
}
