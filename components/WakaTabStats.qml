import QtQuick
import qs.Common
import qs.Widgets

Item {
    property var api: null
    property var pluginData: null

    StyledText {
        anchors.centerIn: parent
        text: "Stats — coming soon"
        color: Theme.onSurfaceVariant
        font.pixelSize: Theme.fontSizeSmall
    }
}
