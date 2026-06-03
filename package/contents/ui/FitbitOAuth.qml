import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: oauth

    property int callbackPort: 19847
    property string activeSource: ""
    property bool lastErrorRequiresAuthorization: false

    signal authorized(var tokens)
    signal error(string message)

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/fitdash-auth.py").toString().replace("file://", "")

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source);
            if (source === oauth.activeSource) {
                oauth.activeSource = "";
            }
            var stdout = data["stdout"] || "";
            var stderr = data["stderr"] || "";

            if (stderr) {
                try {
                    var err = JSON.parse(stderr);
                    reportError(err.error || i18n("Unknown error"), false);
                } catch(e) {
                    reportError(stderr, false);
                }
                return;
            }

            try {
                var tokens = JSON.parse(stdout);
                if (tokens.error) {
                    reportError(tokens.error, false);
                } else {
                    oauth.authorized(tokens);
                }
            } catch(e) {
                reportError(i18n("Failed to parse auth response"), false);
            }
        }
    }

    function isValidClientId(clientId) {
        return (/^[A-Za-z0-9]+$/).test(clientId);
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function reportError(message, requiresAuthorization) {
        lastErrorRequiresAuthorization = requiresAuthorization || false;
        oauth.error(message);
    }

    function authorizationErrorMessage(xhr) {
        try {
            var resp = JSON.parse(xhr.responseText);
            if (resp.errors && resp.errors.length > 0 && resp.errors[0].message) {
                return resp.errors[0].message;
            }
            if (resp.error_description) {
                return resp.error_description;
            }
            if (resp.error) {
                return resp.error;
            }
        } catch(e) {
            // Fall back to generic messages below.
        }
        return "";
    }

    function authorize(clientId) {
        lastErrorRequiresAuthorization = false;
        if (!isValidClientId(clientId)) {
            reportError(i18n("Invalid client ID format"), false);
            return;
        }
        var cmd = "python3 " + shellEscape(scriptPath) + " --client-id=" + shellEscape(clientId) + " --port=" + callbackPort;
        activeSource = cmd;
        executable.connectSource(cmd);
    }

    function cancelAuthorization() {
        if (activeSource === "") {
            return;
        }
        executable.disconnectSource(activeSource);
        activeSource = "";
        reportError(i18n("Authorization canceled"), false);
    }

    function refreshToken(clientId, refreshTok) {
        lastErrorRequiresAuthorization = false;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://api.fitbit.com/oauth2/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onerror = function() {
            reportError(i18n("Network error during token refresh"), false);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 0) {
                reportError(i18n("Network error during token refresh"), false);
                return;
            }
            if (xhr.status === 400 || xhr.status === 401) {
                var authMessage = authorizationErrorMessage(xhr);
                reportError(authMessage
                    ? i18n("Refresh token invalid — please re-authorize (%1)", authMessage)
                    : i18n("Refresh token expired — please re-authorize"),
                    true);
                return;
            }
            if (xhr.status === 429) {
                reportError(i18n("Rate limited — try again later"), false);
                return;
            }
            if (xhr.status >= 500) {
                reportError(i18n("Fitbit server error (HTTP %1)", xhr.status), false);
                return;
            }
            if (xhr.status !== 200) {
                reportError(i18n("Token refresh failed (HTTP %1)", xhr.status), false);
                return;
            }
            try {
                var resp = JSON.parse(xhr.responseText);
                if (resp.access_token && resp.refresh_token) {
                    oauth.authorized(resp);
                } else {
                    reportError(resp.errors ? resp.errors[0].message : i18n("Refresh failed — missing tokens"), true);
                }
            } catch(e) {
                reportError(i18n("Token refresh failed — invalid response"), true);
            }
        };
        var body = "grant_type=refresh_token"
            + "&refresh_token=" + encodeURIComponent(refreshTok)
            + "&client_id=" + encodeURIComponent(clientId);
        xhr.send(body);
    }
}
