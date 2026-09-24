import QtQuick

QtObject {
    id: api

    property string accessToken: ""

    property int steps: 0
    property int calories: 0
    property real distance: 0.0
    property int activeMinutes: 0
    property int restingHeartRate: 0
    property string lastUpdated: ""
    property real lastUpdatedTimestamp: 0

    property bool isLoading: false
    property string errorMessage: ""
    property string lastRequestStatus: ""
    property string lastRequestState: "unknown"

    property var pendingXhrs: []
    property int pendingCount: 0
    property bool authErrorSignaled: false

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
        pendingXhrs = [];
        pendingCount = 5;
        fetchStepsRollup();
        fetchTotalCaloriesRollup();
        fetchDistanceRollup();
        fetchActiveMinutesRollup();
        fetchRestingHeartRate();
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

    // Every dailyRollUp call shares this shape: one civil day, one source family.
    // Called once per successful (non-auth-error) response so the "all requests
    // settled" bookkeeping (isLoading, dataUpdated) only fires once per fetchData().
    function requestSettled(ok) {
        pendingCount--;
        if (pendingCount > 0) return;
        isLoading = false;
        if (ok) {
            api.lastUpdatedTimestamp = Date.now();
            api.lastUpdated = new Date().toLocaleTimeString();
            api.lastRequestStatus = i18n("OK — updated at %1", api.lastUpdated);
            api.lastRequestState = "ok";
            api.dataUpdated();
        }
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
                if (points && points.length > 0) {
                    onSuccess(points[0]);
                }
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
            if (point.steps && point.steps.countSum !== undefined) {
                api.steps = parseInt(point.steps.countSum, 10) || 0;
            }
        });
    }

    function fetchTotalCaloriesRollup() {
        dailyRollUp("total-calories", function(point) {
            if (point.totalCalories && point.totalCalories.kcalSum !== undefined) {
                api.calories = Math.round(point.totalCalories.kcalSum) || 0;
            }
        });
    }

    function fetchDistanceRollup() {
        dailyRollUp("distance", function(point) {
            if (point.distance && point.distance.millimetersSum !== undefined) {
                // API reports distance in millimeters; the UI works in kilometers.
                api.distance = (parseInt(point.distance.millimetersSum, 10) || 0) / 1000000;
            }
        });
    }

    function fetchActiveMinutesRollup() {
        dailyRollUp("active-minutes", function(point) {
            var byLevel = point.activeMinutes && point.activeMinutes.activeMinutesRollupByActivityLevel;
            if (!byLevel) return;
            var total = 0;
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

    function fetchRestingHeartRate() {
        var xhr = new XMLHttpRequest();
        pendingXhrs.push(xhr);
        xhr.open("GET", apiBase + "/dataTypes/daily-resting-heart-rate/dataPoints?pageSize=1");
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
                    console.warn("FitDash: resting heart rate fetch failed (HTTP " + xhr.status + ")");
                }
                requestSettled(false);
                return;
            }
            try {
                var data = JSON.parse(xhr.responseText);
                var points = data.dataPoints;
                if (points && points.length > 0 && points[0].dailyRestingHeartRate) {
                    api.restingHeartRate = parseInt(points[0].dailyRestingHeartRate.beatsPerMinute, 10) || 0;
                }
                requestSettled(true);
            } catch(e) {
                console.warn("FitDash: failed to parse resting heart rate data");
                requestSettled(false);
            }
        };
        xhr.send();
    }
}
