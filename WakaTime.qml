// Root PluginComponent. Owns the bar pill UI and the popout shell.
// All data logic is delegated to WakaAPI.

import QtQuick
import "./utils"
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // API module
    WakaAPI {
        id: api
        pluginService: root.pluginService
    }

    // Scalar properties forwarded from api — safe to reference from Component{} via root.*
    readonly property bool apiConfigured: api ? api.isConfigured : false
    readonly property string apiTotalTime: api ? (api.totalTimeToday || "0m") : "--"
    readonly property string apiProject: api ? api.currentProject : ""
    readonly property string apiLanguage: api ? api.currentLanguage : ""
    readonly property string apiEditor: api ? api.currentEditor : ""
    readonly property int apiTotalSeconds: api ? api.totalSecondsToday : 0

    readonly property color iconColor: {
        if (!api || !api.isConfigured || api.totalSecondsToday === 0)
            return Theme.surfaceText;
        if (pluginData.showGoalColor === false)
            return Theme.surfaceText;
        const goal = (parseFloat(pluginData.dailyGoalHours) || 4) * 3600;
        const ratio = api.totalSecondsToday / goal;
        if (ratio >= 0.9)
            return Theme.success;
        if (ratio >= 0.5)
            return Theme.warning;
        return Theme.error;
    }

    readonly property string pillExtraText: {
        if (!api || !api.isConfigured)
            return "";
        const field = pluginData.pillDisplayField || "project";
        switch (field) {
        case "project":  return api.currentProject;
        case "language": return api.currentLanguage;
        case "editor":   return api.currentEditor;
        default:         return "";
        }
    }

    // Bar pill (horizontal)
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "keyboard"
                color: root.iconColor
                size: Theme.iconSize - 6
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.apiConfigured ? root.apiTotalTime : "configure"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.pillExtraText !== ""
                text: "•"
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.pillExtraText !== ""
                text: root.pillExtraText
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Popout (placeholder - filled in Phase 2+)
    popoutWidth: 480
    popoutHeight: 600

    popoutContent: Component {
        PopoutComponent {
            showCloseButton: true

            StyledText {
                anchors.centerIn: parent
                text: "WakaTime - coming soon"
                color: Theme.onSurfaceVariant
            }
        }
    }
}
