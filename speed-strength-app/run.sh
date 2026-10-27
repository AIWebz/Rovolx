#!/usr/bin/env bash
# Launch the app installed by setup.sh.
set -euo pipefail
cd "$(dirname "$0")"
[ -x .venv/bin/python ] || { echo "ERROR: not installed. Run ./setup.sh first." >&2; exit 1; }
exec .venv/bin/python -m sbe_modifier "$@"
