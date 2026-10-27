import json

import pytest

from sbe_modifier import settings as cfg


@pytest.mark.parametrize("raw, expected", [("16", 16), (" 200 ", 200), ("0", 0), (42, 42), ("+5", 5)])
def test_speed_accepts_valid(raw, expected):
    assert cfg.parse_value(cfg.SPEED, raw) == expected


@pytest.mark.parametrize("raw", ["", "  ", "abc", "1.5", "-1", "201", "1e3", "0x10", True, "١٢"])
def test_speed_rejects_invalid(raw):
    with pytest.raises(cfg.ValidationError):
        cfg.parse_value(cfg.SPEED, raw)


@pytest.mark.parametrize("raw", ["0", "1001", "-3", "ten"])
def test_strength_rejects_invalid(raw):
    with pytest.raises(cfg.ValidationError):
        cfg.parse_value(cfg.STRENGTH, raw)


def test_error_message_names_range():
    with pytest.raises(cfg.ValidationError, match="0–200"):
        cfg.parse_value(cfg.SPEED, "999")


@pytest.mark.parametrize("raw", ["", "0", "-5", "12a", "1.0", "123456789012345678901"])
def test_parse_id_rejects(raw):
    with pytest.raises(cfg.ValidationError):
        cfg.parse_id("Universe ID", raw)


def test_parse_topic_limits():
    assert cfg.parse_topic(" t ") == "t"
    with pytest.raises(cfg.ValidationError):
        cfg.parse_topic("")
    with pytest.raises(cfg.ValidationError):
        cfg.parse_topic("x" * 81)


def test_save_load_roundtrip(tmp_path):
    path = tmp_path / "s.json"
    original = cfg.AppSettings(speed_enabled=True, speed_value=50, strength_enabled=True, strength_value=7,
                               backend=cfg.BACKEND_OPEN_CLOUD, universe_id="123", target_user_id="456")
    cfg.save(original, path)
    loaded, warning = cfg.load(path)
    assert warning is None
    assert loaded == original
    assert "api_key" not in json.loads(path.read_text())


def test_missing_file_gives_defaults(tmp_path):
    loaded, warning = cfg.load(tmp_path / "nope.json")
    assert loaded == cfg.AppSettings() and warning is None


def test_corrupt_file_is_backed_up(tmp_path):
    path = tmp_path / "s.json"
    path.write_text("{not json")
    loaded, warning = cfg.load(path)
    assert loaded == cfg.AppSettings()
    assert "unreadable" in warning
    assert (tmp_path / "s.corrupt.json").exists()


def test_invalid_stored_values_fall_back(tmp_path):
    path = tmp_path / "s.json"
    path.write_text(json.dumps({"speed_value": 9999, "strength_value": "x", "speed_enabled": "yes",
                                "backend": "hack", "topic": "", "unknown": 1}))
    loaded, _ = cfg.load(path)
    assert loaded.speed_value == cfg.SPEED.default
    assert loaded.strength_value == cfg.STRENGTH.default
    assert loaded.speed_enabled is False
    assert loaded.backend == cfg.BACKEND_UNSUPPORTED
    assert loaded.topic == cfg.DEFAULT_TOPIC


def test_reset_keeps_connection_settings():
    s = cfg.AppSettings(speed_enabled=True, speed_value=99, strength_enabled=True, strength_value=9,
                        universe_id="1", target_user_id="2", backend=cfg.BACKEND_OPEN_CLOUD)
    s.reset_modifiers()
    assert (s.speed_enabled, s.speed_value, s.strength_enabled, s.strength_value) == (False, 16, False, 1)
    assert (s.universe_id, s.target_user_id, s.backend) == ("1", "2", cfg.BACKEND_OPEN_CLOUD)


def test_empty_xdg_config_home_falls_back_to_home(monkeypatch, tmp_path):
    from pathlib import Path

    from sbe_modifier import paths
    monkeypatch.delenv("SBE_MODIFIER_HOME")
    monkeypatch.setenv("XDG_CONFIG_HOME", "")
    monkeypatch.setattr(Path, "home", staticmethod(lambda: tmp_path))
    monkeypatch.setattr("sys.platform", "linux")
    assert paths.data_dir() == tmp_path / ".config" / "sbe-speed-strength"
