import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import "sha256.js" as Crypto

Item {
    id: oauth

    property int callbackPort: 19847
    property string activeSource: ""
    property bool lastErrorRequiresAuthorization: false

    // State for the manual copy+paste fallback flow.
    property string manualVerifier: ""
    property string manualState: ""
    property string manualRedirectUri: ""

    signal authorized(var tokens)
    signal error(string message)

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/fitdash-auth.py").toString().replace("file://", "")

    // OAuth scopes requested. Kept in sync with scripts/fitdash-auth.py.
    readonly property string scopes: "activity heartrate profile settings"

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

    // Shared POST to Fitbit's token endpoint. `messages` lets each caller phrase
    // its own error text; `invalidGrantRequiresAuth` flags whether a 400/401 means
    // the user must re-authorize (true for refresh, false for a fresh exchange).
    function postTokenRequest(body, messages, invalidGrantRequiresAuth) {
        lastErrorRequiresAuthorization = false;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://api.fitbit.com/oauth2/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onerror = function() {
            reportError(messages.network, false);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 0) {
                reportError(messages.network, false);
                return;
            }
            if (xhr.status === 400 || xhr.status === 401) {
                var authMessage = authorizationErrorMessage(xhr);
                reportError(authMessage
                    ? i18n("%1 (%2)", messages.invalidGrant, authMessage)
                    : messages.invalidGrant,
                    invalidGrantRequiresAuth);
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
                reportError(i18n("%1 (HTTP %2)", messages.generic, xhr.status), false);
                return;
            }
            try {
                var resp = JSON.parse(xhr.responseText);
                if (resp.access_token && resp.refresh_token) {
                    oauth.authorized(resp);
                } else {
                    reportError(resp.errors ? resp.errors[0].message : messages.missingTokens, invalidGrantRequiresAuth);
                }
            } catch(e) {
                reportError(messages.invalidResponse, invalidGrantRequiresAuth);
            }
        };
        xhr.send(body);
    }

    function refreshToken(clientId, refreshTok) {
        var body = "grant_type=refresh_token"
            + "&refresh_token=" + encodeURIComponent(refreshTok)
            + "&client_id=" + encodeURIComponent(clientId);
        postTokenRequest(body, {
            network: i18n("Network error during token refresh"),
            invalidGrant: i18n("Refresh token invalid — please re-authorize"),
            generic: i18n("Token refresh failed"),
            missingTokens: i18n("Refresh failed — missing tokens"),
            invalidResponse: i18n("Token refresh failed — invalid response")
        }, true);
    }

    // --- Manual copy+paste fallback (no loopback server / no python) ---

    function buildAuthorizeUrl(clientId, challenge, state, redirectUri) {
        return "https://www.fitbit.com/oauth2/authorize"
            + "?response_type=code"
            + "&client_id=" + encodeURIComponent(clientId)
            + "&redirect_uri=" + encodeURIComponent(redirectUri)
            + "&scope=" + encodeURIComponent(scopes)
            + "&code_challenge=" + encodeURIComponent(challenge)
            + "&code_challenge_method=S256"
            + "&state=" + encodeURIComponent(state);
    }

    // Generate an unguessable token from the unreserved PKCE character set.
    // NOTE: QML/JS has no crypto-strong RNG, so this mixes Math.random(),
    // Date.now() and Qt.md5 chaining. Weaker than the python path's secrets
    // module, but acceptable for a one-time, localhost-scoped PKCE verifier.
    function randomToken(length) {
        var unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
        var seed = "" + Date.now() + Math.random() + Math.random();
        var pool = "";
        while (pool.length < length) {
            seed = Qt.md5(seed + Math.random());
            pool += seed;
        }
        var out = "";
        for (var i = 0; i < length; i++) {
            // Map each hex char to the unreserved set with extra random spread.
            var idx = (parseInt(pool[i], 16) * 4 + Math.floor(Math.random() * 4)) % unreserved.length;
            out += unreserved[idx];
        }
        return out;
    }

    // Begin the manual flow: returns the authorize URL and stores the
    // verifier/state needed to complete the exchange. Returns "" on bad input.
    function beginManualAuthorization(clientId) {
        lastErrorRequiresAuthorization = false;
        if (!isValidClientId(clientId)) {
            reportError(i18n("Invalid client ID format"), false);
            return "";
        }
        manualVerifier = randomToken(96);
        manualState = randomToken(32);
        manualRedirectUri = "http://localhost:" + callbackPort + "/callback";
        var challenge = Crypto.pkceChallenge(manualVerifier);
        return buildAuthorizeUrl(clientId, challenge, manualState, manualRedirectUri);
    }

    // Complete the manual flow from the redirect URL (or a bare code) the user pastes.
    function completeManualAuthorization(clientId, pastedText) {
        var text = (pastedText || "").trim();
        if (text === "") {
            reportError(i18n("Paste the redirect URL or authorization code first"), false);
            return;
        }
        if (manualVerifier === "") {
            reportError(i18n("Start the manual authorization first"), false);
            return;
        }

        // Strip any URL fragment (Fitbit appends "#_=_" to the redirect).
        text = text.split("#")[0];

        var code = text;
        var returnedState = "";
        if (text.indexOf("?") !== -1 || text.indexOf("code=") !== -1) {
            var query = text.indexOf("?") !== -1 ? text.substring(text.indexOf("?") + 1) : text;
            var parts = query.split("&");
            for (var i = 0; i < parts.length; i++) {
                var eq = parts[i].indexOf("=");
                if (eq === -1) continue;
                var key = decodeURIComponent(parts[i].substring(0, eq));
                var val = decodeURIComponent(parts[i].substring(eq + 1).replace(/\+/g, " "));
                if (key === "code") code = val;
                else if (key === "state") returnedState = val;
                else if (key === "error") {
                    reportError(val || i18n("Authorization was denied"), false);
                    return;
                }
            }
        }

        if (returnedState !== "" && returnedState !== manualState) {
            reportError(i18n("Authorization failed (state mismatch) — please try again"), false);
            return;
        }
        if (code === "") {
            reportError(i18n("No authorization code found in the pasted text"), false);
            return;
        }

        var body = "grant_type=authorization_code"
            + "&code=" + encodeURIComponent(code)
            + "&code_verifier=" + encodeURIComponent(manualVerifier)
            + "&client_id=" + encodeURIComponent(clientId)
            + "&redirect_uri=" + encodeURIComponent(manualRedirectUri);
        postTokenRequest(body, {
            network: i18n("Network error during token exchange"),
            invalidGrant: i18n("Authorization code invalid or expired — please try again"),
            generic: i18n("Token exchange failed"),
            missingTokens: i18n("Token exchange failed — missing tokens"),
            invalidResponse: i18n("Token exchange failed — invalid response")
        }, false);
    }
}
