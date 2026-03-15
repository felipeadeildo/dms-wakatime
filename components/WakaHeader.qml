import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string totalTime: "--"
    property int totalSeconds: 0
    property bool hasError: false
    property var lastSuccessTime: null
    property string apiUrl: ""
    property real dailyGoalHours: 4
    property bool showGoalColor: true

    implicitHeight: contentCol.implicitHeight + Theme.spacingM * 2

    readonly property real goalRatio: {
        if (totalSeconds <= 0)
            return 0;
        return Math.min(totalSeconds / (dailyGoalHours * 3600), 1.0);
    }

    readonly property color progressColor: {
        if (!showGoalColor)
            return Theme.primary;
        if (goalRatio >= 0.9)
            return Theme.success;
        if (goalRatio >= 0.5)
            return Theme.warning;
        return Theme.error;
    }

    readonly property string serviceType: {
        if (!apiUrl || apiUrl.includes("wakatime.com"))
            return "";
        if (apiUrl.toLowerCase().includes("hakatime"))
            return "Hakatime";
        return "Wakapi";
    }

    readonly property string staleText: {
        if (!hasError || !lastSuccessTime)
            return "";
        const diff = Math.floor((Date.now() - new Date(lastSuccessTime).getTime()) / 60000);
        return "Stale data · last updated " + diff + "m ago";
    }

    Column {
        id: contentCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacingM
        }
        spacing: Theme.spacingS

        Row {
            spacing: Theme.spacingS
            anchors.left: parent.left

            StyledText {
                text: root.totalTime
                font.pixelSize: 28
                font.weight: Font.Bold
                color: Theme.onSurface
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                visible: root.serviceType !== ""
                height: 18
                width: badgeLabel.implicitWidth + 10
                radius: 4
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.serviceType
                    font.pixelSize: 10
                    color: Theme.primary
                }
            }
        }

        Item {
            width: parent.width
            height: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.surfaceContainerHighest
            }

            Rectangle {
                width: parent.width * root.goalRatio
                height: parent.height
                radius: 3
                color: root.progressColor

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        StyledText {
            text: Math.round(root.goalRatio * 100) + "% of " + root.dailyGoalHours + "h goal"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
        }

        Rectangle {
            visible: root.hasError && root.staleText !== ""
            width: parent.width
            height: staleTextItem.implicitHeight + Theme.spacingXS * 2
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)

            StyledText {
                id: staleTextItem
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Theme.spacingS
                }
                text: root.staleText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
                wrapMode: Text.WordWrap
            }
        }
    }
}
