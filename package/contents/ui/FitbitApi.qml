import QtQuick

QtObject {
    id: api

    property string accessToken: ""

    property int steps: 0
    property int calories: 0
    property real distance: 0.0
    property int activeMinutes: 0
    property int restingHeartRate: 0
    property int stepsGoal: 0
    property string lastUpdated: ""
    property real lastUpdatedTimestamp: 0

    property bool isLoading: false
    property string errorMessage: ""
    property string lastRequestStatus: ""
    property string lastRequestState: "unknown"

    signal dataUpdated()
    signal authError()
    signal error(string message)

    function fetchData() {
        if (!accessToken) {
            api.lastRequestState = "error";
            api.error(i18n("No access token"));
            return;
        }
        if (isLoading) return;
        isLoading = true;
        errorMessage = "";
        fetchActivity();
        fetchHeartRate();
    }

    function todayStr() {
        var d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, '0') + "-" + String(d.getDate()).padStart(2, '0');
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
            api.authError();
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
            api.errorMessage = i18n("Fitbit server error (HTTP %1)", xhr.status);
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

    function fetchActivity() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.fitbit.com/1/user/-/activities/date/" + todayStr() + ".json");
        xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (handleHttpError(xhr, i18n("Activity fetch"))) {
                isLoading = false;
                return;
            }
            try {
                var data = JSON.parse(xhr.responseText);
                var summary = data.summary || {};
                api.steps = summary.steps || 0;
                api.calories = summary.caloriesOut || 0;
                var dist = summary.distances;
                if (dist && Array.isArray(dist)) {
                    for (var i = 0; i < dist.length; i++) {
                        if (dist[i].activity === "total") {
                            api.distance = dist[i].distance || 0;
                            break;
                        }
                    }
                }
                api.activeMinutes = (summary.fairlyActiveMinutes || 0) + (summary.veryActiveMinutes || 0);
                var goals = data.goals || {};
                if (goals.steps) {
                    api.stepsGoal = goals.steps;
                }
                api.lastUpdatedTimestamp = Date.now();
                api.lastUpdated = new Date().toLocaleTimeString();
                api.lastRequestStatus = i18n("OK — updated at %1", api.lastUpdated);
                api.lastRequestState = "ok";
                api.isLoading = false;
                api.dataUpdated();
            } catch(e) {
                api.errorMessage = i18n("Failed to parse activity data");
                api.lastRequestStatus = i18n("Parse error at %1", new Date().toLocaleTimeString());
                api.lastRequestState = "error";
                api.error(api.errorMessage);
                api.isLoading = false;
            }
        };
        xhr.send();
    }

    function fetchHeartRate() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.fitbit.com/1/user/-/activities/heart/date/" + todayStr() + "/1d.json");
        xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 401) return; // already handled by activity call
            if (xhr.status !== 200) return;
            try {
                var data = JSON.parse(xhr.responseText);
                var hearts = data["activities-heart"];
                if (hearts && hearts.length > 0 && hearts[0].value) {
                    api.restingHeartRate = hearts[0].value.restingHeartRate || 0;
                }
            } catch(e) {
                // non-critical
            }
        };
        xhr.send();
    }
}
