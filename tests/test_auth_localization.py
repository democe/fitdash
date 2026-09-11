"""Run with python3 -m unittest discover -s tests."""

import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlparse


spec = importlib.util.spec_from_file_location(
    "fitdash_auth", Path(__file__).resolve().parents[1] / "scripts/fitdash-auth.py"
)
auth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auth)


class CallbackTests(unittest.TestCase):
    def run_callback(self, result):
        browser = {}
        response = {}

        class Server:
            def __init__(self, address, handler):
                self.handler = handler

            def handle_request(self):
                if result == "timeout":
                    return
                state = parse_qs(urlparse(browser["url"]).query)["state"][0]
                query = {
                    "success": "code=test&state=" + state,
                    "denied": "error=access_denied&state=" + state,
                    "mismatch": "code=test&state=wrong",
                }[result]
                handler = object.__new__(self.handler)
                handler.path = "/callback?" + query
                handler.wfile = io.BytesIO()
                handler.send_response = lambda status: response.update(status=status)
                handler.send_header = lambda key, value: response.update({key: value})
                handler.end_headers = lambda: None
                handler.do_GET()
                response["body"] = handler.wfile.getvalue().decode("utf-8")

            def server_close(self):
                pass

        def launch(args, **kwargs):
            browser["url"] = args[1]

        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(auth, "_", lambda text: "日本語 <&> " + text), \
                patch.object(auth.http.server, "HTTPServer", Server), \
                patch.object(auth.subprocess, "Popen", launch), \
                patch.object(auth, "exchange_token", return_value={
                    "access_token": "test", "refresh_token": "test"
                }) as exchange, \
                patch("sys.argv", ["fitdash-auth.py", "--client-id", "ABC"]), \
                patch("sys.stdout", stdout), patch("sys.stderr", stderr):
            if result == "success":
                auth.main()
                self.assertEqual(json.loads(stdout.getvalue())["access_token"], "test")
                exchange.assert_called_once()
            else:
                with self.assertRaises(SystemExit):
                    auth.main()
                self.assertTrue(json.loads(stderr.getvalue())["error"].startswith("日本語"))
                exchange.assert_not_called()
        return response

    def test_callback_pages_are_localized_utf8_and_escaped(self):
        for result, status in [("success", 200), ("denied", 400), ("mismatch", 400)]:
            with self.subTest(result=result):
                response = self.run_callback(result)
                self.assertEqual(response["status"], status)
                self.assertEqual(response["Content-Type"], "text/html; charset=utf-8")
                self.assertIn("日本語 &lt;&amp;&gt;", response["body"])
                self.assertIn('dir="auto"', response["body"])

    def test_timeout_is_localized(self):
        self.run_callback("timeout")


if __name__ == "__main__":
    unittest.main()
