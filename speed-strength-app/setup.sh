#!/usr/bin/env bash
# One-step install for macOS/Linux: creates .venv, installs the app, adds a
# desktop launcher (Linux) and runs a launch smoke test.
#   ./setup.sh          install
#   ./setup.sh --dev    also install test/build tools
set -euo pipefail
cd "$(dirname "$0")"
APP_DIR="$(pwd)"

fail() { echo "ERROR: $*" >&2; exit 1; }

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
  for candidate in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1 &&
       "$candidate" -c 'import sys, tkinter; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
      PYTHON="$candidate"; break
    fi
  done
fi
if [ -z "$PYTHON" ]; then
  fail "Python 3.10+ with Tkinter not found.
  Ubuntu/Debian: sudo apt install python3 python3-venv python3-tk
  Fedora:        sudo dnf install python3 python3-tkinter
  macOS:         brew install python-tk   (or the python.org installer)
  Or set PYTHON=/path/to/python3 and re-run."
fi
echo "Using $("$PYTHON" --version) at $(command -v "$PYTHON")"

"$PYTHON" -m venv .venv || fail "could not create virtual environment (install python3-venv)"
.venv/bin/python -m pip install --upgrade pip >/dev/null || fail "pip upgrade failed"
.venv/bin/python -m pip install . || fail "installing the app failed"
if [ "${1:-}" = "--dev" ]; then
  .venv/bin/python -m pip install -r requirements-dev.txt || fail "installing dev tools failed"
fi

if [ "$(uname)" = "Linux" ]; then
  apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$apps"
  cat > "$apps/sbe-speed-strength.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Steal And Break Eggs — Speed & Money
Exec="$APP_DIR/run.sh"
Terminal=false
Categories=Game;Utility;
DESKTOP
  echo "Added launcher: $apps/sbe-speed-strength.desktop"
fi

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ "$(uname)" = "Darwin" ]; then
  .venv/bin/python -m sbe_modifier --smoke-test || fail "launch smoke test failed (see log path in README)"
else
  echo "No display detected; skipped launch smoke test."
fi
echo "Installed. Start with: ./run.sh"
