import QtQuick

QtObject {
    id: api

    property string accessToken: ""

    // NaN means "no data" so the UI can show an em-dash instead of a fake 0.
    property real steps: NaN
    property real calories: NaN
    property real distance: NaN
    property real activeMinutes: NaN
    property real sleepMinutes: NaN
    // Latest daily summaries, which can be from an earlier day.
    property real restingHeartRate: NaN
    property real oxygenSaturation: NaN
    property real heartRateVariability: NaN
    property real respiratoryRate: NaN
    property string lastUpdated: ""
    property real lastUpdatedTimestamp: 0

    property bool isLoading: false
    property string errorMessage: ""
    property string lastRequestStatus: ""
    property string lastRequestState: "unknown"

    property var pendingXhrs: []
    property int pendingCount: 0
    property bool authErrorSignaled: false
    property bool anySucceeded: false

    // Metrics that describe today and must not carry over past midnight.
    readonly property var todayMetrics: ["steps", "calories", "distance", "activeMinutes", "sleepMinutes"]
    readonly property var latestMetrics: ["restingHeartRate", "oxygenSaturation", "heartRateVariability", "respiratoryRate"]

    signal dataUpdated()
    signal authError()
    signal error(string message)

    readonly property string apiBase: "https://health.googleapis.com/v4/users/me"

    function fetchData() {
        if (!accessToken) {
            api.lastRequestState = "error";
            api.error(i18n("No access token"));
            return;
        }
        if (isLoading) return;
        isLoading = true;
        errorMessage = "";
        authErrorSignaled = false;
        anySucceeded = false;
        if (lastUpdatedTimestamp > 0 && !isToday(lastUpdatedTimestamp)) {
            clearMetrics(todayMetrics);
        }
        pendingXhrs = [];
        pendingCount = 9;
        fetchStepsRollup();
        fetchTotalCaloriesRollup();
        fetchDistanceRollup();
        fetchActiveMinutesRollup();
        fetchRestingHeartRate();
        fetchOxygenSaturation();
        fetchHeartRateVariability();
        fetchRespiratoryRate();
        fetchSleep();
    }

    function isToday(timestamp) {
        return new Date(timestamp).toDateString() === new Date().toDateString();
    }

    function clearMetrics(keys) {
        for (var i = 0; i < keys.length; i++) api[keys[i]] = NaN;
    }

    // Serializable copy of the last known values, persisted by main.qml so the
    // widget can show them after a restart while offline.
    function snapshot() {
        var values = {};
        var keys = todayMetrics.concat(latestMetrics);
        for (var i = 0; i < keys.length; i++) {
            if (!isNaN(api[keys[i]])) values[keys[i]] = api[keys[i]];
        }
        return { timestamp: lastUpdatedTimestamp, values: values };
    }

    function restore(json) {
        var snap;
        try { snap = JSON.parse(json); } catch (e) { return; }
        if (!snap || !snap.timestamp || !snap.values) return;
        var keys = isToday(snap.timestamp) ? todayMetrics.concat(latestMetrics) : latestMetrics;
        for (var i = 0; i < keys.length; i++) {
            var v = snap.values[keys[i]];
            if (typeof v === "number") api[keys[i]] = v;
        }
        lastUpdatedTimestamp = snap.timestamp;
        var when = new Date(snap.timestamp);
        lastUpdated = isToday(snap.timestamp) ? when.toLocaleTimeString() : when.toLocaleString();
    }

    // Civil (local-calendar) date range covering "today" for a dailyRollUp request.
    function todayRange() {
        var d = new Date();
        var y = d.getFullYear();
        var m = d.getMonth() + 1;
        var day = d.getDate();
        var next = new Date(y, m - 1, day + 1);
        return {
            start: { date: { year: y, month: m, day: day }, time: {} },
            end: { date: { year: next.getFullYear(), month: next.getMonth() + 1, day: next.getDate() }, time: {} }
        };
    }

    function handleHttpError(xhr, context) {
        var time = new Date().toLocaleTimeString();
        if (xhr.status === 0) {
            api.errorMessage = i18n("Network error — check your connection");
            api.lastRequestStatus = i18n("Network error at %1", time);
            api.lastRequestState = "error";
            api.error(api.errorMessage);
            return true;
        }
        if (xhr.status === 401) {
            api.lastRequestStatus = i18n("Token expired at %1 — refreshing", time);
            api.lastRequestState = "warn";
            // Several requests fire in parallel per fetchData(); only forward the
            // first 401 so a stale token doesn't trigger a refresh burst.
            if (!api.authErrorSignaled) {
                api.authErrorSignaled = true;
                api.authError();
            }
            return true;
        }
        if (xhr.status === 429) {
            api.errorMessage = i18n("Rate limited — try again later");
            api.lastRequestStatus = i18n("Rate limited at %1 — showing cached data", time);
            api.lastRequestState = "warn";
            api.error(api.errorMessage);
            return true;
        }
        if (xhr.status >= 500) {
            api.errorMessage = i18n("Google Health server error (HTTP %1)", xhr.status);
            api.lastRequestStatus = i18n("Server error (HTTP %1) at %2", xhr.status, time);
            api.lastRequestState = "error";
            api.error(api.errorMessage);
            return true;
        }
        if (xhr.status !== 200) {
            api.errorMessage = i18n("%1 failed (HTTP %2)", context, xhr.status);
            api.lastRequestStatus = i18n("Error (HTTP %1) at %2", xhr.status, time);
            api.lastRequestState = "error";
            api.error(api.errorMessage);
            return true;
        }
        return false;
    }

    function cleanup() {
        for (var i = 0; i < pendingXhrs.length; i++) {
            if (pendingXhrs[i]) pendingXhrs[i].abort();
        }
        pendingXhrs = [];
    }

    // Called once per response so the "all requests settled" bookkeeping
    // (isLoading, dataUpdated) only fires once per fetchData(). Data counts as
    // updated if any request succeeded; status is OK only if none set an error.
    function requestSettled(ok) {
        if (ok) anySucceeded = true;
        pendingCount--;
        if (pendingCount > 0) return;
        isLoading = false;
        if (!anySucceeded) return;
        api.lastUpdatedTimestamp = Date.now();
        api.lastUpdated = new Date().toLocaleTimeString();
        if (api.errorMessage === "") {
            api.lastRequestStatus = i18n("OK — updated at %1", api.lastUpdated);
            api.lastRequestState = "ok";
        }
        api.dataUpdated();
    }

    function dailyRollUp(dataType, onSuccess) {
        var xhr = new XMLHttpRequest();
        pendingXhrs.push(xhr);
        xhr.open("POST", apiBase + "/dataTypes/" + dataType + "/dataPoints:dailyRollUp");
        xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 15000;
        xhr.ontimeout = function() {
            api.errorMessage = i18n("Request timed out — check your connection");
            api.lastRequestStatus = i18n("Timed out at %1", new Date().toLocaleTimeString());
            api.lastRequestState = "error";
            api.error(api.errorMessage);
            requestSettled(false);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (handleHttpError(xhr, i18n("%1 fetch", dataType))) {
                requestSettled(false);
                return;
            }
            try {
                var data = JSON.parse(xhr.responseText);
                var points = data.rollupDataPoints;
                // No rollup point for today means no activity yet: a real zero.
                onSuccess(points && points.length > 0 ? points[0] : {});
                requestSettled(true);
            } catch(e) {
                api.errorMessage = i18n("Failed to parse %1 data", dataType);
                api.lastRequestStatus = i18n("Parse error at %1", new Date().toLocaleTimeString());
                api.lastRequestState = "error";
                api.error(api.errorMessage);
                requestSettled(false);
            }
        };
        var range = todayRange();
        xhr.send(JSON.stringify({
            range: { start: range.start, end: range.end },
            windowSizeDays: 1,
            dataSourceFamily: "users/me/dataSourceFamilies/all-sources"
        }));
    }

    function fetchStepsRollup() {
        dailyRollUp("steps", function(point) {
            api.steps = point.steps ? parseInt(point.steps.countSum, 10) || 0 : 0;
        });
    }

    function fetchTotalCaloriesRollup() {
        dailyRollUp("total-calories", function(point) {
            api.calories = point.totalCalories ? Math.round(point.totalCalories.kcalSum) || 0 : 0;
        });
    }

    function fetchDistanceRollup() {
        dailyRollUp("distance", function(point) {
            // API reports distance in millimeters; the UI works in kilometers.
            api.distance = point.distance ? (parseInt(point.distance.millimetersSum, 10) || 0) / 1000000 : 0;
        });
    }

    function fetchActiveMinutesRollup() {
        dailyRollUp("active-minutes", function(point) {
            var byLevel = point.activeMinutes && point.activeMinutes.activeMinutesRollupByActivityLevel;
            var total = 0;
            if (!byLevel) byLevel = [];
            for (var i = 0; i < byLevel.length; i++) {
                // MODERATE + VIGOROUS mirrors the old Fitbit metric (fairly + very
                // active minutes); LIGHT activity is intentionally excluded.
                var level = byLevel[i].activityLevel;
                if (level === "MODERATE" || level === "VIGOROUS") {
                    total += parseInt(byLevel[i].activeMinutesSum, 10) || 0;
                }
            }
            api.activeMinutes = total;
        });
    }

    // GET a dataPoints list. Vitals are optional extras: a missing scope or a
    // device that doesn't record a metric must not put the widget into an error
    // state, so failures other than 401 are only logged.
    function listDataPoints(dataType, query, onSuccess) {
        var xhr = new XMLHttpRequest();
        pendingXhrs.push(xhr);
        xhr.open("GET", apiBase + "/dataTypes/" + dataType + "/dataPoints?" + query);
        xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 401) {
                if (!api.authErrorSignaled) {
                    api.authErrorSignaled = true;
                    api.authError();
                }
                requestSettled(false);
                return;
            }
            if (xhr.status !== 200) {
                if (xhr.status !== 0) {
                    console.warn("FitDash: " + dataType + " fetch failed (HTTP " + xhr.status + ")");
                }
                requestSettled(false);
                return;
            }
            try {
                var data = JSON.parse(xhr.responseText);
                onSuccess(data.dataPoints || []);
                requestSettled(true);
            } catch(e) {
                console.warn("FitDash: failed to parse " + dataType + " data");
                requestSettled(false);
            }
        };
        xhr.send();
    }

    // Results are ordered newest first, so pageSize=1 yields the latest daily summary.
    function latestDaily(dataType, field, onSuccess) {
        listDataPoints(dataType, "pageSize=1", function(points) {
            if (points.length > 0 && points[0][field]) {
                onSuccess(points[0][field]);
            }
        });
    }

    function fetchRestingHeartRate() {
        latestDaily("daily-resting-heart-rate", "dailyRestingHeartRate", function(v) {
            api.restingHeartRate = parseInt(v.beatsPerMinute, 10) || 0;
        });
    }

    function fetchOxygenSaturation() {
        latestDaily("daily-oxygen-saturation", "dailyOxygenSaturation", function(v) {
            api.oxygenSaturation = Number(v.averagePercentage) || 0;
        });
    }

    function fetchHeartRateVariability() {
        latestDaily("daily-heart-rate-variability", "dailyHeartRateVariability", function(v) {
            api.heartRateVariability = Number(v.averageHeartRateVariabilityMilliseconds) || 0;
        });
    }

    function fetchRespiratoryRate() {
        latestDaily("daily-respiratory-rate", "dailyRespiratoryRate", function(v) {
            api.respiratoryRate = Number(v.breathsPerMinute) || 0;
        });
    }

    // Last night's sleep: sessions that ended today (local calendar). Naps are
    // excluded unless they're all there is.
    function fetchSleep() {
        var d = new Date();
        var pad = function(n) { return (n < 10 ? "0" : "") + n; };
        var today = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
        var filter = 'sleep.interval.civil_end_time >= "' + today + '"';
        listDataPoints("sleep", "filter=" + encodeURIComponent(filter), function(points) {
            var main = 0, all = 0;
            for (var i = 0; i < points.length; i++) {
                var sleep = points[i].sleep;
                if (!sleep || !sleep.summary) continue;
                var mins = parseInt(sleep.summary.minutesAsleep, 10) || 0;
                all += mins;
                if (!(sleep.metadata && sleep.metadata.nap)) main += mins;
            }
            // No session ending today yet means unknown, not zero sleep.
            api.sleepMinutes = points.length > 0 ? (main > 0 ? main : all) : NaN;
        });
    }
}
