"""Main window. Owns no game logic: it edits AppSettings and calls a GameIntegration."""

import logging
import os
import queue
import threading
import tkinter as tk
from pathlib import Path
from tkinter import ttk

from sbe_modifier import APP_NAME, __version__
from sbe_modifier import settings as cfg
from sbe_modifier.integration import (
    REGISTRY,
    ConnectionState,
    GameIntegration,
    IntegrationError,
    ModifierRequest,
    OpenCloudIntegration,
    Outcome,
)
from sbe_modifier.integration.opencloud import API_KEY_ENV
from sbe_modifier.widgets import (
    AMBER,
    CARD,
    CARD_EDGE,
    GREEN,
    GREY,
    MUTED,
    RED,
    ScrollFrame,
    ToggleSwitch,
    apply_theme,
)

log = logging.getLogger(__name__)

STATE_COLORS = {
    ConnectionState.NOT_CONFIGURED: GREY,
    ConnectionState.CONFIGURED: AMBER,
    ConnectionState.CHECKING: AMBER,
    ConnectionState.APPLYING: AMBER,
    ConnectionState.CONNECTED: GREEN,
    ConnectionState.UNAVAILABLE: RED,
    ConnectionState.ERROR: RED,
}
WIDE_LAYOUT_MIN_WIDTH = 820
POLL_MS = 80


def wrap_to(label, container, pad: int = 0, minimum: int = 140) -> None:
    """Keep ``label``'s wraplength matched to ``container``'s current width."""
    container.bind("<Configure>", lambda e: label.configure(wraplength=max(minimum, e.width - pad)), add="+")


def card(master) -> ttk.Frame:
    frame = tk.Frame(master, bg=CARD, highlightthickness=1, highlightbackground=CARD_EDGE)
    inner = ttk.Frame(frame, style="Card.TFrame", padding=18)
    inner.pack(fill="both", expand=True)
    inner.outer = frame
    return inner


class ModifierCard:
    """Slider + numeric input + enable switch for one stat."""

    def __init__(self, master, limit: cfg.Limit, description: str, on_value, on_toggle):
        self.limit = limit
        self.on_value = on_value
        self.frame = card(master)
        f = self.frame
        f.columnconfigure(0, weight=1)

        head = ttk.Frame(f, style="Card.TFrame")
        head.grid(row=0, column=0, columnspan=3, sticky="ew")
        head.columnconfigure(0, weight=1)
        ttk.Label(head, text=limit.label, style="H2.TLabel").grid(row=0, column=0, sticky="w")
        self.enabled_text = ttk.Label(head, style="Muted.TLabel")
        self.enabled_text.grid(row=0, column=1, padx=(0, 8))
        self.enabled = tk.BooleanVar(f, value=False)
        self.switch = ToggleSwitch(head, self.enabled, command=on_toggle)
        self.switch.grid(row=0, column=2)
        self.description = ttk.Label(f, text=description, style="Muted.TLabel", justify="left")
        self.description.grid(row=1, column=0, columnspan=3, sticky="w", pady=(4, 14))

        self.scale_var = tk.DoubleVar(f, value=limit.default)
        self.scale = ttk.Scale(
            f,
            from_=limit.minimum,
            to=limit.maximum,
            variable=self.scale_var,
            orient="horizontal",
            command=self._on_scale,
        )
        self.scale.grid(row=2, column=0, sticky="ew", padx=(0, 14))
        self.value_label = ttk.Label(f, text=str(limit.default), style="Value.TLabel", width=5, anchor="e")
        self.value_label.grid(row=2, column=1, sticky="e")
        ttk.Label(f, text=limit.unit, style="Muted.TLabel", width=7).grid(row=2, column=2, sticky="w", padx=(4, 0))

        row = ttk.Frame(f, style="Card.TFrame")
        row.grid(row=3, column=0, columnspan=3, sticky="ew", pady=(14, 0))
        ttk.Label(row, text="Value", style="Card.TLabel").pack(side="left")
        self.entry_var = tk.StringVar(f, value=str(limit.default))
        self.entry = ttk.Entry(row, textvariable=self.entry_var, width=8, style="Dark.TEntry", justify="right")
        self.entry.pack(side="left", padx=(10, 10))
        ttk.Label(row, text=f"Allowed {limit.describe()}", style="Muted.TLabel").pack(side="left")
        self.entry_var.trace_add("write", lambda *_: self._on_entry())
        self.entry.bind("<Return>", lambda e: self._on_entry())
        self.entry.bind("<Up>", lambda e: self._nudge(1))
        self.entry.bind("<Down>", lambda e: self._nudge(-1))

        self.error = ttk.Label(f, text="", style="Error.TLabel")
        self.error.grid(row=4, column=0, columnspan=3, sticky="w", pady=(6, 0))
        wrap_to(self.description, f, 36)
        wrap_to(self.error, f, 36)
        self._syncing = False

    # Programmatic update (load/reset): no callbacks fire.
    def set(self, value: int, enabled: bool) -> None:
        self._syncing = True
        try:
            self.enabled.set(enabled)
            self.scale_var.set(value)
            self.entry_var.set(str(value))
        finally:
            self._syncing = False
        self.show_value(value)
        self.show_error(None)
        self.show_enabled(enabled)

    def show_value(self, value: int) -> None:
        self.value_label.configure(text=str(value))

    def show_enabled(self, enabled: bool) -> None:
        self.enabled_text.configure(text="ENABLED" if enabled else "DISABLED")
        self.value_label.configure(style="Value.TLabel" if enabled else "ValueOff.TLabel")

    def show_error(self, message: str | None) -> None:
        self.error.configure(text=message or "")
        self.entry.configure(style="Invalid.TEntry" if message else "Dark.TEntry")

    def _on_scale(self, _raw):
        if self._syncing:
            return
        value = int(round(self.scale_var.get()))
        self._syncing = True
        try:
            self.entry_var.set(str(value))
        finally:
            self._syncing = False
        self.on_value(value, None)

    def _on_entry(self):
        if self._syncing:
            return
        try:
            value = cfg.parse_value(self.limit, self.entry_var.get())
        except cfg.ValidationError as exc:
            self.on_value(None, str(exc))
            return
        self._syncing = True
        try:
            self.scale_var.set(value)
        finally:
            self._syncing = False
        self.on_value(value, None)

    def _nudge(self, step: int):
        try:
            value = cfg.parse_value(self.limit, self.entry_var.get())
        except cfg.ValidationError:
            return "break"
        value = min(self.limit.maximum, max(self.limit.minimum, value + step))
        self.entry_var.set(str(value))
        return "break"


class SpeedStrengthApp:
    def __init__(self, root: tk.Tk, settings: cfg.AppSettings, settings_path: Path, log_path: Path | None = None,
                 startup_warning: str | None = None):
        self.root = root
        self.settings = settings
        self.settings_path = settings_path
        self.invalid: dict[str, str] = {}
        self.integration: GameIntegration | None = None
        self.busy = False
        self.closing = False
        self.worker: threading.Thread | None = None
        self.results: queue.Queue = queue.Queue()
        self.state = ConnectionState.NOT_CONFIGURED
        self._loading = False

        root.title(APP_NAME)
        root.minsize(420, 520)
        root.geometry(settings.window_geometry or "940x780")
        self.fonts = apply_theme(root)
        root.protocol("WM_DELETE_WINDOW", self.shutdown)
        root.report_callback_exception = self._report_exception

        self._build(log_path)
        self._load_into_widgets()
        self._select_backend(settings.backend, initial=True)
        if startup_warning:
            self.notify(startup_warning, "error")
        self._poll_id = root.after(POLL_MS, self._poll)
        log.info("UI ready (version %s)", __version__)

    # ------------------------------------------------------------- layout
    def _build(self, log_path):
        root = self.root
        root.columnconfigure(0, weight=1)
        root.rowconfigure(0, weight=1)
        scroller = ScrollFrame(root)
        scroller.grid(row=0, column=0, sticky="nsew")
        page = scroller.body
        page.configure(padding=(24, 20))
        page.columnconfigure(0, weight=1)
        self.page = page

        header = ttk.Frame(page)
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)
        title = ttk.Label(header, text=APP_NAME, style="Title.TLabel")
        title.grid(row=0, column=0, sticky="w")
        wrap_to(title, header)
        ttk.Label(
            header,
            text=f"Target game: Break and Steal an Egg (Roblox)  ·  v{__version__}",
            style="PageMuted.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(2, 0))

        # Status
        status = card(page)
        status.outer.grid(row=1, column=0, sticky="ew", pady=(18, 0))
        status.columnconfigure(1, weight=1)
        self.status_dot = tk.Canvas(status, width=16, height=16, bg=CARD, highlightthickness=0)
        self.status_dot.grid(row=0, column=0, padx=(0, 10))
        self.status_title = ttk.Label(status, text="", style="H2.TLabel")
        self.status_title.grid(row=0, column=1, sticky="w")
        self.status_detail = ttk.Label(status, text="", style="Card.TLabel", justify="left")
        self.status_detail.grid(row=1, column=1, sticky="w", pady=(4, 0))
        wrap_to(self.status_detail, status, 36 + 26)

        # Integration
        integ = card(page)
        integ.outer.grid(row=2, column=0, sticky="ew", pady=(14, 0))
        integ.columnconfigure(0, weight=1)
        ttk.Label(integ, text="Game integration", style="H2.TLabel").grid(row=0, column=0, sticky="w")
        self.backend_keys = list(REGISTRY)
        self.backend_var = tk.StringVar(integ)
        self.backend_box = ttk.Combobox(
            integ,
            textvariable=self.backend_var,
            values=[REGISTRY[k].display_name for k in self.backend_keys],
            state="readonly",
            style="Dark.TCombobox",
        )
        self.backend_box.grid(row=1, column=0, sticky="ew", pady=(10, 6))
        self.backend_box.bind("<<ComboboxSelected>>", self._on_backend_picked)
        self.backend_desc = ttk.Label(integ, text="", style="Muted.TLabel", justify="left")
        self.backend_desc.grid(row=2, column=0, sticky="w")
        wrap_to(self.backend_desc, integ, 36)

        self.cred_frame = ttk.Frame(integ, style="Card.TFrame")
        self.cred_frame.grid(row=3, column=0, sticky="ew", pady=(12, 0))
        self.cred_vars = {}
        self.cred_entries = {}
        fields_ = (
            ("universe_id", "Universe ID", False),
            ("topic", "Topic", False),
            ("target_user_id", "Target User ID", False),
            ("api_key", "API key (never saved to disk)", True),
        )
        for i, (key, label, secret) in enumerate(fields_):
            col = (i % 2) * 2
            r = i // 2
            ttk.Label(self.cred_frame, text=label, style="Muted.TLabel").grid(
                row=r * 2, column=col, sticky="w", padx=(0, 12), pady=(6, 2)
            )
            var = tk.StringVar(self.cred_frame)
            entry = ttk.Entry(self.cred_frame, textvariable=var, width=12, style="Dark.TEntry",
                              show="•" if secret else "")
            entry.grid(row=r * 2 + 1, column=col, sticky="ew", padx=(0, 12))
            var.trace_add("write", lambda *_: self._on_credentials_changed())
            self.cred_vars[key] = var
            self.cred_entries[key] = entry
        self.cred_frame.columnconfigure(0, weight=1)
        self.cred_frame.columnconfigure(2, weight=1)
        self.check_button = ttk.Button(
            self.cred_frame, text="Check Connection", style="Ghost.TButton", command=self.check_connection
        )
        self.check_button.grid(row=4, column=0, sticky="w", pady=(14, 0))

        # Modifiers
        self.mods = ttk.Frame(page)
        self.mods.grid(row=3, column=0, sticky="ew", pady=(14, 0))
        self.speed = ModifierCard(
            self.mods,
            cfg.SPEED,
            "Player movement speed (Humanoid.WalkSpeed). Roblox default is 16.",
            lambda v, e: self._on_value("speed", v, e),
            lambda: self._on_toggle("speed"),
        )
        self.strength = ModifierCard(
            self.mods,
            cfg.STRENGTH,
            "Player Strength stat, as defined by the receiving game script.",
            lambda v, e: self._on_value("strength", v, e),
            lambda: self._on_toggle("strength"),
        )
        self._wide = None

        # Actions
        actions = ttk.Frame(page)
        actions.grid(row=4, column=0, sticky="ew", pady=(18, 0))
        actions.columnconfigure(0, weight=1)
        self.notice = ttk.Label(actions, text="", style="PageMuted.TLabel", justify="left")
        self.notice.grid(row=0, column=0, sticky="w")
        wrap_to(self.notice, actions, 330)
        self.reset_button = ttk.Button(actions, text="Reset to Default", style="Ghost.TButton", command=self.reset)
        self.reset_button.grid(row=0, column=1, padx=(12, 10))
        self.apply_button = ttk.Button(actions, text="Apply Changes", style="Accent.TButton", command=self.apply)
        self.apply_button.grid(row=0, column=2)

        where = f"Settings: {self.settings_path}"
        if log_path:
            where += f"\nLog: {log_path}"
        self.footer = ttk.Label(page, text=where, style="PageMuted.TLabel", justify="left")
        self.footer.grid(row=5, column=0, sticky="w", pady=(18, 0))
        wrap_to(self.footer, page, 48)

        root.bind("<Configure>", self._on_resize, add="+")
        self._relayout(root.winfo_width() if root.winfo_width() > 1 else 940)

    def _on_resize(self, event):
        if event.widget is self.root:
            self._relayout(event.width)

    def _relayout(self, width: int):
        wide = width >= WIDE_LAYOUT_MIN_WIDTH
        if wide == self._wide:
            return
        self._wide = wide
        self.speed.frame.outer.grid_forget()
        self.strength.frame.outer.grid_forget()
        if wide:
            self.mods.columnconfigure(0, weight=1, uniform="mods")
            self.mods.columnconfigure(1, weight=1, uniform="mods")
            self.speed.frame.outer.grid(row=0, column=0, sticky="nsew", padx=(0, 7))
            self.strength.frame.outer.grid(row=0, column=1, sticky="nsew", padx=(7, 0))
        else:
            self.mods.columnconfigure(0, weight=1, uniform="")
            self.mods.columnconfigure(1, weight=0, uniform="")
            self.speed.frame.outer.grid(row=0, column=0, sticky="ew")
            self.strength.frame.outer.grid(row=1, column=0, sticky="ew", pady=(14, 0))

    # -------------------------------------------------------------- state
    def _load_into_widgets(self):
        s = self.settings
        self.speed.set(s.speed_value, s.speed_enabled)
        self.strength.set(s.strength_value, s.strength_enabled)
        self._loading = True  # each set() would otherwise copy half-filled fields back
        try:
            self.cred_vars["universe_id"].set(s.universe_id)
            self.cred_vars["topic"].set(s.topic)
            self.cred_vars["target_user_id"].set(s.target_user_id)
            self.cred_vars["api_key"].set(os.environ.get(API_KEY_ENV, ""))
        finally:
            self._loading = False

    def _on_value(self, kind: str, value: int | None, error: str | None):
        widget = self.speed if kind == "speed" else self.strength
        if error:
            self.invalid[kind] = error
            widget.show_error(error)
        else:
            self.invalid.pop(kind, None)
            setattr(self.settings, f"{kind}_value", value)
            widget.show_error(None)
            widget.show_value(value)
        self._refresh_buttons()

    def _on_toggle(self, kind: str):
        widget = self.speed if kind == "speed" else self.strength
        enabled = bool(widget.enabled.get())
        setattr(self.settings, f"{kind}_enabled", enabled)
        widget.show_enabled(enabled)
        log.info("%s modifier %s", kind, "enabled" if enabled else "disabled")

    def _on_backend_picked(self, _event=None):
        index = self.backend_box.current()
        self._select_backend(self.backend_keys[index])
        self._save()

    def _select_backend(self, key: str, initial: bool = False):
        if self.integration:
            self.integration.close()
        self.settings.backend = key
        cls = REGISTRY[key]
        self.backend_box.current(self.backend_keys.index(key))
        self.backend_desc.configure(text=cls.description)
        if cls.needs_credentials:
            self.cred_frame.grid()
            self.integration = OpenCloudIntegration(**self._credential_values())
        else:
            self.cred_frame.grid_remove()
            self.integration = cls()
        log.info("Integration selected: %s", key)
        self._show_outcome(self.integration.initial_state())

    def _credential_values(self) -> dict:
        v = {k: var.get().strip() for k, var in self.cred_vars.items()}
        return {"universe_id": v["universe_id"], "topic": v["topic"], "user_id": v["target_user_id"],
                "api_key": v["api_key"]}

    def _on_credentials_changed(self):
        if self._loading:
            return
        vals = self._credential_values()
        self.settings.universe_id = vals["universe_id"]
        self.settings.topic = vals["topic"] or cfg.DEFAULT_TOPIC
        self.settings.target_user_id = vals["user_id"]
        if isinstance(self.integration, OpenCloudIntegration) and not self.busy:
            for name, value in vals.items():
                setattr(self.integration, name, value)
            self._show_outcome(self.integration.initial_state())

    def _refresh_buttons(self):
        idle = "disabled" if self.busy else "!disabled"
        self.reset_button.state([idle])
        self.check_button.state([idle])
        self.backend_box.state(["disabled" if self.busy else "!disabled", "readonly"])
        self.apply_button.state(["disabled" if self.busy or self.invalid else "!disabled"])

    def _show_outcome(self, outcome: Outcome):
        self.state = outcome.state
        color = STATE_COLORS[outcome.state]
        self.status_dot.delete("all")
        self.status_dot.create_oval(2, 2, 14, 14, fill=color, outline=color)
        self.status_title.configure(text=outcome.state.value, foreground=color)
        self.status_detail.configure(text=outcome.message)

    def notify(self, message: str, level: str = "info"):
        colors = {"info": MUTED, "ok": GREEN, "error": RED}
        self.notice.configure(text=message, foreground=colors[level])

    # ------------------------------------------------------------ actions
    def current_request(self) -> ModifierRequest:
        s = self.settings
        return ModifierRequest(
            speed=s.speed_value if s.speed_enabled else None,
            strength=s.strength_value if s.strength_enabled else None,
        )

    def apply(self):
        if self.busy:
            return
        if self.invalid:
            message = "Not applied: " + " ".join(self.invalid.values())
            self.notify(message, "error")
            log.warning(message)
            return
        self._save()
        request = self.current_request()
        log.info("Apply requested: %s", request)
        self._start(ConnectionState.APPLYING, "Sending settings…", lambda: self.integration.apply(request), "apply")

    def check_connection(self):
        if self.busy:
            return
        self._start(ConnectionState.CHECKING, "Contacting Roblox Open Cloud…", self.integration.check_connection,
                    "check")

    def reset(self):
        if self.busy:
            return
        self.settings.reset_modifiers()
        self.invalid.clear()
        self.speed.set(self.settings.speed_value, self.settings.speed_enabled)
        self.strength.set(self.settings.strength_value, self.settings.strength_enabled)
        self._refresh_buttons()
        self._save()
        log.info("Modifiers reset to defaults")
        self.notify("Speed and Strength restored to defaults. Press Apply Changes to send them.", "info")

    def _start(self, state: ConnectionState, text: str, job, kind: str):
        self.busy = True
        self._refresh_buttons()
        self._show_outcome(Outcome(state, text))
        self.notify("")

        def run():
            try:
                result = job()
            except IntegrationError as exc:
                result = exc
            except Exception as exc:  # noqa: BLE001 - surfaced to the user and logged
                log.exception("Integration crashed")
                result = IntegrationError(f"Unexpected error: {exc}")
            self.results.put((kind, result))

        self.worker = threading.Thread(target=run, name=f"integration-{kind}", daemon=True)
        self.worker.start()

    def _drain(self):
        try:
            while True:
                kind, result = self.results.get_nowait()
                self._finish(kind, result)
        except queue.Empty:
            pass

    def _poll(self):
        self._drain()
        if not self.closing:
            self._poll_id = self.root.after(POLL_MS, self._poll)

    def _finish(self, kind: str, result):
        self.busy = False
        self._refresh_buttons()
        if isinstance(result, IntegrationError):
            self._show_outcome(Outcome(result.state, str(result)))
            verb = "Apply" if kind == "apply" else "Connection check"
            self.notify(f"{verb} failed. See status above.", "error")
            log.warning("%s failed: %s", kind, result)
        else:
            self._show_outcome(result)
            self.notify("Settings delivered." if kind == "apply" else "Connection verified.", "ok")
            log.info("%s succeeded: %s", kind, result.message)

    def wait_idle(self, timeout: float = 15.0) -> None:
        """Block until the current integration job is done and its result shown (tests)."""
        if self.worker:
            self.worker.join(timeout)
        self.root.update()
        self._drain()

    # ------------------------------------------------------------ lifecycle
    def _save(self):
        try:
            cfg.save(self.settings, self.settings_path)
        except OSError as exc:
            log.error("Saving settings failed: %s", exc)
            self.notify(f"Could not save settings: {exc}", "error")

    def _report_exception(self, exc_type, exc, tb):
        log.error("Unhandled UI error", exc_info=(exc_type, exc, tb))
        self.notify(f"Internal error: {exc}. Details are in the log file.", "error")

    def shutdown(self):
        if self.closing:
            return
        self.closing = True
        log.info("Shutting down")
        try:
            self.root.after_cancel(self._poll_id)
        except (tk.TclError, ValueError):
            pass
        if self.worker and self.worker.is_alive():
            log.info("Waiting for in-flight request to finish")
            self.worker.join(timeout=3)
        if self.root.winfo_exists() and self.root.state() == "normal":
            self.settings.window_geometry = self.root.geometry()
        self._save()
        if self.integration:
            self.integration.close()
        self.root.destroy()
