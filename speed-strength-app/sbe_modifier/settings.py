"""Application state, validation rules and persistence.

This module has no UI or network code: the UI edits an ``AppSettings`` instance
and the integration layer reads it.
"""

import json
import logging
import os
import re
from dataclasses import asdict, dataclass, fields
from pathlib import Path

log = logging.getLogger(__name__)

SETTINGS_VERSION = 1


@dataclass(frozen=True)
class Limit:
    label: str
    minimum: int
    maximum: int
    default: int
    unit: str
    #: Slider spreads values logarithmically (useful for very wide ranges).
    log_slider: bool = False
    #: Shown before the value, e.g. "$".
    prefix: str = ""

    def display(self, value: int) -> str:
        return f"{self.prefix}{fmt(value)}"

    def describe(self) -> str:
        return f"{fmt(self.minimum)}–{fmt(self.maximum)} (default {fmt(self.default)})"


def fmt(value: int) -> str:
    return f"{value:,}"


# Roblox's default Humanoid.WalkSpeed is 16 studs/s. Money starts at 0 in the
# Money leaderstat created by StatCommands.server.lua.
SPEED = Limit("Speed", 0, 200, 16, "studs/s")
MONEY = Limit("Money", 0, 1_000_000_000, 0, "", log_slider=True, prefix="$")

BACKEND_UNSUPPORTED = "break_and_steal_an_egg"
BACKEND_OPEN_CLOUD = "open_cloud"
BACKENDS = (BACKEND_UNSUPPORTED, BACKEND_OPEN_CLOUD)

DEFAULT_TOPIC = "SBESpeedMoney"
TOPIC_MAX_LEN = 80  # Roblox MessagingService topic size limit
_ID_RE = re.compile(r"^[1-9][0-9]{0,19}$")


class ValidationError(ValueError):
    """Raised when a user-supplied value is not acceptable."""


def parse_value(limit: Limit, raw) -> int:
    """Return ``raw`` as an int inside ``limit`` or raise ValidationError."""
    if isinstance(raw, bool):
        raise ValidationError(f"{limit.label} must be a number.")
    if isinstance(raw, int):
        value = raw
    else:
        text = str(raw).strip()
        if not text:
            raise ValidationError(f"{limit.label} is empty. Enter a whole number {limit.describe()}.")
        if re.fullmatch(r"[0-9]{1,3}(,[0-9]{3})+", text):  # thousands separators, e.g. 1,000,000
            text = text.replace(",", "")
        if not re.fullmatch(r"[+-]?[0-9]+", text):
            raise ValidationError(f"{limit.label} must be a whole number, got {text!r}.")
        value = int(text)
    if not limit.minimum <= value <= limit.maximum:
        raise ValidationError(
            f"{limit.label} {fmt(value)} is out of range. Allowed: {fmt(limit.minimum)}–{fmt(limit.maximum)}."
        )
    return value


def parse_id(label: str, raw) -> str:
    text = str(raw).strip()
    if not _ID_RE.match(text):
        raise ValidationError(f"{label} must be a positive whole number (digits only).")
    return text


def parse_topic(raw) -> str:
    text = str(raw).strip()
    if not text:
        raise ValidationError("Topic is empty.")
    if len(text) > TOPIC_MAX_LEN:
        raise ValidationError(f"Topic is longer than {TOPIC_MAX_LEN} characters.")
    return text


@dataclass
class AppSettings:
    speed_enabled: bool = False
    speed_value: int = SPEED.default
    money_enabled: bool = False
    money_value: int = MONEY.default
    backend: str = BACKEND_UNSUPPORTED
    universe_id: str = ""
    topic: str = DEFAULT_TOPIC
    target_user_id: str = ""
    window_geometry: str = ""

    def reset_modifiers(self) -> None:
        """Restore Speed and Money to defaults; connection settings are kept."""
        self.speed_enabled = False
        self.speed_value = SPEED.default
        self.money_enabled = False
        self.money_value = MONEY.default

    @classmethod
    def from_dict(cls, data: dict) -> "AppSettings":
        """Build settings from stored data, replacing anything invalid with defaults."""
        settings = cls()
        known = {f.name for f in fields(cls)}
        for key, value in data.items():
            if key in known:
                setattr(settings, key, value)

        defaults = cls()
        checks = {
            "speed_value": lambda v: parse_value(SPEED, v),
            "money_value": lambda v: parse_value(MONEY, v),
            "topic": parse_topic,
        }
        for name, check in checks.items():
            try:
                setattr(settings, name, check(getattr(settings, name)))
            except (ValidationError, TypeError):
                log.warning("Stored %s is invalid; using default", name)
                setattr(settings, name, getattr(defaults, name))
        for name in ("speed_enabled", "money_enabled"):
            if not isinstance(getattr(settings, name), bool):
                setattr(settings, name, getattr(defaults, name))
        for name in ("universe_id", "target_user_id", "window_geometry"):
            if not isinstance(getattr(settings, name), str):
                setattr(settings, name, "")
        if settings.backend not in BACKENDS:
            settings.backend = defaults.backend
        return settings


def load(path: Path) -> tuple[AppSettings, str | None]:
    """Load settings. Returns (settings, warning) where warning is shown to the user."""
    if not path.exists():
        return AppSettings(), None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("settings root is not an object")
    except (OSError, ValueError) as exc:
        backup = path.with_suffix(".corrupt.json")
        try:
            os.replace(path, backup)
        except OSError:
            backup = None
        log.error("Could not read settings %s: %s", path, exc)
        note = f" A copy was kept at {backup}." if backup else ""
        return AppSettings(), f"Saved settings were unreadable and have been reset to defaults.{note}"
    data.pop("version", None)
    return AppSettings.from_dict(data), None


def save(settings: AppSettings, path: Path) -> None:
    """Write settings atomically. API keys are never part of AppSettings."""
    data = {"version": SETTINGS_VERSION, **asdict(settings)}
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.replace(tmp, path)
    log.info("Settings saved to %s", path)
