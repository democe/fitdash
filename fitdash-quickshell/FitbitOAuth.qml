import QtQuick
import Quickshell.Io

// OAuth 2.0 PKCE flow via the fitdash-auth.py helper script.
// Replaces the Plasma5Support.DataSource("executable") approach.
QtObject {
    id: oauth

    property int callbackPort: 19847

    signal authorized(var tokens)
    signal error(string message)

    readonly property string scriptPath:
        Qt.resolvedUrl("scripts/fitdash-auth.py").toString().replace("file://", "")

    function isValidClientId(clientId) {
        return /^[A-Za-z0-9]+$/.test(clientId)
    }

    // ── Auth process ─────────────────────────────────────────────────────────
    // StdioCollector buffers all output; onStreamFinished fires once the pipe
    // closes (i.e. when the process exits).  The script writes exactly one JSON
    // object to either stdout (success) or stderr (error), so we handle each
    // stream independently without needing to wait for both.

    Process {
        id: authProcess

        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim()
                if (!out) return
                try {
                    var tokens = JSON.parse(out)
                    if (tokens.error) oauth.error(tokens.error)
                    else              oauth.authorized(tokens)
                } catch(e) {
                    oauth.error("Failed to parse auth response")
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                var err = this.text.trim()
                if (!err) return
                try {
                    oauth.error(JSON.parse(err).error || "Unknown auth error")
                } catch(e) {
                    oauth.error(err)
                }
            }
        }
    }

    function authorize(clientId) {
        if (!isValidClientId(clientId)) {
            oauth.error("Invalid client ID format")
            return
        }
        authProcess.command = [
            "python3", scriptPath,
            "--client-id=" + clientId,
            "--port="      + callbackPort
        ]
        authProcess.running = true
    }

    function cancelAuthorization() {
        if (!authProcess.running) return
        authProcess.running = false
        oauth.error("Authorization canceled")
    }

    // ── Token refresh (pure XHR — no subprocess needed) ─────────────────────

    function refreshToken(clientId, refreshTok) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://api.fitbit.com/oauth2/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onerror = function() { oauth.error("Network error during token refresh") }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 0)   { oauth.error("Network error during token refresh"); return }
            if (xhr.status === 401) { oauth.error("Refresh token expired — please re-authorize"); return }
            if (xhr.status === 429) { oauth.error("Rate limited — try again later"); return }
            if (xhr.status >= 500)  { oauth.error("Fitbit server error (HTTP " + xhr.status + ")"); return }
            if (xhr.status !== 200) { oauth.error("Token refresh failed (HTTP " + xhr.status + ")"); return }
            try {
                var resp = JSON.parse(xhr.responseText)
                if (resp.access_token && resp.refresh_token) {
                    oauth.authorized(resp)
                } else {
                    oauth.error(resp.errors ? resp.errors[0].message : "Refresh failed — missing tokens")
                }
            } catch(e) {
                oauth.error("Token refresh failed — invalid response")
            }
        }
        var body = "grant_type=refresh_token"
            + "&refresh_token=" + encodeURIComponent(refreshTok)
            + "&client_id="     + encodeURIComponent(clientId)
        xhr.send(body)
    }
}
