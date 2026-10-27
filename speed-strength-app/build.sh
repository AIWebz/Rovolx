#!/usr/bin/env bash
# Run the tests and build a one-file executable into dist/ with PyInstaller.
# UI tests need a display; on a headless Linux box install xvfb and they run under xvfb-run.
set -euo pipefail
cd "$(dirname "$0")"
fail() { echo "ERROR: $*" >&2; exit 1; }

[ -x .venv/bin/python ] || ./setup.sh --dev
.venv/bin/python -m pip install -q -r requirements-dev.txt || fail "installing build tools failed"

runner=()
if [ "$(uname)" = "Linux" ] && [ -z "${DISPLAY:-}" ]; then
  command -v xvfb-run >/dev/null || fail "no display and xvfb-run missing (sudo apt install xvfb)"
  runner=(xvfb-run -a)
fi
${runner[@]+"${runner[@]}"} .venv/bin/python -m pytest -q || fail "tests failed; not building"

rm -rf build dist
.venv/bin/python -m PyInstaller --noconfirm --distpath dist --workpath build packaging/sbe_speed_strength.spec \
  || fail "PyInstaller build failed"
echo "Built: $(ls -d dist/*)"
