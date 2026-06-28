// Accent fill that samples the shared rolling rainbow band ACROSS its own width as a SMOOTH
// gradient (Canvas createLinearGradient sampled from the band at this element's global x, so the
// band rolls across the fill - same band as the clock). Solid accent when rainbow is off.
import QtQuick

Canvas {
    id: bf
    property var skin
    antialiasing: true

    readonly property real ph: skin ? skin.phase : 0   // repaint as the band rolls
    onPhChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onSkinChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height;
        if (w < 1 || h < 1) return;
        if (skin && skin.isRainbow("accent") && skin.stops && skin.stops.length >= 2) {
            const x0 = mapToItem(null, 0, 0).x;
            const grad = ctx.createLinearGradient(0, 0, w, 0);
            const N = 16;
            for (let k = 0; k <= N; k++)
                grad.addColorStop(k / N, skin.bandHex(x0 + (k / N) * w));
            ctx.fillStyle = grad;
        } else {
            ctx.fillStyle = skin ? skin.accentHex : "#ffffff";
        }
        ctx.fillRect(0, 0, w, h);
    }
}
