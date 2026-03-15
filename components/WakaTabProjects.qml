import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var api: null
    property var pluginData: null
    property string selectedPeriod: (pluginData && pluginData.defaultProjectPeriod) || "7d"
    property int expandedIndex: -1

    implicitHeight: 420

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "0m";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h === 0) return m + "m";
        if (m === 0) return h + "h";
        return h + "h " + m + "m";
    }

    readonly property var sourceData: {
        if (!api) return null;
        switch (root.selectedPeriod) {
        case "today": return api.todayData;
        case "7d":    return api.weekData;
        case "30d":   return api.monthData;
        case "6m":    return api.monthData; // 6m falls back to monthData (30-day endpoint)
        default:      return api.weekData;
        }
    }

    readonly property var projectList: {
        if (!sourceData || sourceData.length === 0) return [];
        const map = {};
        for (const day of sourceData) {
            for (const p of (day.projects || [])) {
                if (!map[p.name]) map[p.name] = { name: p.name, total_seconds: 0, languages: {} };
                map[p.name].total_seconds += p.total_seconds || 0;
            }
            // Best-effort: attribute language time to the top project of the day
            const topProj = (day.projects && day.projects[0]) ? day.projects[0].name : null;
            if (topProj && map[topProj]) {
                for (const l of (day.languages || [])) {
                    if (!map[topProj].languages[l.name]) map[topProj].languages[l.name] = 0;
                    map[topProj].languages[l.name] += l.total_seconds || 0;
                }
            }
        }
        return Object.values(map)
            .sort((a, b) => b.total_seconds - a.total_seconds)
            .slice(0, 20);
    }

    readonly property int totalSeconds: projectList.reduce((a, p) => a + p.total_seconds, 0)

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

            // Period selector
            Row {
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { label: "Today", value: "today" },
                        { label: "7 days", value: "7d" },
                        { label: "30 days", value: "30d" },
                        { label: "6 months", value: "6m" }
                    ]

                    Rectangle {
                        height: 26
                        width: chipLabel.implicitWidth + 16
                        radius: 13
                        color: root.selectedPeriod === modelData.value
                            ? Theme.primary
                            : Theme.surfaceContainerHighest

                        StyledText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.selectedPeriod === modelData.value
                                ? Theme.onPrimary
                                : Theme.onSurface
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedPeriod = modelData.value;
                                root.expandedIndex = -1;
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.projectList.length > 0

                Repeater {
                    model: root.projectList

                    Column {
                        id: projectEntry
                        width: parent.width
                        spacing: 0

                        required property var modelData
                        required property int index

                        readonly property bool expanded: root.expandedIndex === index

                        StyledRect {
                            width: parent.width
                            height: 44
                            radius: Theme.cornerRadius
                            color: projectEntry.expanded
                                ? Theme.surfaceContainerHighest
                                : (rowArea.containsMouse ? Theme.surfaceContainerHigh : "transparent")

                            Row {
                                anchors {
                                    left: parent.left; right: chevron.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Theme.spacingS; rightMargin: Theme.spacingS
                                }
                                spacing: Theme.spacingS

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    width: parent.width - timeText.implicitWidth - Theme.spacingS

                                    StyledText {
                                        text: projectEntry.modelData.name || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.onSurface
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Rectangle {
                                        width: parent.width * Math.min(
                                            (projectEntry.modelData.total_seconds || 0) / Math.max(root.totalSeconds, 1), 1)
                                        height: 3
                                        radius: 2
                                        color: Theme.primary
                                        opacity: 0.6
                                    }
                                }

                                StyledText {
                                    id: timeText
                                    text: root.formatDuration(projectEntry.modelData.total_seconds)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.onSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            DankIcon {
                                id: chevron
                                anchors {
                                    right: parent.right; verticalCenter: parent.verticalCenter
                                    rightMargin: Theme.spacingS
                                }
                                name: projectEntry.expanded ? "expand_less" : "expand_more"
                                size: Theme.iconSize - 4
                                color: Theme.onSurfaceVariant
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.expandedIndex = (root.expandedIndex === projectEntry.index)
                                        ? -1 : projectEntry.index;
                                }
                            }
                        }

                        // Expanded language detail
                        Column {
                            visible: projectEntry.expanded
                            width: parent.width
                            spacing: Theme.spacingXS
                            leftPadding: Theme.spacingM
                            topPadding: Theme.spacingXS
                            bottomPadding: Theme.spacingXS

                            Repeater {
                                model: Object.entries(projectEntry.modelData.languages || {})
                                    .sort((a, b) => b[1] - a[1]).slice(0, 5)

                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: modelData[0]
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.onSurface
                                        width: 100
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        text: root.formatDuration(modelData[1])
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 80
                visible: root.projectList.length === 0

                StyledText {
                    anchors.centerIn: parent
                    text: "No project data for this period"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
            }
        }
    }
}
