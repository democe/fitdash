import QtQuick
import Quickshell
import Quickshell.Io

// Persistent config backed by ~/.config/fitdash/config.json.
// Read on startup via fitdash-config.py; written on save().
QtObject {
    id: config

    property string accessToken: ""
    property string refreshToken: ""
    property string clientId: ""
    property string userId: ""
    property int    refreshInterval: 15
    property int    tokenExpiry: 0
    property string distanceUnit: "km"
    property bool   showSteps: true
    property bool   showCalories: true
    property bool   showDistance: true
    property bool   showActiveMinutes: true
    property bool   showHeartRate: true
    property int    callbackPort: 19847
    property string lastRequestStatus: ""
    property string lastRequestState: "unknown"

    readonly property string configPath: Quickshell.env("HOME") + "/.config/fitdash/config.json"
    readonly property string scriptDir:  Qt.resolvedUrl("scripts/").toString().replace("file://", "")

    // ── Internal helpers ────────────────────────────────────────────────────

    function _apply(data) {
        accessToken       = data.accessToken       || ""
        refreshToken      = data.refreshToken      || ""
        clientId          = data.clientId          || ""
        userId            = data.userId            || ""
        refreshInterval   = data.refreshInterval   || 15
        tokenExpiry       = data.tokenExpiry       || 0
        distanceUnit      = data.distanceUnit      || "km"
        showSteps         = data.showSteps         !== undefined ? data.showSteps         : true
        showCalories      = data.showCalories      !== undefined ? data.showCalories      : true
        showDistance      = data.showDistance      !== undefined ? data.showDistance      : true
        showActiveMinutes = data.showActiveMinutes !== undefined ? data.showActiveMinutes : true
        showHeartRate     = data.showHeartRate     !== undefined ? data.showHeartRate     : true
        callbackPort      = data.callbackPort      || 19847
        lastRequestStatus = data.lastRequestStatus || ""
        lastRequestState  = data.lastRequestState  || "unknown"
    }

    function _toObject() {
        return {
            accessToken:       accessToken,
            refreshToken:      refreshToken,
            clientId:          clientId,
            userId:            userId,
            refreshInterval:   refreshInterval,
            tokenExpiry:       tokenExpiry,
            distanceUnit:      distanceUnit,
            showSteps:         showSteps,
            showCalories:      showCalories,
            showDistance:      showDistance,
            showActiveMinutes: showActiveMinutes,
            showHeartRate:     showHeartRate,
            callbackPort:      callbackPort,
            lastRequestStatus: lastRequestStatus,
            lastRequestState:  lastRequestState
        }
    }

    // ── Read on startup ──────────────────────────────────────────────────────

    Process {
        id: readProc
        property string buf: ""
        command: ["python3", config.scriptDir + "fitdash-config.py", "read"]
        running: true

        stdout: SplitParser {
            onRead: data => readProc.buf += data + "\n"
        }

        onRunningChanged: {
            if (running) return
            var text = buf.trim()
            buf = ""
            if (!text || text === "{}") return
            try {
                config._apply(JSON.parse(text))
            } catch(e) {
                console.warn("FitDash Config: parse error:", e)
            }
        }
    }

    // ── Write on save() ──────────────────────────────────────────────────────

    Process {
        id: writeProc
        property string data: ""
        command: ["python3", config.scriptDir + "fitdash-config.py", "write", data]
        running: false
    }

    function save() {
        if (writeProc.running) return   // skip; next save will capture latest state
        writeProc.data = JSON.stringify(_toObject(), null, 2)
        writeProc.running = true
    }
}
