"""Drives the real Tk window. Needs a display (on Linux CI: xvfb-run)."""

import json

import pytest

tk = pytest.importorskip("tkinter")

from sbe_modifier import paths  # noqa: E402
from sbe_modifier import settings as cfg  # noqa: E402
from sbe_modifier.integration import ConnectionState  # noqa: E402
from sbe_modifier.ui import SpeedMoneyApp  # noqa: E402


@pytest.fixture
def make_app():
    apps = []

    def factory(settings=None, warning=None, size="940x780"):
        try:
            root = tk.Tk()
        except tk.TclError as exc:
            pytest.skip(f"no display: {exc}")
        settings = settings or cfg.AppSettings()
        settings.window_geometry = size
        app = SpeedMoneyApp(root, settings, paths.settings_file(), None, warning)
        root.update()
        apps.append(app)
        return app

    yield factory
    for app in apps:
        if not app.closing:
            app.shutdown()


def drag(scale, fraction):
    """Press on the slider thumb and drag it to ``fraction`` of the width, like a user."""
    scale.update()
    x0, y0 = (int(float(c)) for c in scale.tk.splitlist(scale.tk.call(scale, "coords")))
    x = int(scale.winfo_width() * fraction)
    scale.event_generate("<Button-1>", x=x0, y=y0)
    scale.event_generate("<B1-Motion>", x=x, y=y0)
    scale.event_generate("<ButtonRelease-1>", x=x, y=y0)
    scale.update()


def test_window_renders_all_controls(make_app):
    app = make_app()
    assert app.root.title() == "Steal And Break Eggs — Speed & Money"
    for widget in (app.apply_button, app.reset_button, app.speed.scale, app.money.scale, app.speed.entry,
                   app.money.entry, app.speed.switch, app.money.switch, app.status_title, app.backend_box):
        assert widget.winfo_ismapped(), widget
    assert app.status_title.cget("text") == ConnectionState.UNAVAILABLE.value


def test_slider_updates_state_entry_and_label(make_app):
    app = make_app()
    app.speed.switch.focus_set()
    drag(app.speed.scale, 0.75)
    value = app.settings.speed_value
    assert value != cfg.SPEED.default and value > 100
    assert app.speed.entry_var.get() == str(value)
    assert app.speed.value_label.cget("text") == str(value)


def test_typing_updates_state_and_slider(make_app):
    app = make_app()
    app.speed.entry_var.set("150")
    app.root.update()
    assert app.settings.speed_value == 150
    assert int(app.speed.scale_var.get()) == 150
    assert app.speed.value_label.cget("text") == "150"


def test_money_typing_formats_and_moves_log_slider(make_app):
    app = make_app()
    app.money.entry_var.set("1,000,000")
    app.root.update()
    assert app.settings.money_value == 1_000_000
    assert app.money.value_label.cget("text") == "$1,000,000"
    assert app.money.from_slider(app.money.scale_var.get()) == 1_000_000
    position = app.money.scale_var.get()
    assert 600 < position < 700  # log scale: one million is about two thirds along


def test_money_slider_drag_reaches_small_and_large_amounts(make_app):
    app = make_app()
    drag(app.money.scale, 0.0)
    assert app.settings.money_value == 0
    drag(app.money.scale, 1.0)
    assert app.settings.money_value == 1_000_000_000
    drag(app.money.scale, 0.3)
    value = app.settings.money_value
    assert 0 < value < 1_000_000
    assert app.money.entry_var.get() == str(value)
    assert app.money.value_label.cget("text") == cfg.MONEY.display(value)


@pytest.mark.parametrize("bad", ["", "abc", "12.5", "-4", "5000"])
def test_invalid_input_rejected(make_app, bad):
    app = make_app()
    app.speed.entry_var.set("40")
    app.speed.entry_var.set(bad)
    app.root.update()
    assert app.settings.speed_value == 40  # last valid value kept
    assert app.speed.error.cget("text")
    assert str(app.speed.entry.cget("style")) == "Invalid.TEntry"
    assert app.apply_button.instate(["disabled"])
    app.apply()  # guarded even if invoked directly
    assert "Not applied" in app.notice.cget("text")
    app.speed.entry_var.set("41")
    app.root.update()
    assert not app.speed.error.cget("text") and app.apply_button.instate(["!disabled"])


def test_toggles_update_state(make_app):
    app = make_app()
    app.speed.switch.event_generate("<Button-1>", x=10, y=10)
    app.root.update()
    assert app.settings.speed_enabled is True
    assert app.speed.enabled_text.cget("text") == "ENABLED"
    # Key events go to the focused window; on Windows the test window must be
    # brought to the foreground first.
    app.root.focus_force()
    app.money.switch.focus_force()
    app.root.update()
    app.money.switch.event_generate("<space>")
    app.root.update()
    assert app.settings.money_enabled is True
    app.speed.switch.toggle()
    assert app.settings.speed_enabled is False
    assert app.current_request().speed is None


def test_reset_restores_defaults(make_app):
    app = make_app(cfg.AppSettings(speed_enabled=True, speed_value=99, money_enabled=True, money_value=77))
    app.money.entry_var.set("oops")
    app.reset()
    app.root.update()
    s = app.settings
    assert (s.speed_enabled, s.speed_value, s.money_enabled, s.money_value) == (False, 16, False, 0)
    assert app.speed.entry_var.get() == "16" and app.speed.value_label.cget("text") == "16"
    assert app.money.entry_var.get() == "0" and not app.money.error.cget("text")
    assert app.apply_button.instate(["!disabled"])
    assert "restored to defaults" in app.notice.cget("text")


def test_apply_on_public_game_shows_unavailable_error(make_app):
    app = make_app(cfg.AppSettings(speed_enabled=True, speed_value=30))
    app.apply()
    app.wait_idle()
    assert app.state is ConnectionState.UNAVAILABLE
    assert "nothing was changed in-game" in app.status_detail.cget("text")
    assert "failed" in app.notice.cget("text")


def test_open_cloud_apply_delivers_exact_values(make_app, mock_cloud, monkeypatch):
    monkeypatch.setenv("SBE_OPENCLOUD_BASE_URL", mock_cloud.url)
    app = make_app(cfg.AppSettings(backend=cfg.BACKEND_OPEN_CLOUD))
    assert app.state is ConnectionState.NOT_CONFIGURED
    app.cred_vars["universe_id"].set("555")
    app.cred_vars["target_user_id"].set("777")
    app.cred_vars["api_key"].set("k")
    assert app.state is ConnectionState.CONFIGURED

    app.check_connection()
    app.wait_idle()
    assert app.state is ConnectionState.CONNECTED

    app.speed.switch.toggle()
    app.speed.entry_var.set("64")
    app.money.entry_var.set("12")  # money stays disabled -> null (left unchanged)
    app.apply()
    assert app.state is ConnectionState.APPLYING and app.apply_button.instate(["disabled"])
    app.wait_idle()
    assert app.state is ConnectionState.CONNECTED
    sent = json.loads(mock_cloud.requests[-1]["body"]["message"])
    assert sent == {"v": 2, "type": "apply", "userId": 777, "speed": 64, "money": None}
    assert app.apply_button.instate(["!disabled"])


def test_open_cloud_error_is_displayed(make_app, mock_cloud, monkeypatch):
    monkeypatch.setenv("SBE_OPENCLOUD_BASE_URL", mock_cloud.url)
    mock_cloud.status = 401
    app = make_app(cfg.AppSettings(backend=cfg.BACKEND_OPEN_CLOUD, universe_id="1", target_user_id="2"))
    app.cred_vars["api_key"].set("bad")
    app.apply()
    app.wait_idle()
    assert app.state is ConnectionState.ERROR
    assert "API key" in app.status_detail.cget("text")


def test_settings_persist_across_restart(make_app):
    app = make_app()
    app.speed.switch.toggle()
    app.speed.entry_var.set("88")
    app.money.entry_var.set("321000")
    app.cred_vars["api_key"].set("must-not-be-saved")
    app.shutdown()
    saved = paths.settings_file().read_text()
    assert "must-not-be-saved" not in saved

    loaded, _ = cfg.load(paths.settings_file())
    app2 = make_app(loaded)
    assert app2.settings.speed_enabled is True and app2.settings.speed_value == 88
    assert app2.speed.entry_var.get() == "88" and app2.speed.value_label.cget("text") == "88"
    assert app2.money.value_label.cget("text") == "$321,000"


def test_startup_warning_shown(make_app):
    app = make_app(warning="Saved settings were unreadable")
    assert "unreadable" in app.notice.cget("text")


def test_layout_adapts_to_width(make_app):
    app = make_app(size="940x780")
    assert app._wide is True
    app.root.geometry("480x700")
    app.root.update()
    assert app._wide is False
    assert app.speed.frame.outer.grid_info()["row"] != app.money.frame.outer.grid_info()["row"]
