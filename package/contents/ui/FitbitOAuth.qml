import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: oauth

    property int callbackPort: 19847

    signal authorized(var tokens)
    signal error(string message)

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/fitdash-auth.py").toString().replace("file://", "")

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source);
            var stdout = data["stdout"] || "";
            var stderr = data["stderr"] || "";

            if (stderr) {
                try {
                    var err = JSON.parse(stderr);
                    oauth.error(err.error || "Unknown error");
                } catch(e) {
                    oauth.error(stderr);
                }
                return;
            }

            try {
                var tokens = JSON.parse(stdout);
                if (tokens.error) {
                    oauth.error(tokens.error);
                } else {
                    oauth.authorized(tokens);
                }
            } catch(e) {
                oauth.error("Failed to parse auth response");
            }
        }
    }

    function isValidClientId(clientId) {
        return (/^[A-Za-z0-9]+$/).test(clientId);
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function authorize(clientId) {
        if (!isValidClientId(clientId)) {
            oauth.error("Invalid client ID format");
            return;
        }
        var cmd = "python3 " + shellEscape(scriptPath) + " --client-id=" + shellEscape(clientId) + " --port=" + callbackPort;
        executable.connectSource(cmd);
    }

    function refreshToken(clientId, refreshTok) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://api.fitbit.com/oauth2/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onerror = function() {
            oauth.error("Network error during token refresh");
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 0) {
                oauth.error("Network error during token refresh");
                return;
            }
            if (xhr.status === 401) {
                oauth.error("Refresh token expired — please re-authorize");
                return;
            }
            if (xhr.status === 429) {
                oauth.error("Rate limited — try again later");
                return;
            }
            if (xhr.status >= 500) {
                oauth.error("Fitbit server error (HTTP " + xhr.status + ")");
                return;
            }
            if (xhr.status !== 200) {
                oauth.error("Token refresh failed (HTTP " + xhr.status + ")");
                return;
            }
            try {
                var resp = JSON.parse(xhr.responseText);
                if (resp.access_token && resp.refresh_token) {
                    oauth.authorized(resp);
                } else {
                    oauth.error(resp.errors ? resp.errors[0].message : "Refresh failed — missing tokens");
                }
            } catch(e) {
                oauth.error("Token refresh failed — invalid response");
            }
        };
        var body = "grant_type=refresh_token"
            + "&refresh_token=" + encodeURIComponent(refreshTok)
            + "&client_id=" + encodeURIComponent(clientId);
        xhr.send(body);
    }
}
