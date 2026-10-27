"""Per-user locations for settings and logs."""

import os
import sys
from pathlib import Path

from sbe_modifier import APP_ID

# Overrides the data directory (used by tests and portable installs).
HOME_ENV = "SBE_MODIFIER_HOME"


def data_dir() -> Path:
    override = os.environ.get(HOME_ENV)
    if override:
        base = Path(override)
    elif sys.platform == "win32":
        base = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming") / APP_ID
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / APP_ID
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "sbe-speed-strength"
    base.mkdir(parents=True, exist_ok=True)
    return base


def settings_file() -> Path:
    return data_dir() / "settings.json"


def log_dir() -> Path:
    path = data_dir() / "logs"
    path.mkdir(parents=True, exist_ok=True)
    return path
