import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string label: ""
    property string value: ""
    property real ratio: 0.0
    property string percentage: ""

    implicitHeight: 24

    Row {
        anchors.fill: parent
        spacing: Theme.spacingS

        StyledText {
            id: labelText
            width: 110
            text: root.label
            elide: Text.ElideRight
            color: Theme.onSurface
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - labelText.width - valueText.implicitWidth
                   - (percentText.visible ? percentText.implicitWidth + Theme.spacingS : 0)
                   - Theme.spacingS * 2
            height: 6
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.surfaceContainerHighest
            }

            Rectangle {
                width: parent.width * Math.min(Math.max(root.ratio, 0), 1)
                height: parent.height
                radius: 3
                color: Theme.primary
            }
        }

        StyledText {
            id: valueText
            text: root.value
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            id: percentText
            visible: root.percentage !== ""
            text: root.percentage
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
