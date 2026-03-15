import QtQuick
import qs.Common

Item {
    id: root

    property var data: []
    property var labels: []
    property int highlightIndex: -1
    property bool highlightMax: false
    property color barColor: Theme.primary
    property color barColorDim: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.35)
    property color labelColor: Theme.onSurfaceVariant

    signal barClicked(int index)

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!root.data || root.data.length === 0)
                return;

            const n = root.data.length;
            const max = Math.max.apply(null, root.data.concat([1]));
            const labelH = root.labels.length > 0 ? 14 : 0;
            const chartH = height - labelH - 4;
            const barW = width / n;

            for (let i = 0; i < n; i++) {
                const isHighlight = root.highlightMax
                    ? root.data[i] === max
                    : (root.highlightIndex >= 0 ? i === root.highlightIndex : false);
                const ratio = root.data[i] / max;
                const bh = Math.max(ratio * chartH, root.data[i] > 0 ? 2 : 0);
                const x = i * barW + barW * 0.15;
                const w = barW * 0.7;

                ctx.fillStyle = isHighlight ? root.barColor : root.barColorDim;
                ctx.beginPath();
                if (ctx.roundRect) {
                    ctx.roundRect(x, chartH - bh, w, bh, 2);
                } else {
                    ctx.rect(x, chartH - bh, w, bh);
                }
                ctx.fill();

                if (root.labels[i] !== undefined && root.labels[i] !== "") {
                    ctx.fillStyle = root.labelColor;
                    ctx.font = "10px sans-serif";
                    ctx.textAlign = "center";
                    ctx.fillText(root.labels[i], x + w / 2, height - 2);
                }
            }
        }

        Connections {
            target: root
            function onDataChanged() { canvas.requestPaint(); }
            function onHighlightIndexChanged() { canvas.requestPaint(); }
            function onHighlightMaxChanged() { canvas.requestPaint(); }
            function onBarColorChanged() { canvas.requestPaint(); }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            if (!root.data || root.data.length === 0)
                return;
            const i = Math.floor(mouse.x / (width / root.data.length));
            if (i >= 0 && i < root.data.length)
                root.barClicked(i);
        }
    }
}
