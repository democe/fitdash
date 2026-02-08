#!/usr/bin/env python3
"""OAuth 2.0 PKCE helper for FitDash. Outputs tokens JSON to stdout."""

import argparse
import base64
import hashlib
import http.server
import json
import os
import secrets
import socket
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request
import webbrowser


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
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Token exchange failed (HTTP {e.code}): {body}") from None
    except urllib.error.URLError as e:
        raise RuntimeError(f"Network error during token exchange: {e.reason}") from None

    for field in ("access_token", "refresh_token"):
        if field not in tokens:
            raise RuntimeError(f"Token response missing required field: {field}")
    return tokens


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--client-id", required=True)
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
                error = "state_mismatch"
                self.send_response(400)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<html><body><h1>Authorization failed (state mismatch).</h1></body></html>")
                return

            if "code" in params:
                auth_code = params["code"][0]
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<html><body><h1>Authorization successful!</h1>"
                                 b"<p>You can close this tab.</p></body></html>")
            else:
                error = params.get("error", ["unknown"])[0]
                self.send_response(400)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<html><body><h1>Authorization failed.</h1></body></html>")

        def log_message(self, format, *a):
            pass  # suppress request logging

    port = 19847
    try:
        http.server.HTTPServer.allow_reuse_address = True
        server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    except OSError as e:
        json.dump({"error": f"Could not start auth server on port {port}: {e}"}, sys.stderr)
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

    # Shut down server after timeout
    timer = threading.Timer(120.0, server.shutdown)
    timer.daemon = True
    timer.start()

    webbrowser.open(authorize_url)
    server.handle_request()  # serve exactly one request
    server.server_close()
    timer.cancel()

    if error:
        json.dump({"error": error}, sys.stderr)
        sys.exit(1)

    if not auth_code:
        json.dump({"error": "timeout"}, sys.stderr)
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
        json.dump({"error": str(e)}, sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
