import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var api: null
    property var pluginData: null

    implicitHeight: 420

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "0m";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h === 0) return m + "m";
        if (m === 0) return h + "h";
        return h + "h " + m + "m";
    }

    readonly property int currentStreak: {
        if (!api || !api.monthData || api.monthData.length === 0) return 0;
        const days = api.monthData.slice().reverse();
        let streak = 0;
        for (const day of days) {
            if ((day.grand_total && day.grand_total.total_seconds) > 0) streak++;
            else break;
        }
        return streak;
    }

    readonly property int longestStreakFromData: {
        if (!api || !api.monthData || api.monthData.length === 0) return 0;
        let best = 0, run = 0;
        for (const day of api.monthData) {
            if ((day.grand_total && day.grand_total.total_seconds) > 0) { run++; best = Math.max(best, run); }
            else run = 0;
        }
        return best;
    }

    // Persist best streak so it survives monthData rolling over 30 days
    onCurrentStreakChanged: {
        if (!api || !api.pluginService) return;
        const saved = parseInt(api.pluginService.loadPluginData("wakaTime", "bestStreak", "0")) || 0;
        const newBest = Math.max(saved, longestStreakFromData, currentStreak);
        if (newBest > saved)
            api.pluginService.savePluginData("wakaTime", "bestStreak", String(newBest));
    }

    readonly property int bestStreak: {
        if (!api || !api.pluginService) return longestStreakFromData;
        const saved = parseInt(api.pluginService.loadPluginData("wakaTime", "bestStreak", "0")) || 0;
        return Math.max(saved, longestStreakFromData);
    }

    readonly property var langSegments: {
        if (!api || !api.monthData) return [];
        const map = {};
        for (const day of api.monthData) {
            for (const l of (day.languages || [])) {
                if (!map[l.name]) map[l.name] = 0;
                map[l.name] += l.total_seconds || 0;
            }
        }
        const sorted = Object.entries(map).sort((a, b) => b[1] - a[1]).slice(0, 6);
        const palette = [Theme.primary, Theme.secondary, Theme.error,
                         Theme.warning, Theme.success, Theme.onSurfaceVariant];
        return sorted.map((e, i) => ({ label: e[0], value: e[1], color: palette[i % palette.length] }));
    }

    readonly property var dowData: {
        if (!api || !api.monthData) return new Array(7).fill(0);
        const totals = new Array(7).fill(0);
        const counts = new Array(7).fill(0);
        for (const day of api.monthData) {
            if (!day.range || !day.range.date) continue;
            const d = new Date(day.range.date + "T00:00:00").getDay();
            totals[d] += (day.grand_total && day.grand_total.total_seconds) || 0;
            counts[d]++;
        }
        return totals.map((t, i) => counts[i] > 0 ? Math.round(t / counts[i]) : 0);
    }

    readonly property string peakDay: {
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const max = Math.max.apply(null, dowData);
        if (max === 0) return "--";
        return days[dowData.indexOf(max)];
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

            // Streak cards
            Row {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { label: "Current streak", value: root.currentStreak + "d" },
                        { label: "Best streak", value: root.bestStreak + "d" }
                    ]

                    StyledRect {
                        width: (parent.width - Theme.spacingS) / 2
                        height: streakCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Column {
                            id: streakCol
                            anchors.centerIn: parent
                            spacing: 2

                            StyledText {
                                text: modelData.value
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: Theme.primary
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

            // Language pie chart
            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: root.langSegments.length > 0

                StyledText {
                    text: "Languages (30 days)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    PieChart {
                        width: 90
                        height: 90
                        segments: root.langSegments
                        surfaceColor: Theme.surface
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: root.langSegments

                            Row {
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: 10; height: 10; radius: 2
                                    color: modelData.color
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // Day-of-week productivity
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "By day of week"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                BarChart {
                    width: parent.width
                    height: 60
                    data: root.dowData
                    labels: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    highlightMax: true
                }

                StyledText {
                    text: "Most productive: " + root.peakDay
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
            }

            Item {
                width: parent.width
                height: 80
                visible: !api || !api.monthData || api.monthData.length === 0

                StyledText {
                    anchors.centerIn: parent
                    text: "No data yet — check back after a few coding sessions"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width * 0.8
                }
            }
        }
    }
}
