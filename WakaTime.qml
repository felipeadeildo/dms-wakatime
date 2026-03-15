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

    // Computed pill properties — declared as properties so QML tracks
    // api.* dependencies and re-evaluates automatically when data changes.
    readonly property color iconColor: {
        if (!api.isConfigured || api.totalSecondsToday === 0)
            return Theme.onSurfaceVariant;
        const showColor = pluginService ? pluginService.loadPluginData("wakaTime", "showGoalColor", true) : true;
        if (!showColor)
            return Theme.onSurface;
        const goalHours = pluginService ? parseFloat(pluginService.loadPluginData("wakaTime", "dailyGoalHours", "4")) : 4;
        const ratio = api.totalSecondsToday / (goalHours * 3600);
        if (ratio >= 0.9)
            return Theme.success;
        if (ratio >= 0.5)
            return Theme.warning;
        return Theme.error;
    }

    readonly property string pillExtraText: {
        if (!api.isConfigured)
            return "";
        const field = pluginService ? pluginService.loadPluginData("wakaTime", "pillDisplayField", "project") : "project";
        switch (field) {
        case "project":
            return api.currentProject;
        case "language":
            return api.currentLanguage;
        case "editor":
            return api.currentEditor;
        default:
            return "";
        }
    }

    // Bar pill (horizontal)
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "keyboard"
                color: root.iconColor
                size: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.api.isConfigured ? root.api.totalTimeToday : "configure"
                color: Theme.onSurface
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
