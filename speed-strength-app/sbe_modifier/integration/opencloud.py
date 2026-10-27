"""Roblox Open Cloud Messaging Service integration (experiences you own).

Documented endpoint (Roblox creator-docs, "Messaging usage guide"):

    POST https://apis.roblox.com/cloud/v2/universes/{universe}:publishMessage
    x-api-key: <key with universe-messaging-service:publish>
    {"topic": "...", "message": "..."}      -> 200 with empty body

Roblox only lets the owner of an experience create this API key, and a server
script in that experience must subscribe to the topic and apply the values
(see src/ServerScriptService/SpeedStrengthBridge.server.lua). An HTTP 200 proves
Roblox accepted the message; it does not prove a server applied it.
"""

import json
import logging
import os
import urllib.error
import urllib.request

from sbe_modifier.integration.base import (
    ConnectionState,
    GameIntegration,
    IntegrationError,
    ModifierRequest,
    Outcome,
)
from sbe_modifier.settings import ValidationError, parse_id, parse_topic

log = logging.getLogger(__name__)

DEFAULT_BASE_URL = "https://apis.roblox.com"
# Points the client at another server, e.g. a local mock during testing.
BASE_URL_ENV = "SBE_OPENCLOUD_BASE_URL"
API_KEY_ENV = "SBE_OPENCLOUD_API_KEY"
MESSAGE_MAX_LEN = 1024  # MessagingService message size limit
PROTOCOL_VERSION = 1
TIMEOUT_SECONDS = 10

_HTTP_ERRORS = {
    400: "Roblox rejected the request as invalid (HTTP 400). Check the topic name.",
    401: "The API key is invalid or lacks the universe-messaging-service:publish permission (HTTP 401).",
    403: "Publishing is not allowed on this experience with this key (HTTP 403). "
    "The key must be created by the experience owner for this universe.",
    404: "Universe not found (HTTP 404). Check the Universe ID.",
    429: "Roblox rate limit reached (HTTP 429). Wait a minute and try again.",
}


class OpenCloudIntegration(GameIntegration):
    display_name = "Roblox Open Cloud — an experience you own"
    description = (
        "Sends your settings to live servers of an experience you own through Roblox's "
        "documented Open Cloud Messaging API. Requires the owner's API key and the "
        "SpeedStrengthBridge server script in that experience. This does not work for "
        "games owned by someone else, including the public Break and Steal an Egg."
    )
    needs_credentials = True

    def __init__(self, universe_id="", topic="", user_id="", api_key="", base_url=None):
        self.universe_id = universe_id
        self.topic = topic
        self.user_id = user_id
        self.api_key = api_key
        self.base_url = (base_url or os.environ.get(BASE_URL_ENV) or DEFAULT_BASE_URL).rstrip("/")
        if self.base_url != DEFAULT_BASE_URL:
            log.warning("Open Cloud requests go to non-default endpoint %s", self.base_url)

    # -- configuration -------------------------------------------------
    def missing_fields(self) -> list[str]:
        names = {
            "Universe ID": self.universe_id,
            "Topic": self.topic,
            "Target User ID": self.user_id,
            "API key": self.api_key,
        }
        return [name for name, value in names.items() if not str(value).strip()]

    def _validated(self) -> tuple[str, str, str, str]:
        missing = self.missing_fields()
        if missing:
            raise IntegrationError(
                "Not configured: enter " + ", ".join(missing) + ".", ConnectionState.NOT_CONFIGURED
            )
        try:
            universe = parse_id("Universe ID", self.universe_id)
            user = parse_id("Target User ID", self.user_id)
            topic = parse_topic(self.topic)
        except ValidationError as exc:
            raise IntegrationError(str(exc), ConnectionState.NOT_CONFIGURED) from exc
        return universe, topic, user, self.api_key.strip()

    def initial_state(self) -> Outcome:
        try:
            self._validated()
        except IntegrationError as exc:
            return Outcome(exc.state, str(exc))
        return Outcome(
            ConnectionState.CONFIGURED,
            "Credentials entered. Press Check Connection to verify them with Roblox." + self._endpoint_note(),
        )

    def _endpoint_note(self) -> str:
        return "" if self.base_url == DEFAULT_BASE_URL else f" [endpoint: {self.base_url}]"

    # -- protocol ------------------------------------------------------
    @staticmethod
    def build_message(kind: str, user_id: str | None = None, request: ModifierRequest | None = None) -> str:
        payload = {"v": PROTOCOL_VERSION, "type": kind}
        if user_id is not None:
            payload["userId"] = int(user_id)
        if request is not None:
            payload["speed"] = request.speed
            payload["strength"] = request.strength
        message = json.dumps(payload, separators=(",", ":"))
        if len(message) > MESSAGE_MAX_LEN:
            raise IntegrationError("Message exceeds the 1 KiB Messaging Service limit.")
        return message

    def _publish(self, message: str) -> None:
        universe, topic, _, api_key = self._validated()
        url = f"{self.base_url}/cloud/v2/universes/{universe}:publishMessage"
        body = json.dumps({"topic": topic, "message": message}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=body,
            method="POST",
            headers={"x-api-key": api_key, "Content-Type": "application/json"},
        )
        log.info("POST %s topic=%s message=%s", url, topic, message)
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
                status = resp.status
        except urllib.error.HTTPError as exc:
            detail = _HTTP_ERRORS.get(exc.code)
            if detail is None:
                detail = (
                    f"Roblox server error (HTTP {exc.code}). Try again later."
                    if exc.code >= 500
                    else f"Unexpected response from Roblox (HTTP {exc.code})."
                )
            log.error("Open Cloud publish failed: HTTP %s", exc.code)
            raise IntegrationError(detail) from exc
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            reason = getattr(exc, "reason", exc)
            log.error("Open Cloud unreachable: %s", reason)
            raise IntegrationError(
                f"Cannot reach Roblox Open Cloud ({reason}). Check your internet connection."
            ) from exc
        if status != 200:
            raise IntegrationError(f"Unexpected response from Roblox (HTTP {status}).")
        log.info("Open Cloud accepted message (HTTP 200)")

    # -- GameIntegration -----------------------------------------------
    def check_connection(self) -> Outcome:
        self._publish(self.build_message("ping"))
        return Outcome(
            ConnectionState.CONNECTED,
            "Roblox accepted the API key and Universe ID (HTTP 200)." + self._endpoint_note(),
        )

    def apply(self, request: ModifierRequest) -> Outcome:
        _, _, user_id, _ = self._validated()
        self._publish(self.build_message("apply", user_id, request))
        return Outcome(
            ConnectionState.CONNECTED,
            "Delivered to Roblox (HTTP 200). Live servers running SpeedStrengthBridge apply it "
            f"to user {user_id} if they are in a server; this app cannot see in-game values."
            + self._endpoint_note(),
        )
