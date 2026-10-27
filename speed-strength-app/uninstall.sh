#!/usr/bin/env bash
# Remove the virtual environment, build output and launcher.
#   ./uninstall.sh          keep saved settings and logs
#   ./uninstall.sh --purge  also delete settings and logs
set -euo pipefail
cd "$(dirname "$0")"
rm -rf .venv build dist ./*.egg-info .pytest_cache
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/sbe-speed-strength.desktop"
if [ "${1:-}" = "--purge" ]; then
  if [ "$(uname)" = "Darwin" ]; then data="$HOME/Library/Application Support/SBESpeedStrength"
  else data="${XDG_CONFIG_HOME:-$HOME/.config}/sbe-speed-strength"; fi
  rm -rf "$data" && echo "Deleted $data"
fi
echo "Uninstalled. You can now delete this folder."
