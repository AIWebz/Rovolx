# PyInstaller spec: one-file windowed executable.
# Build with build.ps1 (Windows) or build.sh (macOS/Linux).
import sys
from pathlib import Path

root = Path(SPECPATH).parent

a = Analysis(
    [str(root / "packaging" / "launcher.py")],
    pathex=[str(root)],
    hiddenimports=["tkinter", "tkinter.ttk", "tkinter.font"],
    excludes=["pytest"],
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    name="SBESpeedStrength",
    console=False,
    upx=False,
)
if sys.platform == "darwin":
    app = BUNDLE(exe, name="SBESpeedStrength.app", bundle_identifier="com.sbe.speedstrength")
