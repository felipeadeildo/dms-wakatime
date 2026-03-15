// Settings UI. Zero business logic, all fields are declarative settings
// components.

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "wakaTime"

    // ── Daily goal ───────────────────────────────────────────────────────────

    StyledText {
        text: "Daily goal"
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "dailyGoalHours"
        label: "Hours per day"
        options: [
            {
                label: "1h",
                value: "1"
            },
            {
                label: "1.5h",
                value: "1.5"
            },
            {
                label: "2h",
                value: "2"
            },
            {
                label: "2.5h",
                value: "2.5"
            },
            {
                label: "3h",
                value: "3"
            },
            {
                label: "4h",
                value: "4"
            },
            {
                label: "5h",
                value: "5"
            },
            {
                label: "6h",
                value: "6"
            },
            {
                label: "8h",
                value: "8"
            },
            {
                label: "10h",
                value: "10"
            },
            {
                label: "12h",
                value: "12"
            }
        ]
        defaultValue: "4"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // ── Bar pill ─────────────────────────────────────────────────────────────

    StyledText {
        text: "Bar pill"
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "pillDisplayField"
        label: "Show next to time"
        options: [
            {
                label: "Project",
                value: "project"
            },
            {
                label: "Language",
                value: "language"
            },
            {
                label: "Editor",
                value: "editor"
            },
            {
                label: "Nothing",
                value: "none"
            }
        ]
        defaultValue: "project"
    }

    ToggleSetting {
        settingKey: "showGoalColor"
        label: "Goal color indicator"
        description: "Icon color reflects daily goal progress"
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // ── Refresh intervals ────────────────────────────────────────────────────

    StyledText {
        text: "Refresh intervals"
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "pillIntervalMin"
        label: "Pill (current status)"
        options: [1, 2, 3, 5, 10].map(v => ({
                    label: v + " min",
                    value: String(v)
                }))
        defaultValue: "5"
    }

    SelectionSetting {
        settingKey: "todayIntervalMin"
        label: "Today data"
        options: [5, 10, 15, 20, 30].map(v => ({
                    label: v + " min",
                    value: String(v)
                }))
        defaultValue: "15"
    }

    SelectionSetting {
        settingKey: "weekIntervalMin"
        label: "Week data"
        options: [15, 20, 30, 45, 60].map(v => ({
                    label: v + " min",
                    value: String(v)
                }))
        defaultValue: "30"
    }

    SelectionSetting {
        settingKey: "defaultProjectPeriod"
        label: "Default period in Projects tab"
        options: [
            {
                label: "Today",
                value: "today"
            },
            {
                label: "7 days",
                value: "7d"
            },
            {
                label: "30 days",
                value: "30d"
            },
            {
                label: "6 months",
                value: "6m"
            }
        ]
        defaultValue: "7d"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // ── API ──────────────────────────────────────────────────────────────────

    StyledText {
        text: "API"
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
    }

    StyledText {
        text: "Auto-detected from ~/.wakatime.cfg. Override only if needed (e.g. Wakapi, Hakatime)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent.width
    }

    StringSetting {
        settingKey: "apiKey"
        label: "API Key"
        description: "Overrides ~/.wakatime.cfg"
        placeholder: "waka_..."
        defaultValue: ""
    }

    StringSetting {
        settingKey: "apiUrl"
        label: "API URL"
        description: "For Wakapi or Hakatime. Leave empty for wakatime.com"
        placeholder: "https://api.wakatime.com/api/v1"
        defaultValue: ""
    }
}
