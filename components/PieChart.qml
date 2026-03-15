import QtQuick
import qs.Common

Item {
    id: root

    property var segments: []
    property color surfaceColor: Theme.surfaceContainerHigh

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!root.segments || root.segments.length === 0)
                return;

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(cx, cy) - 4;
            const total = root.segments.reduce((s, seg) => s + (seg.value || 0), 0);

            if (total <= 0)
                return;

            let angle = -Math.PI / 2;
            for (let i = 0; i < root.segments.length; i++) {
                const seg = root.segments[i];
                const sweep = (seg.value / total) * Math.PI * 2;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, r, angle, angle + sweep);
                ctx.closePath();
                ctx.fillStyle = seg.color || Theme.primary;
                ctx.fill();
                angle += sweep;
            }

            // Donut hole
            ctx.beginPath();
            ctx.arc(cx, cy, r * 0.52, 0, Math.PI * 2);
            ctx.fillStyle = root.surfaceColor;
            ctx.fill();
        }

        Connections {
            target: root
            function onSegmentsChanged() { canvas.requestPaint(); }
            function onSurfaceColorChanged() { canvas.requestPaint(); }
        }
    }
}
