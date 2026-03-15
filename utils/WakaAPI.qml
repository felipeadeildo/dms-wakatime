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
    property bool isOwner: true   // set to false on non-owner instances
    readonly property string pluginId: "wakaTime"

    // API config
    property string apiKey: ""
    property string apiUrl: "https://api.wakatime.com/api/v1"

    readonly property bool isConfigured: apiKey !== ""

    // Error state
    property bool hasError: false
    property string errorMessage: ""
    property var lastSuccessTime: null

    // Pill data
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

    // Timer intervals
    property int pillIntervalMs: 5 * 60000
    property int todayIntervalMs: 15 * 60000
    property int weekIntervalMs: 30 * 60000
    readonly property int monthIntervalMs: 60 * 60000

    // Timers

    Timer {
        id: pillTimer
        interval: root.pillIntervalMs
        repeat: true
        triggeredOnStart: false
        onTriggered: root.fetchPill()
    }

    Timer {
        id: todayStartDelay
        interval: 10000
        repeat: false
        onTriggered: {
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

    onPluginServiceChanged: {
        if (!pluginService)
            return;
        pillIntervalMs = parseInt(pluginService.loadPluginData(pluginId, "pillIntervalMin", "5")) * 60000;
        todayIntervalMs = parseInt(pluginService.loadPluginData(pluginId, "todayIntervalMin", "15")) * 60000;
        weekIntervalMs = parseInt(pluginService.loadPluginData(pluginId, "weekIntervalMin", "30")) * 60000;
    }

    onConfigLoaded: {
        _startFetching();
    }

    onIsOwnerChanged: {
        if (isOwner && isConfigured && !pillTimer.running)
            _startFetching();
    }

    function _startFetching() {
        if (!isConfigured || !isOwner)
            return;
        fetchPill();
        pillTimer.start();
        todayStartDelay.start();
        weekStartDelay.start();
        monthStartDelay.start();
    }

    // Config loading
    function loadConfig() {
        if (pluginService) {
            const savedKey = pluginService.loadPluginData(pluginId, "apiKey", "");
            const savedUrl = pluginService.loadPluginData(pluginId, "apiUrl", "");
            if (savedKey)
                apiKey = savedKey;
            if (savedUrl)
                apiUrl = savedUrl;
        }

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
        _fetchEndpoint("fetchPill", "/users/current/summaries?range=today", parsed => {
            const cumulative = parsed.cumulative_total;
            const day = parsed.data && parsed.data[0];
            totalTimeToday = (cumulative && cumulative.text) ? cumulative.text : (day ? (day.grand_total.text || "0m") : "0m");
            totalSecondsToday = cumulative ? cumulative.seconds : (day ? day.grand_total.total_seconds : 0);
            currentProject = (day && day.projects && day.projects[0]) ? day.projects[0].name : "";
            currentLanguage = (day && day.languages && day.languages[0]) ? day.languages[0].name : "";
            currentEditor = (day && day.editors && day.editors[0]) ? day.editors[0].name : "";
            todayData = parsed.data;
            _savePillCache();
            _saveSummaryCache("cacheToday", parsed.data);
            pillDataUpdated();
            todayDataUpdated();
        }, null);
    }

    function fetchToday() {
        _fetchEndpoint("fetchToday", "/users/current/summaries?range=today", parsed => {
            const cumulative = parsed.cumulative_total;
            const day = parsed.data && parsed.data[0];
            totalTimeToday = (cumulative && cumulative.text) ? cumulative.text : (day ? (day.grand_total.text || "0m") : "0m");
            totalSecondsToday = cumulative ? cumulative.seconds : (day ? day.grand_total.total_seconds : 0);
            currentProject = (day && day.projects && day.projects[0]) ? day.projects[0].name : "";
            currentLanguage = (day && day.languages && day.languages[0]) ? day.languages[0].name : "";
            currentEditor = (day && day.editors && day.editors[0]) ? day.editors[0].name : "";
            todayData = parsed.data;
            _savePillCache();
            _saveSummaryCache("cacheToday", parsed.data);
            pillDataUpdated();
            todayDataUpdated();
        }, null);
    }

    function fetchWeek() {
        _fetchEndpoint("fetchWeek", "/users/current/summaries?range=last_7_days", parsed => {
            weekData = parsed.data;
            _saveSummaryCache("cacheWeek", parsed.data);
            weekDataUpdated();
        }, null);
    }

    function fetchMonth() {
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
