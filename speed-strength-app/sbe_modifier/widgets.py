"""Themed Tk widgets: palette, toggle switch and a scrollable container."""

import sys
import tkinter as tk
from tkinter import font as tkfont
from tkinter import ttk

BG = "#0d0f14"
CARD = "#161a23"
CARD_EDGE = "#262c3a"
INPUT = "#0f1219"
TEXT = "#e7eaf3"
MUTED = "#8a93a8"
ACCENT = "#ffb020"
ACCENT_HOVER = "#ffc34d"
ACCENT_TEXT = "#1a1300"
GREEN = "#38d67a"
RED = "#ff5d5d"
AMBER = "#ffb020"
GREY = "#5c6478"
TRACK_OFF = "#2b3140"


def pick_family(root: tk.Misc) -> str:
    available = set(tkfont.families(root))
    for family in ("Segoe UI", "SF Pro Text", "Helvetica Neue", "Inter", "Cantarell", "DejaVu Sans"):
        if family in available:
            return family
    return tkfont.nametofont("TkDefaultFont").actual("family")


def apply_theme(root: tk.Tk) -> dict:
    """Configure ttk styles and return the named fonts used by the UI."""
    family = pick_family(root)
    fonts = {
        "title": tkfont.Font(root, family=family, size=18, weight="bold"),
        "h2": tkfont.Font(root, family=family, size=13, weight="bold"),
        "body": tkfont.Font(root, family=family, size=10),
        "small": tkfont.Font(root, family=family, size=9),
        "value": tkfont.Font(root, family=family, size=20, weight="bold"),
        "button": tkfont.Font(root, family=family, size=10, weight="bold"),
    }
    root.configure(bg=BG)
    root.option_add("*TCombobox*Listbox.background", INPUT)
    root.option_add("*TCombobox*Listbox.foreground", TEXT)
    root.option_add("*TCombobox*Listbox.selectBackground", ACCENT)
    root.option_add("*TCombobox*Listbox.selectForeground", ACCENT_TEXT)
    root.option_add("*TCombobox*Listbox.font", fonts["body"])

    style = ttk.Style(root)
    style.theme_use("clam")
    style.configure(".", background=BG, foreground=TEXT, font=fonts["body"])
    style.configure("TFrame", background=BG)
    style.configure("Card.TFrame", background=CARD)
    style.configure("TLabel", background=BG, foreground=TEXT)
    style.configure("Card.TLabel", background=CARD, foreground=TEXT)
    style.configure("Muted.TLabel", background=CARD, foreground=MUTED, font=fonts["small"])
    style.configure("PageMuted.TLabel", background=BG, foreground=MUTED, font=fonts["small"])
    style.configure("Title.TLabel", background=BG, foreground=TEXT, font=fonts["title"])
    style.configure("H2.TLabel", background=CARD, foreground=TEXT, font=fonts["h2"])
    style.configure("Value.TLabel", background=CARD, foreground=ACCENT, font=fonts["value"])
    style.configure("ValueOff.TLabel", background=CARD, foreground=GREY, font=fonts["value"])
    style.configure("Error.TLabel", background=CARD, foreground=RED, font=fonts["small"])

    for name, edge in (("Dark.TEntry", CARD_EDGE), ("Invalid.TEntry", RED)):
        style.configure(
            name,
            fieldbackground=INPUT,
            foreground=TEXT,
            insertcolor=TEXT,
            bordercolor=edge,
            lightcolor=edge,
            darkcolor=edge,
            padding=6,
        )
        style.map(name, bordercolor=[("focus", ACCENT if edge == CARD_EDGE else RED)])

    style.configure(
        "Dark.TCombobox",
        fieldbackground=INPUT,
        background=CARD_EDGE,
        foreground=TEXT,
        arrowcolor=TEXT,
        bordercolor=CARD_EDGE,
        lightcolor=CARD_EDGE,
        darkcolor=CARD_EDGE,
        padding=6,
    )
    style.map(
        "Dark.TCombobox",
        fieldbackground=[("readonly", INPUT)],
        foreground=[("readonly", TEXT)],
        selectbackground=[("readonly", INPUT)],
        selectforeground=[("readonly", TEXT)],
    )

    style.configure(
        "Horizontal.TScale",
        background=ACCENT,
        troughcolor=TRACK_OFF,
        bordercolor=CARD,
        lightcolor=ACCENT,
        darkcolor=ACCENT,
        sliderlength=22,
        sliderthickness=18,
    )
    style.map("Horizontal.TScale", background=[("active", ACCENT_HOVER), ("disabled", GREY)])

    style.configure(
        "Accent.TButton",
        background=ACCENT,
        foreground=ACCENT_TEXT,
        font=fonts["button"],
        bordercolor=ACCENT,
        lightcolor=ACCENT,
        darkcolor=ACCENT,
        focuscolor=ACCENT_TEXT,
        padding=(18, 10),
    )
    style.map(
        "Accent.TButton",
        background=[("disabled", GREY), ("pressed", ACCENT), ("active", ACCENT_HOVER)],
        foreground=[("disabled", "#2a2f3a")],
    )
    style.configure(
        "Ghost.TButton",
        background=CARD,
        foreground=TEXT,
        font=fonts["button"],
        bordercolor=CARD_EDGE,
        lightcolor=CARD,
        darkcolor=CARD,
        focuscolor=TEXT,
        padding=(18, 10),
    )
    style.map(
        "Ghost.TButton",
        background=[("disabled", CARD), ("active", CARD_EDGE)],
        foreground=[("disabled", GREY)],
    )
    style.configure("Vertical.TScrollbar", background=CARD, troughcolor=BG, bordercolor=BG, arrowcolor=MUTED)
    return fonts


class ToggleSwitch(tk.Canvas):
    """Pill-shaped on/off switch bound to a BooleanVar. Keyboard: Space/Enter."""

    W, H = 48, 26

    def __init__(self, master, variable: tk.BooleanVar, command=None, bg=CARD):
        super().__init__(
            master,
            width=self.W,
            height=self.H,
            bg=bg,
            highlightthickness=2,
            highlightbackground=bg,
            highlightcolor=ACCENT,
            bd=0,
            takefocus=1,
            cursor="hand2",
        )
        self.variable = variable
        self.command = command
        self.bind("<Button-1>", self._on_click)
        self.bind("<space>", self._on_click)
        self.bind("<Return>", self._on_click)
        self._trace = variable.trace_add("write", lambda *_: self._draw())
        self._draw()

    def toggle(self) -> None:
        self.variable.set(not self.variable.get())
        if self.command:
            self.command()

    def _on_click(self, _event=None):
        self.focus_set()
        self.toggle()
        return "break"

    def _draw(self) -> None:
        self.delete("all")
        on = bool(self.variable.get())
        w, h, r = self.W, self.H, self.H // 2
        color = ACCENT if on else TRACK_OFF
        self.create_oval(0, 0, h, h, fill=color, outline=color)
        self.create_oval(w - h, 0, w, h, fill=color, outline=color)
        self.create_rectangle(r, 0, w - r, h, fill=color, outline=color)
        x = w - h + 3 if on else 3
        self.create_oval(x, 3, x + h - 6, h - 3, fill="#ffffff" if on else MUTED, outline="")

    def destroy(self):
        try:
            self.variable.trace_remove("write", self._trace)
        except tk.TclError:
            pass
        super().destroy()


class ScrollFrame(ttk.Frame):
    """Vertically scrollable area; ``self.body`` is the frame to fill."""

    def __init__(self, master):
        super().__init__(master)
        self.canvas = tk.Canvas(self, bg=BG, highlightthickness=0, bd=0)
        self.scrollbar = ttk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        self.body = ttk.Frame(self.canvas)
        self._window = self.canvas.create_window((0, 0), window=self.body, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.grid(row=0, column=0, sticky="nsew")
        self.scrollbar.grid(row=0, column=1, sticky="ns")
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)
        self.body.bind("<Configure>", self._sync)
        self.canvas.bind("<Configure>", self._sync)
        self.canvas.bind_all("<MouseWheel>", self._on_wheel, add="+")
        self.canvas.bind_all("<Button-4>", lambda e: self._scroll(-1), add="+")
        self.canvas.bind_all("<Button-5>", lambda e: self._scroll(1), add="+")

    def _sync(self, _event=None):
        self.canvas.itemconfigure(self._window, width=self.canvas.winfo_width())
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))
        needs_bar = self.body.winfo_reqheight() > self.canvas.winfo_height()
        if needs_bar and not self.scrollbar.winfo_ismapped():
            self.scrollbar.grid()
        elif not needs_bar and self.scrollbar.winfo_ismapped():
            self.scrollbar.grid_remove()
            self.canvas.yview_moveto(0)

    def _scroll(self, units: int):
        if self.scrollbar.winfo_ismapped():
            self.canvas.yview_scroll(units, "units")

    def _on_wheel(self, event):
        delta = event.delta if sys.platform == "darwin" else event.delta // 120
        self._scroll(-delta)
