import json
import socket

import pytest

from sbe_modifier.integration import (
    ConnectionState,
    IntegrationError,
    ModifierRequest,
    OpenCloudIntegration,
    UnsupportedGameIntegration,
)


def make(mock, **overrides):
    args = {"universe_id": "987654", "topic": "SBESpeedMoney", "user_id": "1234", "api_key": "secret-key",
            "base_url": mock.url}
    args.update(overrides)
    return OpenCloudIntegration(**args)


def test_unsupported_game_never_reports_success():
    integ = UnsupportedGameIntegration()
    assert integ.initial_state().state is ConnectionState.UNAVAILABLE
    with pytest.raises(IntegrationError) as exc:
        integ.apply(ModifierRequest(speed=30, money=5))
    assert exc.value.state is ConnectionState.UNAVAILABLE
    with pytest.raises(IntegrationError):
        integ.check_connection()


def test_check_connection_publishes_ping(mock_cloud):
    outcome = make(mock_cloud).check_connection()
    assert outcome.state is ConnectionState.CONNECTED
    (req,) = mock_cloud.requests
    assert req["path"] == "/cloud/v2/universes/987654:publishMessage"
    assert req["headers"]["x-api-key"] == "secret-key"
    assert req["headers"]["content-type"] == "application/json"
    assert req["body"]["topic"] == "SBESpeedMoney"
    assert json.loads(req["body"]["message"]) == {"v": 2, "type": "ping"}


def test_apply_sends_values_and_nulls_for_disabled(mock_cloud):
    outcome = make(mock_cloud).apply(ModifierRequest(speed=48, money=None))
    assert outcome.state is ConnectionState.CONNECTED
    assert "cannot see in-game values" in outcome.message
    message = json.loads(mock_cloud.requests[0]["body"]["message"])
    assert message == {"v": 2, "type": "apply", "userId": 1234, "speed": 48, "money": None}


def test_apply_sends_large_money(mock_cloud):
    make(mock_cloud).apply(ModifierRequest(speed=None, money=1_000_000_000))
    message = json.loads(mock_cloud.requests[0]["body"]["message"])
    assert message["money"] == 1_000_000_000 and message["speed"] is None


@pytest.mark.parametrize("status, text", [(400, "invalid"), (401, "API key"), (403, "not allowed"),
                                          (404, "Universe ID"), (429, "rate limit"), (500, "server error"),
                                          (418, "Unexpected")])
def test_http_errors_are_reported(mock_cloud, status, text):
    mock_cloud.status = status
    with pytest.raises(IntegrationError, match=text) as exc:
        make(mock_cloud).apply(ModifierRequest(speed=20, money=2))
    assert exc.value.state is ConnectionState.ERROR


def test_unreachable_server_is_reported():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    integ = OpenCloudIntegration("1", "t", "2", "k", base_url=f"http://127.0.0.1:{port}")
    with pytest.raises(IntegrationError, match="Cannot reach"):
        integ.check_connection()


def test_missing_credentials_not_configured(mock_cloud):
    integ = make(mock_cloud, api_key="", user_id="")
    state = integ.initial_state()
    assert state.state is ConnectionState.NOT_CONFIGURED
    assert "Target User ID" in state.message and "API key" in state.message
    with pytest.raises(IntegrationError) as exc:
        integ.apply(ModifierRequest(16, 1))
    assert exc.value.state is ConnectionState.NOT_CONFIGURED
    assert mock_cloud.requests == []


def test_bad_ids_rejected_before_network(mock_cloud):
    with pytest.raises(IntegrationError, match="Universe ID"):
        make(mock_cloud, universe_id="abc").check_connection()
    assert mock_cloud.requests == []


def test_configured_state_mentions_custom_endpoint(mock_cloud):
    state = make(mock_cloud).initial_state()
    assert state.state is ConnectionState.CONFIGURED
    assert mock_cloud.url in state.message
