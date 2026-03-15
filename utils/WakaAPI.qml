// Central API module. Owns all network requests, timers, config reading,
// and cache persistence. Exposes only properties and signals to consumers.
// Base type is Item (not QtObject) so Timer children are supported.

import QtQuick
import qs.Common

Item {
    id: root
    visible: false

    // Injected by parent
    property var pluginService: null
    readonly property string pluginId: "wakaTime"

    // API config
    property string apiKey: ""
    property string apiUrl: "https://wakatime.com/api/v1"

    readonly property bool isConfigured: apiKey !== ""

    // Error state
    property bool hasError: false
    property string errorMessage: ""
    property var lastSuccessTime: null

    // Pill data (from /status_bar/today)
    property string totalTimeToday: "--"
    property int totalSecondsToday: 0
    property string currentProject: ""
    property string currentLanguage: ""
    property string currentEditor: ""

    // Detailed data (from /summaries)
    property var todayData: null
    property var weekData: null
    property var monthData: null

    // Signals
    signal pillDataUpdated
    signal todayDataUpdated
    signal weekDataUpdated
    signal monthDataUpdated
    signal configLoaded
    signal connectionTestResult(bool success, string message)

    // Timer intervals (resolved once at startup from pluginService)
    readonly property int pillIntervalMs: (pluginService ? parseInt(pluginService.loadPluginData(pluginId, "pillIntervalMin", "5")) : 5) * 60000
    readonly property int todayIntervalMs: (pluginService ? parseInt(pluginService.loadPluginData(pluginId, "todayIntervalMin", "15")) : 15) * 60000
    readonly property int weekIntervalMs: (pluginService ? parseInt(pluginService.loadPluginData(pluginId, "weekIntervalMin", "30")) : 30) * 60000
    readonly property int monthIntervalMs: 60 * 60000

    // Timers

    Timer {
        id: pillTimer
        interval: root.pillIntervalMs
        repeat: true
        triggeredOnStart: false   // started explicitly in onConfigLoaded
        onTriggered: root.fetchPill()
    }

    Timer {
        id: todayStartDelay
        interval: 10000
        repeat: false
        onTriggered: {
            root.fetchToday();
            todayTimer.start();
        }
    }
    Timer {
        id: todayTimer
        interval: root.todayIntervalMs
        repeat: true
        onTriggered: root.fetchToday()
    }

    Timer {
        id: weekStartDelay
        interval: 10000
        repeat: false
        onTriggered: {
            root.fetchWeek();
            weekTimer.start();
        }
    }
    Timer {
        id: weekTimer
        interval: root.weekIntervalMs
        repeat: true
        onTriggered: root.fetchWeek()
    }

    Timer {
        id: monthStartDelay
        interval: 10000
        repeat: false
        onTriggered: {
            root.fetchMonth();
            monthTimer.start();
        }
    }
    Timer {
        id: monthTimer
        interval: root.monthIntervalMs
        repeat: true
        onTriggered: root.fetchMonth()
    }

    // Lifecycle
    Component.onCompleted: {
        _loadCache();
        loadConfig();
    }

    onConfigLoaded: {
        if (!isConfigured)
            return;
        fetchPill();
        pillTimer.start();
        todayStartDelay.start();
        weekStartDelay.start();
        monthStartDelay.start();
    }

    // Config loading
    function loadConfig() {
        // Saved API key takes priority over .wakatime.cfg
        if (pluginService) {
            const savedKey = pluginService.loadPluginData(pluginId, "apiKey", "");
            const savedUrl = pluginService.loadPluginData(pluginId, "apiUrl", "");
            if (savedKey)
                apiKey = savedKey;
            if (savedUrl)
                apiUrl = savedUrl;
        }

        // Fall back to ~/.wakatime.cfg for api_key / api_url
        Proc.runCommand("wakaTime.readCfg", ["sh", "-c", "cat ~/.wakatime.cfg"], (stdout, exitCode) => {
            if (exitCode === 0) {
                const lines = stdout.split("\n");
                for (const line of lines) {
                    const eqIdx = line.indexOf("=");
                    if (eqIdx < 0)
                        continue;
                    const key = line.slice(0, eqIdx).trim();
                    const val = line.slice(eqIdx + 1).trim();
                    if (key === "api_key" && !apiKey)
                        apiKey = val;
                    if (key === "api_url" && !apiUrl)
                        apiUrl = val;
                }
            }
            configLoaded();
        });
    }

    // Auth
    function _authHeader() {
        return "Basic " + Qt.btoa(apiKey + ":");
    }

    // Generic fetch
    function _fetchEndpoint(id, path, onSuccess, onError) {
        const url = apiUrl + path;
        Proc.runCommand("wakaTime." + id, ["curl", "-s", "--max-time", "15", "-H", "Authorization: " + _authHeader(), url], (stdout, exitCode) => {
            if (exitCode !== 0) {
                hasError = true;
                errorMessage = "Network error (exit " + exitCode + ")";
                if (onError)
                    onError(errorMessage);
                return;
            }
            let parsed;
            try {
                parsed = JSON.parse(stdout);
            } catch (e) {
                hasError = true;
                errorMessage = "Parse error";
                if (onError)
                    onError(errorMessage);
                return;
            }
            if (parsed.error) {
                hasError = true;
                errorMessage = parsed.error;
                if (onError)
                    onError(errorMessage);
                return;
            }
            hasError = false;
            lastSuccessTime = new Date();
            onSuccess(parsed);
        });
    }

    // Public fetch functions
    function fetchPill() {
        if (!isConfigured)
            return;
        _fetchEndpoint("fetchPill", "/users/current/status_bar/today", parsed => {
            const d = parsed.data;
            totalTimeToday = d.grand_total.text || "0m";
            totalSecondsToday = d.grand_total.total_seconds;
            currentProject = (d.projects && d.projects[0]) ? d.projects[0].name : "";
            currentLanguage = (d.languages && d.languages[0]) ? d.languages[0].name : "";
            currentEditor = (d.editors && d.editors[0]) ? d.editors[0].name : "";
            _savePillCache();
            pillDataUpdated();
        }, null);
    }

    function fetchToday() {
        if (!isConfigured)
            return;
        _fetchEndpoint("fetchToday", "/users/current/summaries?range=today", parsed => {
            todayData = parsed.data;
            _saveSummaryCache("cacheToday", parsed.data);
            todayDataUpdated();
        }, null);
    }

    function fetchWeek() {
        if (!isConfigured)
            return;
        _fetchEndpoint("fetchWeek", "/users/current/summaries?range=last_7_days", parsed => {
            weekData = parsed.data;
            _saveSummaryCache("cacheWeek", parsed.data);
            weekDataUpdated();
        }, null);
    }

    function fetchMonth() {
        if (!isConfigured)
            return;
        _fetchEndpoint("fetchMonth", "/users/current/summaries?range=last_30_days", parsed => {
            monthData = parsed.data;
            _saveSummaryCache("cacheMonth", parsed.data);
            monthDataUpdated();
        }, null);
    }

    function testConnection() {
        if (!isConfigured) {
            connectionTestResult(false, "No API key configured");
            return;
        }
        _fetchEndpoint("testConnection", "/users/current", parsed => {
            const name = parsed.data ? (parsed.data.username || parsed.data.email || "user") : "user";
            connectionTestResult(true, name);
        }, errMsg => {
            connectionTestResult(false, errMsg);
        });
    }

    // Cache persistence
    function _savePillCache() {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "cachePill", JSON.stringify({
            totalTime: totalTimeToday,
            totalSeconds: totalSecondsToday,
            project: currentProject,
            language: currentLanguage,
            editor: currentEditor,
            savedAt: new Date().toISOString()
        }));
    }

    function _saveSummaryCache(key, data) {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, key, JSON.stringify(data));
    }

    function _loadCache() {
        if (!pluginService)
            return;
        const pill = pluginService.loadPluginData(pluginId, "cachePill", "");
        if (pill) {
            try {
                const c = JSON.parse(pill);
                totalTimeToday = c.totalTime || "--";
                totalSecondsToday = c.totalSeconds || 0;
                currentProject = c.project || "";
                currentLanguage = c.language || "";
                currentEditor = c.editor || "";
            } catch (e) {}
        }

        const today = pluginService.loadPluginData(pluginId, "cacheToday", "");
        if (today) {
            try {
                todayData = JSON.parse(today);
            } catch (e) {}
        }

        const week = pluginService.loadPluginData(pluginId, "cacheWeek", "");
        if (week) {
            try {
                weekData = JSON.parse(week);
            } catch (e) {}
        }

        const month = pluginService.loadPluginData(pluginId, "cacheMonth", "");
        if (month) {
            try {
                monthData = JSON.parse(month);
            } catch (e) {}
        }
    }
}
