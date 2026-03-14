# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## What this project is

A DankMaterialShell (DMS) plugin that tracks coding time via WakaTime (or self-hosted alternatives: Wakapi, Hakatime). It renders as a pill in the DankBar and opens a 4-tab popout with detailed stats.

---

## Reference documentation (always fetch when needed)

These are the authoritative DMS docs. Fetch them when implementing plugin features:

- **Plugin System**: `https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/README.md`
- **PopoutService API**: `https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/POPOUT_SERVICE.md`
- **Theme Reference**: `https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/THEME_REFERENCE.md`

---

## Development workflow

### Install (symlink for live editing)
```bash
make symlink
# Creates: ~/.config/DankMaterialShell/plugins/dms-wakatime → this repo
```

### Reload / run DMS
```bash
qs -p $CONFIGPATH/quickshell/dms/shell.qml
# With verbose logs:
qs -v -p $CONFIGPATH/quickshell/dms/shell.qml
```

### Enable plugin
1. Open Settings (Ctrl+,) → Plugins → Scan for Plugins
2. Enable WakaTime toggle

### Watch logs
```bash
qs -v -p $CONFIGPATH/quickshell/dms/shell.qml 2>&1 | grep -E "WakaTime|PluginService"
```

---

## File structure

```
dms-wakatime/
├── plugin.json               # Plugin manifest
├── WakaTime.qml              # Root PluginComponent: pill + popout shell
├── WakaTimeSettings.qml      # PluginSettings with all user config fields
├── components/
│   ├── WakaHeader.qml        # Popout header: daily time + goal progress bar
│   ├── WakaTabToday.qml      # Tab 1: today's breakdown
│   ├── WakaTabWeek.qml       # Tab 2: last 7 days
│   ├── WakaTabProjects.qml   # Tab 3: projects with period selector
│   ├── WakaTabStats.qml      # Tab 4: streaks, pie charts, productivity patterns
│   ├── BarChart.qml          # Reusable vertical bar chart (Canvas)
│   ├── HorizontalBar.qml     # Reusable horizontal bar: label + value + percentage
│   └── PieChart.qml          # Reusable pie chart (Canvas)
└── utils/
    └── WakaAPI.qml           # All fetch logic, timers, .wakatime.cfg parsing, cache
```

---

## QML patterns — always follow these

### Imports
```qml
import QtQuick
import qs.Common          // Theme, Proc
import qs.Widgets         // StyledText, DankIcon, StyledRect
import qs.Modules.Plugins // PluginComponent, PluginSettings, PopoutComponent
import qs.Services        // PluginService
```

### Wrapping a widget
```qml
PluginComponent {
    horizontalBarPill: Component { /* ... */ }
    verticalBarPill: Component { /* ... */ }
    popoutContent: Component { PopoutComponent { /* ... */ } }
    popoutWidth: 480
    popoutHeight: 560
}
```

### Running external commands (curl)
Use `Proc.runCommand`, never `Process` directly for one-off calls:
```qml
Proc.runCommand(
    "wakaTime.fetchToday",
    ["curl", "-s", "-H", "Authorization: Basic " + token, apiUrl + "/users/current/status_bar/today"],
    (stdout, exitCode) => {
        if (exitCode === 0) { /* parse stdout */ }
    },
    100
)
```

### Persisting data
```qml
// Settings (survives restart):
pluginService.savePluginData("wakaTime", "apiKey", value)
pluginService.loadPluginData("wakaTime", "apiKey", "")

// Cache (runtime state, for fast reload):
pluginService.savePluginData("wakaTime", "cacheToday", JSON.stringify(data))
```

### Theme — never hardcode colors or sizes
```qml
// Colors
Theme.surfaceContainerHigh
Theme.onSurface
Theme.onSurfaceVariant
Theme.primary
Theme.error

// Spacing
Theme.spacingS / Theme.spacingM / Theme.spacingL

// Font sizes
Theme.fontSizeSmall / Theme.fontSizeMedium / Theme.fontSizeLarge

// Corner radius
Theme.cornerRadius
```

### Canvas-based charts
All charts (BarChart, PieChart) use QML `Canvas`. Redraw by calling `requestPaint()` when data changes. Use `ctx.fillStyle = Theme.primary` for colors — pass theme colors as properties into the Canvas item.

### Toast notifications
```qml
ToastService.showInfo("Connection successful: " + username)
ToastService.showError("WakaTime API error: " + errorMsg)
```

---

## WakaTime API

Base URL: `https://wakatime.com/api/v1` (configurable for self-hosted)

Auth: `Authorization: Basic base64(api_key + ":")`

Key endpoints:
| Endpoint | Used for |
|---|---|
| `GET /users/current/status_bar/today` | Pill: current time, project, language, editor |
| `GET /users/current/summaries?range=today` | Tab Hoje: hourly activity, top projects/langs |
| `GET /users/current/summaries?range=last_7_days` | Tab Semana |
| `GET /users/current/summaries?range=last_30_days` | Tab Projetos + Tab Stats |
| `GET /users/current` | Settings: test connection |

Self-hosted detection (from `api_url` setting):
- Contains `hakatime` → badge "Hakatime"
- Any other non-wakatime.com URL → badge "Wakapi"

### Reading ~/.wakatime.cfg
```bash
cat ~/.wakatime.cfg
```
Parse INI format: look for `api_key =` and `api_url =` lines.

---

## Timer strategy

| Timer ID | Endpoint | Interval | Start |
|---|---|---|---|
| `pillTimer` | `status_bar/today` | 5 min | Immediately (`triggeredOnStart: true`) |
| `todayTimer` | `summaries?range=today` | 15 min | After 10s delay |
| `weekTimer` | `summaries?range=last_7_days` | 30 min | After 10s delay |
| `monthTimer` | `summaries?range=last_30_days` | 60 min | After 10s delay |

On fetch failure: keep previous cache, mark data as stale. Never clear cache on error.

---

## Settings fields (WakaTimeSettings.qml)

All via `PluginSettings` + setting components. Keys stored under plugin ID `"wakaTime"`:

| Key | Type | Default | Purpose |
|---|---|---|---|
| `apiKey` | string | `""` | Overrides ~/.wakatime.cfg |
| `apiUrl` | string | `""` | Custom base URL (Wakapi/Hakatime) |
| `dailyGoalHours` | number | `4` | Daily coding goal in hours |
| `activeDays` | array | `[1,2,3,4,5]` | Active weekdays (0=Sun) |
| `pillDisplayField` | string | `"project"` | What to show next to time: project/language/editor/none |
| `showGoalColor` | bool | `true` | Color icon based on goal progress |
| `pillIntervalMin` | number | `5` | Pill refresh interval (minutes) |
| `todayIntervalMin` | number | `15` | Today data refresh interval |
| `weekIntervalMin` | number | `30` | Week data refresh interval |
| `defaultProjectPeriod` | string | `"7d"` | Default period in Projects tab |

---

## Special states to handle

| State | Pill shows | Popout shows |
|---|---|---|
| No ~/.wakatime.cfg or no api_key | icon + `configurar` | Onboarding card with install instructions |
| API error / network down | gray icon + cached time + warning dot | Stale banner: "Dados desatualizados · última atualização há Xmin" |
| 0 minutes today | `⌨ 0m` | Motivational message + week breakdown as fallback |
| Self-hosted URL | Normal | Small "Wakapi" or "Hakatime" badge in popout header |

---

## Icon color logic (pill)

Based on `(secondsToday / dailyGoalSeconds)` ratio:
- `< 0.5` → `Theme.error` (red)
- `0.5 - 0.9` → `Theme.warning` (yellow)
- `>= 0.9` → `Theme.success` (green)
- No data → `Theme.onSurfaceVariant` (gray)

---

## Common pitfalls

- **Never use `globalThis.clipboard`** — use `Quickshell.execDetached(["dms", "cl", "copy", text])`
- **Never hardcode colors/sizes** — always `Theme.*`
- **Canvas charts**: pass theme colors as QML properties, don't access `Theme` inside `onPaint` JS context
- **JSON parsing**: wrap in try/catch — API may return error objects or empty strings
- **Base64 encoding** for WakaTime auth: use `Qt.btoa(apiKey + ":")` (available in Qt 6.x QML)
- **Proc.runCommand IDs** must be unique per call site, use namespaced format: `"wakaTime.actionName"`
- **Settings component** requires `permissions: ["settings_read", "settings_write"]` in plugin.json
