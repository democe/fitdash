#!/usr/bin/env python3
"""OAuth 2.0 PKCE helper for FitDash. Outputs tokens JSON to stdout."""

import argparse
import base64
import hashlib
import gettext
import html
from pathlib import Path
import http.server
import json
import secrets
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import webbrowser


# Installed beside contents/locale; use the same catalog and LANGUAGE preference
# as the widget. Running from the source tree falls back to English.
_translation = gettext.translation(
    "plasma_applet_com.democe.fitdash",
    localedir=Path(__file__).resolve().parent.parent / "locale",
    fallback=True,
)
_ = _translation.gettext


def callback_page(message, detail=""):
    return ("<!doctype html><html><head><meta charset=\"utf-8\"></head>"
            "<body dir=\"auto\"><h1>" + html.escape(message) + "</h1><p>"
            + html.escape(detail) + "</p></body></html>").encode("utf-8")


def generate_pkce():
    code_verifier = secrets.token_urlsafe(64)[:128]
    digest = hashlib.sha256(code_verifier.encode("ascii")).digest()
    code_challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    return code_verifier, code_challenge


def exchange_token(code, code_verifier, client_id, redirect_uri):
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "code_verifier": code_verifier,
        "client_id": client_id,
        "redirect_uri": redirect_uri,
    }).encode("ascii")
    req = urllib.request.Request(
        "https://api.fitbit.com/oauth2/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            tokens = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise RuntimeError(_("%1 (HTTP %2)").replace("%1", _("Token exchange failed")).replace("%2", str(e.code))) from None
    except urllib.error.URLError as e:
        raise RuntimeError(_("Network error during token exchange")) from None

    for field in ("access_token", "refresh_token"):
        if field not in tokens:
            raise RuntimeError(_("Token exchange failed — missing tokens"))
    return tokens


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--client-id", required=True)
    parser.add_argument("--port", type=int, default=19847)
    args = parser.parse_args()

    code_verifier, code_challenge = generate_pkce()
    oauth_state = secrets.token_urlsafe(32)
    auth_code = None
    error = None

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            nonlocal auth_code, error
            params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)

            returned_state = params.get("state", [None])[0]
            if returned_state != oauth_state:
                error = _("Authorization failed (state mismatch) — please try again")
                self.send_response(400)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(callback_page(error))
                return

            if "code" in params:
                auth_code = params["code"][0]
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(callback_page(_("Authorization successful!"), _("You can close this tab.")))
            else:
                error = _("Authorization was denied")
                self.send_response(400)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(callback_page(error))

        def log_message(self, format, *a):
            pass  # suppress request logging

    port = args.port
    try:
        http.server.HTTPServer.allow_reuse_address = True
        server = http.server.HTTPServer(("127.0.0.1", port), Handler)
        server.timeout = 120  # handle_request() returns after this if no request arrives
    except OSError as e:
        json.dump({"error": _("Could not start authorization server on port %1").replace("%1", str(port))}, sys.stderr)
        sys.exit(1)
    redirect_uri = f"http://localhost:{port}/callback"

    scopes = "activity heartrate profile settings"
    authorize_url = (
        "https://www.fitbit.com/oauth2/authorize?"
        + urllib.parse.urlencode({
            "response_type": "code",
            "client_id": args.client_id,
            "redirect_uri": redirect_uri,
            "scope": scopes,
            "code_challenge": code_challenge,
            "code_challenge_method": "S256",
            "state": oauth_state,
        })
    )

    # Launch the browser with stderr/stdout suppressed so that Qt locale
    # warnings or other noise from the browser helper (xdg-open, kde-open5,
    # etc.) do not leak into the stderr that Plasma captures from this process.
    try:
        subprocess.Popen(
            ["xdg-open", authorize_url],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        webbrowser.open(authorize_url)
    # Serve exactly one request. server.timeout bounds the wait; if it elapses
    # with no request, handle_request() returns and auth_code stays None.
    server.handle_request()
    server.server_close()

    if error:
        json.dump({"error": error}, sys.stderr)
        sys.exit(1)

    if not auth_code:
        json.dump({"error": _("Authorization timed out — please try again")}, sys.stderr)
        sys.exit(1)

    try:
        tokens = exchange_token(auth_code, code_verifier, args.client_id, redirect_uri)
        json.dump({
            "access_token": tokens["access_token"],
            "refresh_token": tokens["refresh_token"],
            "expires_in": tokens.get("expires_in", 28800),
            "user_id": tokens.get("user_id", ""),
        }, sys.stdout)
    except Exception as e:
        message = str(e) if isinstance(e, RuntimeError) else _("Token exchange failed — invalid response")
        json.dump({"error": message}, sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
