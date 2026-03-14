# SPEC.md — dms-wakatime

Especificação técnica completa para agentes de código implementarem o plugin.
Leia IDEA.md para o contexto de produto. Este arquivo foca em **como** implementar.

> **Docs de referência do DMS** (busque quando precisar):
> - Plugin System: `https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/README.md`
> - PopoutService: `https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/POPOUT_SERVICE.md`
> - Theme Reference: `https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/THEME_REFERENCE.md`

---

## Stack

| Concern | Solução |
|---|---|
| Linguagem | QML (Quickshell / Qt 6) |
| Widget wrapper | `PluginComponent` (injetado pelo DMS) |
| Settings wrapper | `PluginSettings` (injetado pelo DMS) |
| HTTP | `Proc.runCommand` com `curl` |
| Persistência (preferências) | `pluginService.savePluginData` / `loadPluginData` |
| Persistência (cache) | `pluginService.savePluginData` com JSON.stringify |
| Timers | `Timer` (componente Qt) |
| Ícones | `DankIcon` com Material Symbols |
| Textos | `StyledText` |
| Cores / espaçamentos | `Theme.*` — nunca hardcoded |
| Notificações | `ToastService.showInfo` / `ToastService.showError` |
| Gráficos | `Canvas` QML |
| Clipboard | `Quickshell.execDetached(["dms", "cl", "copy", text])` |

---

## Estrutura de arquivos

```
dms-wakatime/
├── plugin.json
├── WakaTime.qml              # Root: PluginComponent, pill, popout shell, 4 tabs
├── WakaTimeSettings.qml      # PluginSettings com todos os campos de config
├── components/
│   ├── WakaHeader.qml        # Header do popout: tempo total + barra de meta + badge
│   ├── WakaTabToday.qml      # Aba "Hoje"
│   ├── WakaTabWeek.qml       # Aba "Semana"
│   ├── WakaTabProjects.qml   # Aba "Projetos"
│   ├── WakaTabStats.qml      # Aba "Stats"
│   ├── BarChart.qml          # Gráfico de barras verticais reutilizável
│   ├── HorizontalBar.qml     # Barra horizontal: label + barra + valor + percentual
│   └── PieChart.qml          # Pie chart reutilizável
└── utils/
    └── WakaAPI.qml           # Fetch, timers, parsing .cfg, lógica de cache
```

---

## plugin.json

```json
{
  "$schema": "https://raw.githubusercontent.com/AvengeMedia/DankMaterialShell/refs/heads/master/quickshell/PLUGINS/plugin-schema.json",
  "id": "wakaTime",
  "name": "WakaTime",
  "description": "Monitor your coding time. Supports WakaTime, Wakapi and Hakatime.",
  "version": "0.1.0",
  "author": "felipeadeildo",
  "icon": "monitoring",
  "type": "widget",
  "component": "./WakaTime.qml",
  "settings": "./WakaTimeSettings.qml",
  "permissions": ["settings_read", "settings_write"],
  "requires_dms": ">=1.2.0",
  "requires": ["curl"],
  "capabilities": ["wakatime"]
}
```

---

## WakaAPI.qml — módulo central

`utils/WakaAPI.qml` é um `QtObject` (ou `Item`) instanciado dentro de `WakaTime.qml`.
Responsável por:
1. Ler `~/.wakatime.cfg`
2. Fazer todos os fetches com `Proc.runCommand`
3. Gerenciar todos os `Timer`s
4. Emitir sinais quando dados novos chegam
5. Salvar/carregar cache via `pluginService`

### Propriedades expostas

```qml
// Injetadas pelo WakaTime.qml:
property var pluginService: null
property string pluginId: "wakaTime"

// Estado da API:
property string apiKey: ""
property string apiUrl: "https://wakatime.com/api/v1"
property bool isConfigured: apiKey !== ""
property bool hasError: false
property string errorMessage: ""
property var lastSuccessTime: null  // Date object

// Dados do pill (status_bar/today):
property string totalTimeToday: "--"     // "5h 23m"
property int totalSecondsToday: 0
property string currentProject: ""
property string currentLanguage: ""
property string currentEditor: ""

// Dados detalhados (summaries):
property var todayData: null    // parsed JSON de summaries?range=today
property var weekData: null     // parsed JSON de summaries?range=last_7_days
property var monthData: null    // parsed JSON de summaries?range=last_30_days
```

### Sinais

```qml
signal pillDataUpdated()
signal todayDataUpdated()
signal weekDataUpdated()
signal monthDataUpdated()
signal configLoaded()
signal connectionTestResult(bool success, string message)
```

### Leitura do ~/.wakatime.cfg

```qml
function loadConfig() {
    Proc.runCommand(
        "wakaTime.readCfg",
        ["cat", Qt.resolvedUrl("~/.wakatime.cfg").replace("file://", "")],
        (stdout, exitCode) => {
            if (exitCode !== 0) return
            // Parse INI: procura linhas "api_key = ..." e "api_url = ..."
            const lines = stdout.split("\n")
            for (const line of lines) {
                const kv = line.split("=")
                if (kv.length < 2) continue
                const key = kv[0].trim()
                const val = kv.slice(1).join("=").trim()
                if (key === "api_key" && !apiKey) apiKey = val
                if (key === "api_url" && !apiUrl) apiUrl = val
            }
            configLoaded()
        }
    )
}
```

> **Nota**: API key vinda de `pluginService.loadPluginData("wakaTime", "apiKey", "")` tem prioridade sobre o arquivo.

### Auth header

```qml
function authHeader() {
    return "Basic " + Qt.btoa(apiKey + ":")
}
```

### Fetch genérico

```qml
function fetchEndpoint(id, path, callback) {
    const url = (apiUrl || "https://wakatime.com/api/v1") + path
    Proc.runCommand(
        "wakaTime." + id,
        ["curl", "-s", "--max-time", "15", "-H", "Authorization: " + authHeader(), url],
        (stdout, exitCode) => {
            if (exitCode !== 0) {
                hasError = true
                return
            }
            try {
                const parsed = JSON.parse(stdout)
                if (parsed.error) {
                    hasError = true
                    errorMessage = parsed.error
                    return
                }
                hasError = false
                callback(parsed)
            } catch(e) {
                hasError = true
                errorMessage = "Parse error"
            }
        }
    )
}
```

### Timers

```qml
// Em WakaAPI.qml:

Timer {
    id: pillTimer
    interval: pillIntervalMs   // carregado do pluginData, default 5min
    repeat: true
    triggeredOnStart: true
    onTriggered: fetchPill()
}

Timer {
    id: todayStartDelay
    interval: 10000
    repeat: false
    onTriggered: {
        fetchToday()
        todayTimer.start()
    }
}
Timer {
    id: todayTimer
    interval: todayIntervalMs  // default 15min
    repeat: true
    onTriggered: fetchToday()
}

// Mesmo padrão para weekTimer e monthTimer com delay de 10s
```

### Cache

Ao salvar:
```qml
pluginService.savePluginData(pluginId, "cachePill", JSON.stringify({
    totalTime: totalTimeToday,
    totalSeconds: totalSecondsToday,
    project: currentProject,
    language: currentLanguage,
    editor: currentEditor,
    savedAt: new Date().toISOString()
}))
```

Ao carregar (no `Component.onCompleted`):
```qml
const raw = pluginService.loadPluginData(pluginId, "cachePill", "")
if (raw) {
    try {
        const cached = JSON.parse(raw)
        totalTimeToday = cached.totalTime || "--"
        // ... resto dos campos
    } catch(e) {}
}
```

---

## WakaTime.qml — root component

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Injetado pelo DMS:
    property var pluginService: null
    property var popoutService: null

    // Instância do módulo de API:
    WakaAPI {
        id: api
        pluginService: root.pluginService
    }

    // === BAR PILL (horizontal) ===
    horizontalBarPill: Component {
        StyledRect {
            width: pillRow.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "keyboard"
                    color: iconColor()    // função que retorna cor baseada no progresso
                    font.pixelSize: Theme.iconSize
                }

                StyledText {
                    text: api.totalTimeToday
                    color: Theme.onSurface
                    font.pixelSize: Theme.fontSizeMedium
                }

                // Separador e campo configurável (se não for "none"):
                StyledText {
                    visible: pillExtraText !== ""
                    text: "•"
                    color: Theme.onSurfaceVariant
                }
                StyledText {
                    text: pillExtraText   // projeto, linguagem, editor, ou ""
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
        }
    }

    // === POPOUT ===
    popoutWidth: 480
    popoutHeight: 600

    popoutContent: Component {
        PopoutComponent {
            showCloseButton: true

            Column {
                width: parent.width
                spacing: 0

                WakaHeader { api: root.api; /* ... */ }

                // Tab bar
                Row { /* Hoje · Semana · Projetos · Stats */ }

                // Tab content (StackLayout ou Loader baseado em currentTab)
                Loader {
                    source: tabSources[currentTab]
                }
            }
        }
    }
}
```

### Função de cor do ícone

```qml
function iconColor() {
    if (!api.isConfigured || api.totalSecondsToday === 0) return Theme.onSurfaceVariant
    const goal = pluginService.loadPluginData("wakaTime", "dailyGoalHours", 4) * 3600
    const ratio = api.totalSecondsToday / goal
    if (ratio >= 0.9) return Theme.success      // verde
    if (ratio >= 0.5) return Theme.warning      // amarelo
    return Theme.error                           // vermelho
}
```

---

## WakaHeader.qml

Recebe `api` como propriedade e exibe:

```qml
Column {
    // Tempo total + badge self-hosted
    Row {
        StyledText { text: api.totalTimeToday; font.pixelSize: Theme.fontSizeXLarge }
        // Badge condicional:
        Rectangle {
            visible: api.apiUrl && !api.apiUrl.includes("wakatime.com")
            // Texto: "Wakapi" ou "Hakatime"
        }
    }

    // Barra de progresso da meta
    Rectangle {
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surfaceContainerHighest

        Rectangle {
            width: Math.min(parent.width * progressRatio, parent.width)
            height: parent.height
            radius: parent.radius
            color: progressColor()
        }
    }

    // Texto "Xh Ym / meta Zh"
    StyledText { text: api.totalTimeToday + " / meta " + goalText }

    // Banner de dados desatualizados (condicional)
    Rectangle {
        visible: api.hasError && api.totalSecondsToday > 0
        // "Dados desatualizados · última atualização há Xmin"
    }
}
```

---

## WakaTabToday.qml

Seções (em `Column`):

### 1. Card "Agora"
```qml
StyledRect {
    // Visível se api.currentProject !== ""
    Column {
        StyledText { text: api.currentProject; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold }
        Row {
            // Badges: currentLanguage, currentEditor
        }
        StyledText { text: "último heartbeat há " + minutesAgo + " minutos"; color: Theme.onSurfaceVariant }
    }
}
```

### 2. Gráfico de atividade por hora (BarChart.qml)
```qml
BarChart {
    width: parent.width
    height: 80
    // data: array de 24 valores (minutos por hora) extraído de api.todayData
    // labels: ["0", "", "", "3", "", "", "6", ...]
    // highlightMax: true
}
```

### 3. Top 5 Projetos e Top 5 Linguagens
```qml
// Para cada item:
HorizontalBar {
    label: project.name
    value: formatDuration(project.total_seconds)
    percentage: project.percent  // só em linguagens
    ratio: project.total_seconds / maxSeconds
}
```

---

## WakaTabWeek.qml

### Gráfico de 7 dias (BarChart.qml)
```qml
BarChart {
    data: weekData.map(d => d.grand_total.total_seconds)
    labels: weekData.map(d => shortDayName(d.range.date))
    highlightIndex: selectedDayIndex   // -1 = nenhum selecionado
    onBarClicked: (index) => selectedDayIndex = index
}
```

### Resumo
Extraído de `api.weekData`:
- `grand_total` de todos os dias somados
- Média = total / 7
- Dia mais produtivo = max(dias)
- Comparação com semana anterior: requer dados do `last_14_days` (busca junto com `last_7_days`)

### Breakdown
- Se `selectedDayIndex >= 0`: usa dados do dia específico de `weekData[selectedDayIndex]`
- Senão: agrega todos os 7 dias

---

## WakaTabProjects.qml

### Seletor de período
```qml
property string selectedPeriod: "7d"  // "today" | "7d" | "30d" | "6m"

Row {
    Repeater {
        model: [{label: "Hoje", value: "today"}, ...]
        // Chip clicável, selecionado = fundo primário
    }
}
```

### Dados por período
```qml
function currentData() {
    switch(selectedPeriod) {
        case "today": return api.todayData
        case "7d":    return api.weekData
        case "30d":   return api.monthData
        case "6m":    // precisaria de endpoint extra, usar monthData como fallback
    }
}
```

### Lista de projetos com expand
```qml
property int expandedIndex: -1

Repeater {
    model: projectsList(currentData())
    delegate: Column {
        // Linha do projeto
        StyledRect {
            onClicked: expandedIndex = (expandedIndex === index ? -1 : index)
            Row {
                StyledText { text: modelData.name }
                HorizontalBar { ratio: modelData.percent / 100 }
                StyledText { text: formatDuration(modelData.total_seconds) }
                // Badge da linguagem dominante
                StyledText { text: relativeTime(modelData.last_heartbeat_at) }
            }
        }

        // Expand inline
        Column {
            visible: expandedIndex === index
            // Linguagens do projeto + gráfico por dia + editor dominante
        }
    }
}
```

---

## WakaTabStats.qml

### Streaks
> A API do WakaTime tem endpoint `/users/current/stats/last_30_days` que inclui `best_day` e dados de streak implícitos via sequência de `daily_average`.
> Para streak real, calcular a partir dos dados de `summaries` dos últimos 30 dias: contar sequência de dias consecutivos com `total_seconds > 0`.

```qml
property int currentStreak: calculateStreak(api.monthData)
property int bestStreak: 0  // salvo no pluginData, atualizado se currentStreak > bestStreak
```

### Pie charts (PieChart.qml)
```qml
PieChart {
    width: 80
    height: 80
    // segments: array de {label, value, color}
    // colors gerados dinamicamente ou mapeados por linguagem
}
```

### Padrões de produtividade
Calculados a partir de `monthData`:
- **Dia mais produtivo**: agregar por dia da semana, pegar média, encontrar máximo
- **Horário de pico**: agregar minutos por hora em todos os dias, encontrar janela de 3h com maior soma

---

## BarChart.qml — especificação

```qml
Item {
    property var data: []          // array de números
    property var labels: []        // array de strings (mesmo tamanho que data)
    property int highlightIndex: -1  // índice destacado (-1 = maior valor)
    property bool highlightMax: false
    property color barColor: Theme.primary
    property color barColorDim: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.15)
    property color labelColor: Theme.onSurfaceVariant

    signal barClicked(int index)

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const max = Math.max(...data, 1)
            const barW = width / data.length
            const labelH = 16
            const chartH = height - labelH - 4

            data.forEach((val, i) => {
                const isHighlight = highlightMax ? val === max : i === highlightIndex
                const ratio = val / max
                const bh = ratio * chartH
                const x = i * barW + barW * 0.1
                const w = barW * 0.8

                ctx.fillStyle = isHighlight ? barColor : barColorDim
                ctx.roundRect(x, chartH - bh, w, bh, 2)
                ctx.fill()

                if (labels[i]) {
                    ctx.fillStyle = labelColor
                    ctx.font = "10px sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText(labels[i], x + w/2, height)
                }
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: (mouse) => {
            const i = Math.floor(mouse.x / (width / data.length))
            if (i >= 0 && i < data.length) barClicked(i)
        }
    }

    // Redraw quando dados mudam:
    onDataChanged: canvas.requestPaint()
}
```

---

## HorizontalBar.qml — especificação

```qml
Item {
    property string label: ""
    property string value: ""
    property real ratio: 0.0      // 0.0 a 1.0
    property string percentage: "" // ex: "67%" — se vazio, não exibe

    implicitHeight: 28

    Row {
        anchors.fill: parent
        spacing: Theme.spacingS

        StyledText {
            width: 120
            text: label
            elide: Text.ElideRight
            color: Theme.onSurface
            font.pixelSize: Theme.fontSizeMedium
        }

        Rectangle {
            width: parent.width - 120 - valueText.width - (percentText.visible ? percentText.width : 0) - Theme.spacingS * 3
            height: 6
            anchors.verticalCenter: parent.verticalCenter
            radius: 3
            color: Theme.surfaceContainerHighest

            Rectangle {
                width: parent.width * ratio
                height: parent.height
                radius: parent.radius
                color: Theme.primary
            }
        }

        StyledText {
            id: valueText
            text: value
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
        }

        StyledText {
            id: percentText
            visible: percentage !== ""
            text: percentage
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
```

---

## PieChart.qml — especificação

```qml
Item {
    property var segments: []  // [{label, value, color}]

    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2, cy = height / 2
            const r = Math.min(cx, cy) - 4
            const total = segments.reduce((s, seg) => s + seg.value, 0)
            let startAngle = -Math.PI / 2

            segments.forEach(seg => {
                const angle = (seg.value / total) * Math.PI * 2
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, r, startAngle, startAngle + angle)
                ctx.closePath()
                ctx.fillStyle = seg.color
                ctx.fill()
                startAngle += angle
            })

            // Donut hole:
            ctx.beginPath()
            ctx.arc(cx, cy, r * 0.55, 0, Math.PI * 2)
            ctx.fillStyle = surfaceColor  // property passada de fora
            ctx.fill()
        }
    }

    onSegmentsChanged: canvas.requestPaint()
}
```

> Passe `surfaceColor: Theme.surfaceContainerHigh` como propriedade para o buraco do donut combinar com o container pai.

---

## WakaTimeSettings.qml

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "wakaTime"

    // === API ===
    StyledText { text: "API"; font.weight: Font.Bold }

    StringSetting {
        settingKey: "apiKey"
        label: "API Key"
        description: "Detectada automaticamente de ~/.wakatime.cfg se vazio"
        placeholder: "waka_..."
        defaultValue: ""
    }

    StringSetting {
        settingKey: "apiUrl"
        label: "API URL"
        description: "Para Wakapi ou Hakatime. Deixe vazio para usar wakatime.com"
        placeholder: "https://wakatime.com/api/v1"
        defaultValue: ""
    }

    // Botão "Testar conexão" — Item customizado dentro do PluginSettings
    Item {
        width: parent.width
        height: 40

        Rectangle {
            width: 140; height: 36
            radius: Theme.cornerRadius
            color: testArea.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary

            StyledText { anchors.centerIn: parent; text: "Testar conexão"; color: Theme.onPrimary }

            MouseArea {
                id: testArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Dispara fetch de /users/current e emite toast com resultado
                    api.testConnection()
                }
            }
        }
    }

    // === Meta diária ===
    StyledText { text: "Meta diária"; font.weight: Font.Bold }

    // Slider para horas (implementado como Item customizado + pluginService direto)
    // ou usar SelectionSetting com opções de 1h a 12h em steps de 0.5h

    SelectionSetting {
        settingKey: "dailyGoalHours"
        label: "Horas por dia"
        options: [
            {label: "1h", value: "1"}, {label: "1.5h", value: "1.5"},
            {label: "2h", value: "2"}, {label: "2.5h", value: "2.5"},
            {label: "3h", value: "3"}, {label: "4h", value: "4"},
            {label: "5h", value: "5"}, {label: "6h", value: "6"},
            {label: "8h", value: "8"}, {label: "10h", value: "10"},
            {label: "12h", value: "12"}
        ]
        defaultValue: "4"
    }

    // === Bar Pill ===
    StyledText { text: "Bar Pill"; font.weight: Font.Bold }

    SelectionSetting {
        settingKey: "pillDisplayField"
        label: "Mostrar ao lado do tempo"
        options: [
            {label: "Projeto", value: "project"},
            {label: "Linguagem", value: "language"},
            {label: "Editor", value: "editor"},
            {label: "Nada", value: "none"}
        ]
        defaultValue: "project"
    }

    ToggleSetting {
        settingKey: "showGoalColor"
        label: "Indicador de cor da meta"
        description: "Cor do ícone reflete progresso da meta diária"
        defaultValue: true
    }

    // === Intervalos ===
    StyledText { text: "Intervalos de atualização"; font.weight: Font.Bold }

    SelectionSetting {
        settingKey: "pillIntervalMin"
        label: "Pill (status atual)"
        options: [1,2,3,5,10].map(v => ({label: v + " min", value: String(v)}))
        defaultValue: "5"
    }

    SelectionSetting {
        settingKey: "todayIntervalMin"
        label: "Dados do dia"
        options: [5,10,15,20,30].map(v => ({label: v + " min", value: String(v)}))
        defaultValue: "15"
    }

    SelectionSetting {
        settingKey: "weekIntervalMin"
        label: "Dados da semana"
        options: [15,20,30,45,60].map(v => ({label: v + " min", value: String(v)}))
        defaultValue: "30"
    }
}
```

---

## Parsing da resposta da API

### status_bar/today → pill

```javascript
// response.data:
{
    grand_total: { text: "5 hrs 23 mins", total_seconds: 19380 },
    projects: [{ name: "ranqia", ... }],
    languages: [{ name: "TypeScript", ... }],
    editors: [{ name: "Zed", ... }]
}

// Extrair:
totalTimeToday = data.grand_total.text          // "5 hrs 23 mins"
totalSecondsToday = data.grand_total.total_seconds
currentProject = data.projects[0]?.name || ""
currentLanguage = data.languages[0]?.name || ""
currentEditor = data.editors[0]?.name || ""
```

### summaries → abas

```javascript
// response.data: array de objetos por dia
// Cada objeto:
{
    range: { date: "2026-03-14" },
    grand_total: { total_seconds: 19380 },
    projects: [{ name, total_seconds, percent }],
    languages: [{ name, total_seconds, percent }],
    editors: [{ name, total_seconds, percent }],
    // Para "today" inclui também:
    categories: [...],
    // Atividade por hora (apenas em summaries de hoje):
    // NÃO disponível diretamente — requer endpoint /durations
}
```

> **Nota importante**: O endpoint `summaries` não retorna atividade por hora diretamente.
> Para o gráfico de horas na aba Hoje, usar:
> `GET /users/current/durations?date=YYYY-MM-DD`
> Retorna array de `{project, time, duration}` onde `time` é timestamp Unix.
> Agrupar por hora: `Math.floor((time % 86400) / 3600)`.

---

## Detecção de self-hosted

```javascript
function detectServiceType(url) {
    if (!url || url.includes("wakatime.com")) return "wakatime"
    if (url.toLowerCase().includes("hakatime")) return "hakatime"
    return "wakapi"
}
```

---

## Formatação de duração

```javascript
function formatDuration(seconds) {
    if (seconds < 60) return seconds + "s"
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    if (h === 0) return m + "m"
    if (m === 0) return h + "h"
    return h + "h " + m + "m"
}
```

## Tempo relativo

```javascript
function relativeTime(isoString) {
    const diff = (Date.now() - new Date(isoString).getTime()) / 1000
    if (diff < 60) return "agora"
    if (diff < 3600) return Math.floor(diff / 60) + " min atrás"
    if (diff < 86400) return Math.floor(diff / 3600) + "h atrás"
    return Math.floor(diff / 86400) + "d atrás"
}
```

---

## Checklist de implementação

### Fase 1 — Core
- [ ] `utils/WakaAPI.qml`: leitura do .cfg, auth, fetch genérico, timers, cache
- [ ] `WakaTime.qml`: pill horizontal básico com dados reais
- [ ] `WakaTimeSettings.qml`: campos de API + botão de teste

### Fase 2 — Aba Hoje
- [ ] `components/BarChart.qml`
- [ ] `components/HorizontalBar.qml`
- [ ] `components/WakaHeader.qml`
- [ ] `components/WakaTabToday.qml`
- [ ] Endpoint `/durations` para gráfico por hora

### Fase 3 — Aba Semana
- [ ] `components/WakaTabWeek.qml`
- [ ] Lógica de comparação com semana anterior

### Fase 4 — Aba Projetos
- [ ] `components/WakaTabProjects.qml`
- [ ] Expand inline de projeto
- [ ] Seletor de período

### Fase 5 — Aba Stats
- [ ] `components/PieChart.qml`
- [ ] `components/WakaTabStats.qml`
- [ ] Cálculo de streak
- [ ] Padrões de produtividade (dia da semana + horário de pico)

### Fase 6 — Polish
- [ ] Pill vertical (barra vertical)
- [ ] Estado onboarding (sem config)
- [ ] Estado de erro com dados stale
- [ ] Estado sem atividade hoje
- [ ] Animações de transição entre abas
