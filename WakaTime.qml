// Root PluginComponent. Owns the bar pill UI and the popout shell.
// All data logic is delegated to WakaAPI.
// Uses PluginGlobalVar to sync state across bar instances (one per monitor).

import QtQuick
import "./utils"
import "./components"
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Owner election: first instance to set this wins
    property string instanceId: Math.random().toString(36).substring(2)

    PluginGlobalVar {
        id: gvOwner
        varName: "ownerId"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: gvConfigured
        varName: "isConfigured"
        defaultValue: false
    }

    PluginGlobalVar {
        id: gvTotalTime
        varName: "totalTimeToday"
        defaultValue: "--"
    }

    PluginGlobalVar {
        id: gvTotalSeconds
        varName: "totalSecondsToday"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: gvProject
        varName: "currentProject"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: gvLanguage
        varName: "currentLanguage"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: gvEditor
        varName: "currentEditor"
        defaultValue: ""
    }

    readonly property bool isOwner: gvOwner.value === instanceId

    // API module — only runs fetches when this instance is owner
    WakaAPI {
        id: api
        pluginService: root.pluginService
        isOwner: root.isOwner

        onPillDataUpdated: {
            gvTotalTime.set(api.totalTimeToday);
            gvTotalSeconds.set(api.totalSecondsToday);
            gvProject.set(api.currentProject);
            gvLanguage.set(api.currentLanguage);
            gvEditor.set(api.currentEditor);
        }

        onConfigLoaded: {
            gvConfigured.set(api.isConfigured);
        }
    }

    // pluginId is injected by DMS when pluginService is set — wait for it
    onPluginIdChanged: {
        if (!pluginId)
            return;
        if (!gvOwner.value)
            gvOwner.set(instanceId);
    }

    // Read from globals — all instances stay in sync
    readonly property bool apiConfigured: gvConfigured.value
    readonly property string apiTotalTime: gvTotalTime.value || "0m"
    readonly property int apiTotalSeconds: gvTotalSeconds.value
    readonly property string apiProject: gvProject.value
    readonly property string apiLanguage: gvLanguage.value
    readonly property string apiEditor: gvEditor.value

    readonly property real goalRatio: {
        if (!apiConfigured || apiTotalSeconds === 0)
            return 0;
        const goal = (parseFloat(pluginData.dailyGoalHours) || 4) * 3600;
        return Math.min(apiTotalSeconds / goal, 1.0);
    }

    readonly property color progressColor: {
        if (!apiConfigured || apiTotalSeconds === 0)
            return Theme.surfaceVariant;
        if (pluginData.showGoalColor === false)
            return Theme.primary;
        if (goalRatio >= 0.9)
            return Theme.success;
        if (goalRatio >= 0.5)
            return Theme.warning;
        return Theme.error;
    }

    readonly property string pillExtraText: {
        if (!apiConfigured)
            return "";
        const field = pluginData.pillDisplayField || "project";
        switch (field) {
        case "project":
            return apiProject;
        case "language":
            return apiLanguage;
        case "editor":
            return apiEditor;
        default:
            return "";
        }
    }

    // Bar pill (horizontal)
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            // Goal progress arc
            Canvas {
                id: progressRing
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                renderStrategy: Canvas.Cooperative

                property real ratio: root.goalRatio
                property color ringColor: root.progressColor
                property color bgColor: Theme.surfaceVariant

                onRatioChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var cx = width / 2, cy = height / 2, r = 7, lw = 2.5;

                    // Background circle
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.lineWidth = lw;
                    ctx.strokeStyle = bgColor;
                    ctx.stroke();

                    // Progress arc
                    if (ratio > 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * ratio);
                        ctx.lineWidth = lw;
                        ctx.strokeStyle = ringColor;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }
            }

            StyledText {
                text: root.apiConfigured ? root.apiTotalTime : "configure"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.pillExtraText !== ""
                text: "•"
                color: Theme.surfaceTextMedium
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.pillExtraText !== ""
                text: root.pillExtraText
                color: Theme.surfaceTextMedium
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Popout
    popoutWidth: 480
    popoutHeight: 600

    popoutContent: Component {
        PopoutComponent {
            id: popout
            showCloseButton: true

            property int currentTab: 0

            Column {
                width: parent.width
                spacing: 0

                WakaHeader {
                    width: parent.width
                    totalTime: root.apiTotalTime
                    totalSeconds: root.apiTotalSeconds
                    hasError: api.hasError
                    lastSuccessTime: api.lastSuccessTime
                    apiUrl: api.apiUrl
                    dailyGoalHours: parseFloat(pluginData.dailyGoalHours) || 4
                    showGoalColor: pluginData.showGoalColor !== false
                }

                // Tab bar
                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: ["Today", "Week", "Projects", "Stats"]

                            Item {
                                width: popout.width / 4
                                height: 40

                                readonly property bool active: popout.currentTab === index

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 2
                                    color: parent.active ? Theme.primary : "transparent"
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: parent.active ? Font.Medium : Font.Normal
                                    color: parent.active ? Theme.primary : Theme.onSurfaceVariant
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popout.currentTab = index
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                }

                // Tab content — uses Qt.resolvedUrl so path resolves from plugin root
                Loader {
                    id: tabLoader
                    width: parent.width
                    height: 420
                    source: {
                        switch (popout.currentTab) {
                        case 0: return Qt.resolvedUrl("components/WakaTabToday.qml")
                        case 1: return Qt.resolvedUrl("components/WakaTabWeek.qml")
                        case 2: return Qt.resolvedUrl("components/WakaTabProjects.qml")
                        case 3: return Qt.resolvedUrl("components/WakaTabStats.qml")
                        default: return ""
                        }
                    }
                    onLoaded: {
                        item.api = api
                        item.pluginData = root.pluginData
                    }
                }
            }
        }
    }
}
