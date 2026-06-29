import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import "sha256.js" as Crypto

Item {
    id: oauth

    property int callbackPort: 19847
    property string activeSource: ""
    property bool lastErrorRequiresAuthorization: false
    // Guards against the proactive timer and a reactive 401 both spending the
    // refresh token at once — Fitbit rotates it on every use, so a concurrent
    // double-use invalidates it and forces a full re-authorization.
    property bool refreshing: false

    // Retry state for transient token-endpoint failures (5xx, 429, network
    // errors). Held across the retry delay so the `refreshing` guard stays
    // asserted and the proactive timer can't double-spend the refresh token.
    property int maxTokenRetries: 3
    property var _retryBody: null
    property var _retryMessages: null
    property bool _retryInvalidGrantFlag: false
    property int _retryAttempt: 0

    // State for the manual copy+paste fallback flow.
    property string manualVerifier: ""
    property string manualState: ""
    property string manualRedirectUri: ""

    signal authorized(var tokens)
    signal error(string message)

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/fitdash-auth.py").toString().replace("file://", "")

    // OAuth scopes requested. Kept in sync with scripts/fitdash-auth.py.
    readonly property string scopes: "activity heartrate profile settings"

    // Backoff timer for transient token-endpoint failures. On each fire it
    // re-issues the same POST body that previously failed. Cleared on
    // success, on a non-retryable error, or when retries are exhausted.
    Timer {
        id: tokenRetryTimer
        repeat: false

        onTriggered: {
            if (!oauth.refreshing || oauth._retryBody === null) {
                // State got cleared (success, abort, or user-driven
                // re-authorization). Don't resurrect a stale attempt.
                return;
            }
            postTokenRequest(oauth._retryBody, oauth._retryMessages, oauth._retryInvalidGrantFlag);
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source);
            if (source === oauth.activeSource) {
                oauth.activeSource = "";
            }
            var stdout = (data["stdout"] || "").trim();
            var stderr = (data["stderr"] || "").trim();

            // stdout is authoritative: the Python script writes tokens to stdout on
            // success and errors to stderr. Check stdout first so that incidental
            // stderr noise (e.g. Qt locale warnings from the browser launcher) cannot
            // shadow a successful token response.
            if (stdout) {
                try {
                    var tokens = JSON.parse(stdout);
                    if (tokens.error) {
                        reportError(tokens.error, false);
                    } else {
                        oauth.authorized(tokens);
                    }
                    return;
                } catch(e) {
                    // stdout was not valid JSON — fall through to check stderr
                }
            }

            if (stderr) {
                try {
                    var err = JSON.parse(stderr);
                    reportError(err.error || i18n("Unknown error"), false);
                } catch(e) {
                    reportError(stderr, false);
                }
                return;
            }

            reportError(i18n("Failed to parse auth response"), false);
        }
    }

    function isValidClientId(clientId) {
        return (/^[A-Za-z0-9]+$/).test(clientId);
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function reportError(message, requiresAuthorization) {
        refreshing = false;
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
    //
    // Transient failures (5xx, 429, network errors, timeouts) are retried with
    // exponential backoff up to `maxTokenRetries` times. The `refreshing` guard
    // stays asserted across the delay so the proactive refresh timer can't
    // double-spend the refresh token while a retry is pending. Non-retryable
    // failures (400/401, malformed 200 responses, unexpected non-200 statuses)
    // surface immediately via `reportError`.
    function postTokenRequest(body, messages, invalidGrantRequiresAuth) {
        lastErrorRequiresAuthorization = false;

        // Persist the request context so the retry timer can replay it. These
        // are overwritten (not appended) on every attempt, including retries.
        _retryBody = body;
        _retryMessages = messages;
        _retryInvalidGrantFlag = invalidGrantRequiresAuth;

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://api.fitbit.com/oauth2/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.timeout = 15000;
        xhr.onerror = function() {
            scheduleRetryOrGiveUp(messages.network, false);
        };
        xhr.ontimeout = function() {
            scheduleRetryOrGiveUp(messages.network, false);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 0) {
                scheduleRetryOrGiveUp(messages.network, false);
                return;
            }
            if (xhr.status === 400 || xhr.status === 401) {
                var authMessage = authorizationErrorMessage(xhr);
                giveUp(authMessage
                    ? i18n("%1 (%2)", messages.invalidGrant, authMessage)
                    : messages.invalidGrant,
                    invalidGrantRequiresAuth);
                return;
            }
            if (xhr.status === 429) {
                // Honor Retry-After if Fitbit sends it (seconds). Fall back to
                // the exponential schedule otherwise.
                var retryAfter = 0;
                var header = xhr.getResponseHeader("Retry-After");
                if (header) {
                    var parsed = parseInt(header, 10);
                    if (!isNaN(parsed) && parsed > 0) retryAfter = parsed * 1000;
                }
                scheduleRetryOrGiveUp(i18n("Rate limited — try again later"), false, retryAfter);
                return;
            }
            if (xhr.status >= 500) {
                scheduleRetryOrGiveUp(i18n("Fitbit server error (HTTP %1)", xhr.status), false);
                return;
            }
            if (xhr.status !== 200) {
                giveUp(i18n("%1 (HTTP %2)", messages.generic, xhr.status), false);
                return;
            }
            try {
                var resp = JSON.parse(xhr.responseText);
                if (resp.access_token && resp.refresh_token) {
                    clearRetryState();
                    refreshing = false;
                    oauth.authorized(resp);
                } else {
                    giveUp(resp.errors ? resp.errors[0].message : messages.missingTokens, invalidGrantRequiresAuth);
                }
            } catch(e) {
                giveUp(messages.invalidResponse, invalidGrantRequiresAuth);
            }
        };
        xhr.send(body);
    }

    // Reset retry bookkeeping. Called on success and on any non-retryable
    // failure. Kept separate from `reportError` because `reportError` clears
    // the `refreshing` guard — during a pending retry we want the guard to
    // stay asserted, so retries go through this path instead.
    function clearRetryState() {
        _retryBody = null;
        _retryMessages = null;
        _retryInvalidGrantFlag = false;
        _retryAttempt = 0;
        if (tokenRetryTimer.running) tokenRetryTimer.stop();
    }

    // Surface a non-retryable failure: reset retry state and emit the error.
    function giveUp(message, requiresAuthorization) {
        clearRetryState();
        reportError(message, requiresAuthorization);
    }

    // Decide whether to retry a transient failure or give up. `fixedDelay`
    // overrides the exponential schedule (used for Retry-After). Messages are
    // not emitted to the UI while a retry is pending — the plasmoid keeps its
    // last-known-good status rather than flashing an error for a blip that
    // may resolve within seconds.
    function scheduleRetryOrGiveUp(message, requiresAuthorization, fixedDelay) {
        if (_retryAttempt >= maxTokenRetries) {
            giveUp(message, requiresAuthorization);
            return;
        }
        _retryAttempt++;
        var base = fixedDelay && fixedDelay > 0
            ? fixedDelay
            : Math.min(1000 * Math.pow(2, _retryAttempt - 1), 8000);
        // ±25% jitter to avoid synchronizing retries with other clients.
        var jitter = base * 0.25 * (Math.random() * 2 - 1);
        tokenRetryTimer.interval = Math.max(500, Math.round(base + jitter));
        console.log("FitDash: token request transient failure (" + message
                    + "), retry " + _retryAttempt + "/" + maxTokenRetries
                    + " in " + tokenRetryTimer.interval + "ms");
        tokenRetryTimer.restart();
    }

    function refreshToken(clientId, refreshTok) {
        if (refreshing) return;
        refreshing = true;
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
