"""Entry script for PyInstaller (it needs a file, not a -m module)."""

from sbe_modifier.app import main

raise SystemExit(main())
