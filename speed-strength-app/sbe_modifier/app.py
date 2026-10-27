"""Entry point: logging, settings, window, clean exit."""

import argparse
import logging
import logging.handlers
import signal
import sys

from sbe_modifier import APP_NAME, __version__, paths
from sbe_modifier import settings as cfg

log = logging.getLogger("sbe_modifier")


def setup_logging(debug: bool = False):
    log_path = paths.log_dir() / "app.log"
    handler = logging.handlers.RotatingFileHandler(log_path, maxBytes=1_000_000, backupCount=3, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)-7s %(name)s: %(message)s"))
    handlers = [handler]
    if sys.stderr is not None:  # None in windowed PyInstaller builds
        handlers.append(logging.StreamHandler())
    logging.basicConfig(level=logging.DEBUG if debug else logging.INFO, handlers=handlers, force=True)

    def excepthook(exc_type, exc, tb):
        log.critical("Unhandled exception", exc_info=(exc_type, exc, tb))

    sys.excepthook = excepthook
    return log_path


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="sbe-speed-money", description=APP_NAME)
    parser.add_argument("--version", action="version", version=__version__)
    parser.add_argument("--debug", action="store_true", help="verbose logging")
    parser.add_argument("--smoke-test", action="store_true",
                        help="open the window, render it, then exit (used by install checks)")
    args = parser.parse_args(argv)

    log_path = setup_logging(args.debug)
    log.info("Starting %s %s (Python %s, %s)", APP_NAME, __version__, sys.version.split()[0], sys.platform)

    try:
        import tkinter as tk
    except ImportError:
        log.critical("Tkinter is not installed")
        print("ERROR: Python's Tkinter GUI library is missing. See README > Troubleshooting.", file=sys.stderr)
        return 2

    from sbe_modifier.ui import SpeedMoneyApp

    settings_path = paths.settings_file()
    settings, warning = cfg.load(settings_path)
    try:
        root = tk.Tk()
    except tk.TclError as exc:
        log.critical("Cannot open a window: %s", exc)
        print(f"ERROR: cannot open a window ({exc}). Is a desktop session available?", file=sys.stderr)
        return 3

    app = SpeedMoneyApp(root, settings, settings_path, log_path, warning)
    if args.smoke_test:
        root.update()
        ok = root.winfo_viewable() and app.apply_button.winfo_ismapped()
        result = f"SMOKE TEST {'PASSED' if ok else 'FAILED'} - state: {app.state.value}"
        print(result)  # no console in the windowed .exe, so it is logged as well
        log.info(result)
        app.shutdown()
        return 0 if ok else 1

    # Save settings on SIGTERM/Ctrl+C too. The UI's poll loop gives Python a
    # chance to run the handler while Tk's mainloop is waiting.
    def on_signal(signum, _frame):
        log.info("Received signal %s", signum)
        root.after(0, app.shutdown)

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, on_signal)
    try:
        root.mainloop()
    except KeyboardInterrupt:
        app.shutdown()
    log.info("Exited cleanly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
