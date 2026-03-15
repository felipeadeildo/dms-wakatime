import QtQuick
import qs.Common
import qs.Widgets

Item {
    property var api: null
    property var pluginData: null

    StyledText {
        anchors.centerIn: parent
        text: "Week — coming soon"
        color: Theme.onSurfaceVariant
        font.pixelSize: Theme.fontSizeSmall
    }
}
