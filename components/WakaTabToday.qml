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

    readonly property var hourlyData: {
        const arr = new Array(24).fill(0);
        if (!api || !api.durationsData) return arr;
        for (const d of api.durationsData) {
            const hour = Math.floor((d.time % 86400) / 3600);
            if (hour >= 0 && hour < 24)
                arr[hour] += Math.round(d.duration / 60);
        }
        return arr;
    }

    readonly property var todayProjects: {
        if (!api || !api.todayData || !api.todayData[0]) return [];
        return (api.todayData[0].projects || []).slice(0, 5);
    }

    readonly property var todayLanguages: {
        if (!api || !api.todayData || !api.todayData[0]) return [];
        return (api.todayData[0].languages || []).slice(0, 5);
    }

    readonly property int maxProjectSeconds: {
        if (todayProjects.length === 0) return 1;
        return Math.max.apply(null, todayProjects.map(p => p.total_seconds || 0).concat([1]));
    }

    readonly property int maxLangSeconds: {
        if (todayLanguages.length === 0) return 1;
        return Math.max.apply(null, todayLanguages.map(l => l.total_seconds || 0).concat([1]));
    }

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + Theme.spacingM * 2
        clip: true

        Column {
            id: contentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacingM
            }
            spacing: Theme.spacingM

            // "Now" card
            StyledRect {
                width: parent.width
                implicitHeight: nowCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                visible: api && api.currentProject !== ""

                Column {
                    id: nowCol
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        margins: Theme.spacingM
                    }
                    spacing: Theme.spacingXS

                    StyledText {
                        text: api ? api.currentProject : ""
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.onSurface
                    }

                    Row {
                        spacing: Theme.spacingS

                        Repeater {
                            model: {
                                const badges = [];
                                if (api && api.currentLanguage) badges.push(api.currentLanguage);
                                if (api && api.currentEditor) badges.push(api.currentEditor);
                                return badges;
                            }

                            Rectangle {
                                height: 18
                                width: badgeText.implicitWidth + 10
                                radius: 4
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                                StyledText {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 10
                                    color: Theme.primary
                                }
                            }
                        }
                    }
                }
            }

            // Hourly chart
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Activity today"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                BarChart {
                    width: parent.width
                    height: 72
                    data: root.hourlyData
                    labels: {
                        const lbls = new Array(24).fill("");
                        lbls[0] = "0"; lbls[6] = "6"; lbls[12] = "12"; lbls[18] = "18";
                        return lbls;
                    }
                    highlightMax: true
                }
            }

            // Top projects
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.todayProjects.length > 0

                StyledText {
                    text: "Projects"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                Repeater {
                    model: root.todayProjects

                    HorizontalBar {
                        width: parent.width
                        label: modelData.name || ""
                        value: root.formatDuration(modelData.total_seconds)
                        ratio: (modelData.total_seconds || 0) / root.maxProjectSeconds
                    }
                }
            }

            // Top languages
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.todayLanguages.length > 0

                StyledText {
                    text: "Languages"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                Repeater {
                    model: root.todayLanguages

                    HorizontalBar {
                        width: parent.width
                        label: modelData.name || ""
                        value: root.formatDuration(modelData.total_seconds)
                        ratio: (modelData.total_seconds || 0) / root.maxLangSeconds
                        percentage: modelData.percent ? Math.round(modelData.percent) + "%" : ""
                    }
                }
            }

            // Empty state
            Item {
                width: parent.width
                height: 80
                visible: root.todayProjects.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "keyboard"
                        size: Theme.iconSize
                        color: Theme.onSurfaceVariant
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "No activity yet today"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurfaceVariant
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
