import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var api: null
    property var pluginData: null
    property int selectedDay: -1

    implicitHeight: 420

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "0m";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h === 0) return m + "m";
        if (m === 0) return h + "h";
        return h + "h " + m + "m";
    }

    function shortDay(dateStr) {
        if (!dateStr) return "";
        const d = new Date(dateStr + "T00:00:00");
        return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][d.getDay()];
    }

    readonly property var weekDays: api && api.weekData ? api.weekData : []
    readonly property var barData: weekDays.map(d => (d.grand_total && d.grand_total.total_seconds) || 0)
    readonly property var barLabels: weekDays.map(d => shortDay(d.range && d.range.date))
    readonly property int weekTotal: barData.reduce((a, b) => a + b, 0)
    readonly property int bestDaySeconds: barData.length > 0 ? Math.max.apply(null, barData) : 0
    readonly property var activeDay: selectedDay >= 0 && selectedDay < weekDays.length ? weekDays[selectedDay] : null

    readonly property var displayProjects: {
        if (activeDay) return (activeDay.projects || []).slice(0, 5);
        const map = {};
        for (const day of weekDays) {
            for (const p of (day.projects || [])) {
                if (!map[p.name]) map[p.name] = { name: p.name, total_seconds: 0 };
                map[p.name].total_seconds += p.total_seconds || 0;
            }
        }
        return Object.values(map).sort((a, b) => b.total_seconds - a.total_seconds).slice(0, 5);
    }

    readonly property var displayLanguages: {
        if (activeDay) return (activeDay.languages || []).slice(0, 5);
        const map = {};
        for (const day of weekDays) {
            for (const l of (day.languages || [])) {
                if (!map[l.name]) map[l.name] = { name: l.name, total_seconds: 0 };
                map[l.name].total_seconds += l.total_seconds || 0;
            }
        }
        return Object.values(map).sort((a, b) => b.total_seconds - a.total_seconds).slice(0, 5);
    }

    readonly property int displayTotal: activeDay
        ? ((activeDay.grand_total && activeDay.grand_total.total_seconds) || 0)
        : weekTotal

    readonly property int maxDisplaySeconds: {
        const items = displayProjects.concat(displayLanguages);
        return Math.max.apply(null, items.map(i => i.total_seconds || 0).concat([1]));
    }

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + Theme.spacingM * 2
        clip: true

        Column {
            id: contentCol
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Theme.spacingM
            }
            spacing: Theme.spacingM

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: root.selectedDay >= 0
                        ? (root.weekDays[root.selectedDay] && root.weekDays[root.selectedDay].range
                           ? root.weekDays[root.selectedDay].range.date : "Selected day")
                        : "Last 7 days"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                BarChart {
                    width: parent.width
                    height: 80
                    data: root.barData
                    labels: root.barLabels
                    highlightIndex: root.selectedDay
                    onBarClicked: index => {
                        root.selectedDay = (root.selectedDay === index) ? -1 : index;
                    }
                }
            }

            // Summary stats
            Row {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { label: root.selectedDay >= 0 ? "Day" : "Total", value: root.formatDuration(root.displayTotal) },
                        { label: "Avg/day", value: root.formatDuration(Math.round(root.weekTotal / 7)) },
                        { label: "Best day", value: root.formatDuration(root.bestDaySeconds) }
                        // TODO: week-over-week comparison requires last_14_days fetch (deferred)
                    ]

                    StyledRect {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        height: statCol.implicitHeight + Theme.spacingS * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            id: statCol
                            anchors.centerIn: parent
                            spacing: 2

                            StyledText {
                                text: modelData.value
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.onSurface
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.onSurfaceVariant
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.displayProjects.length > 0

                StyledText {
                    text: "Projects"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                Repeater {
                    model: root.displayProjects

                    HorizontalBar {
                        width: parent.width
                        label: modelData.name || ""
                        value: root.formatDuration(modelData.total_seconds)
                        ratio: (modelData.total_seconds || 0) / root.maxDisplaySeconds
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.displayLanguages.length > 0

                StyledText {
                    text: "Languages"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                Repeater {
                    model: root.displayLanguages

                    HorizontalBar {
                        width: parent.width
                        label: modelData.name || ""
                        value: root.formatDuration(modelData.total_seconds)
                        ratio: (modelData.total_seconds || 0) / root.maxDisplaySeconds
                    }
                }
            }

            Item {
                width: parent.width
                height: 80
                visible: root.weekDays.length === 0

                StyledText {
                    anchors.centerIn: parent
                    text: "No data for the past 7 days"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
            }
        }
    }
}
