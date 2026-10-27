import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


class MockOpenCloud:
    """Local stand-in for apis.roblox.com that records publishMessage calls."""

    def __init__(self):
        self.requests = []
        self.status = 200
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length)
                owner.requests.append(
                    {"path": self.path, "headers": {k.lower(): v for k, v in self.headers.items()},
                     "body": json.loads(body or b"{}")}
                )
                self.send_response(owner.status)
                self.send_header("Content-Length", "0")
                self.end_headers()

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


@pytest.fixture
def mock_cloud():
    server = MockOpenCloud()
    yield server
    server.close()


@pytest.fixture(autouse=True)
def isolated_home(tmp_path, monkeypatch):
    monkeypatch.setenv("SBE_MODIFIER_HOME", str(tmp_path / "home"))
    monkeypatch.delenv("SBE_OPENCLOUD_API_KEY", raising=False)
    monkeypatch.delenv("SBE_OPENCLOUD_BASE_URL", raising=False)
    return tmp_path / "home"
