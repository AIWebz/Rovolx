"""Roblox-style theme: blue stud baseplate, navy panels, gold controls.

The stud texture is drawn pixel by pixel at start-up, so the app ships with no
image files (important for the one-file .exe).
"""

import sys
import tkinter as tk
from tkinter import font as tkfont
from tkinter import ttk

BG = "#0d69ac"  # Roblox "Bright blue" baseplate
CARD = "#0a2f5a"
CARD_EDGE = "#2a72bd"
INPUT = "#061d3a"
TEXT = "#ffffff"
MUTED = "#a9c9ef"
ACCENT = "#f5c518"  # gold
ACCENT_HOVER = "#ffd84d"
ACCENT_DARK = "#b88a0b"
ACCENT_TEXT = "#2a1b00"
GOLD_2 = "#dba515"  # secondary gold button
GOLD_2_HOVER = "#efbb2c"
GREEN = "#43e584"
RED = "#ff6b6b"
AMBER = "#ffc94a"
GREY = "#7189aa"
TRACK_OFF = "#17406f"

STUD_TILE = 30  # pixels per stud


def _rgb(color: str) -> tuple[int, int, int]:
    return int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)


def _shade(rgb, amount: float) -> str:
    """Lighten (amount > 0) or darken (amount < 0) towards white/black."""
    target = 255 if amount > 0 else 0
    a = min(abs(amount), 1.0)
    r, g, b = (round(c + (target - c) * a) for c in rgb)
    return f"#{r:02x}{g:02x}{b:02x}"


def stud_tile_rows(size: int = STUD_TILE, base: str = BG) -> list[list[str]]:
    """Pixel colours for one stud: a raised, lit-from-top-left cylinder on a plate."""
    rgb = _rgb(base)
    c = (size - 1) / 2
    radius = size * 0.31
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            dx, dy = x - c, y - c
            dist = (dx * dx + dy * dy) ** 0.5
            light = -(dx + dy) / (2 * radius)  # +1 at top-left, -1 at bottom-right
            if dist <= radius - 1.2:
                amount = 0.10 + 0.10 * light  # stud top
            elif dist <= radius + 0.4:
                amount = 0.28 * light  # rim: bright top-left, dark bottom-right
            else:
                sx, sy = x - c - 2, y - c - 2  # drop shadow
                amount = -0.16 if (sx * sx + sy * sy) ** 0.5 <= radius else 0.0
                if x == 0 or y == 0:
                    amount = 0.07  # plate seam highlight
                elif x == size - 1 or y == size - 1:
                    amount = -0.10  # plate seam shadow
            row.append(_shade(rgb, amount) if amount else base)
        rows.append(row)
    return rows


def make_stud_tile(master, size: int = STUD_TILE) -> tk.PhotoImage:
    img = tk.PhotoImage(master=master, width=size, height=size)
    img.put(" ".join("{" + " ".join(r) + "}" for r in stud_tile_rows(size)))
    return img


class StudBackground:
    """Fills ``frame`` with the tiled stud texture, behind its other children."""

    GROW = 512

    def __init__(self, frame: tk.Misc):
        self.frame = frame
        self.tile = make_stud_tile(frame)
        self.image = None
        self.label = tk.Label(frame, bd=0, highlightthickness=0, bg=BG, anchor="nw")
        self.label.place(x=0, y=0, relwidth=1, relheight=1)
        self.label.lower()
        frame.bind("<Configure>", self._resize, add="+")

    def _resize(self, event):
        w, h = event.width, event.height
        if self.image and self.image.width() >= w and self.image.height() >= h:
            return
        # Grow in steps so dragging the window edge does not rebuild every pixel.
        w = (w // self.GROW + 1) * self.GROW
        h = (h // self.GROW + 1) * self.GROW
        image = tk.PhotoImage(master=self.frame, width=w, height=h)
        image.tk.call(image, "copy", self.tile, "-to", 0, 0, w, h)
        self.label.configure(image=image)
        self.image = image  # keep a reference or Tk frees it


def pick_family(root: tk.Misc) -> str:
    available = set(tkfont.families(root))
    for family in ("Builder Sans", "Gotham", "Segoe UI", "SF Pro Text", "Helvetica Neue", "Inter",
                   "Cantarell", "DejaVu Sans"):
        if family in available:
            return family
    return tkfont.nametofont("TkDefaultFont").actual("family")


def apply_theme(root: tk.Tk) -> dict:
    """Configure ttk styles and return the named fonts used by the UI."""
    family = pick_family(root)
    fonts = {
        "title": tkfont.Font(root, family=family, size=19, weight="bold"),
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
    style.configure("TLabel", background=CARD, foreground=TEXT)
    style.configure("Card.TLabel", background=CARD, foreground=TEXT)
    style.configure("Muted.TLabel", background=CARD, foreground=MUTED, font=fonts["small"])
    style.configure("Title.TLabel", background=CARD, foreground=TEXT, font=fonts["title"])
    style.configure("Subtitle.TLabel", background=CARD, foreground=ACCENT, font=fonts["small"])
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
        background=ACCENT,
        foreground=TEXT,
        arrowcolor=ACCENT_TEXT,
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
        background=[("active", ACCENT_HOVER)],
    )

    style.configure(
        "Horizontal.TScale",
        background=ACCENT,
        troughcolor=INPUT,
        bordercolor=CARD_EDGE,
        lightcolor=ACCENT_HOVER,
        darkcolor=ACCENT_DARK,
        sliderlength=22,
        sliderthickness=18,
    )
    style.map("Horizontal.TScale", background=[("active", ACCENT_HOVER), ("disabled", GREY)])

    for name, color, hover in (("Accent.TButton", ACCENT, ACCENT_HOVER), ("Ghost.TButton", GOLD_2, GOLD_2_HOVER)):
        style.configure(
            name,
            background=color,
            foreground=ACCENT_TEXT,
            font=fonts["button"],
            bordercolor=ACCENT_DARK,
            lightcolor=hover,
            darkcolor=ACCENT_DARK,
            focuscolor=ACCENT_TEXT,
            padding=(18, 10),
        )
        style.map(
            name,
            background=[("disabled", GREY), ("pressed", ACCENT_DARK), ("active", hover)],
            foreground=[("disabled", "#33445c")],
        )
    style.configure("Vertical.TScrollbar", background=ACCENT, troughcolor=CARD, bordercolor=CARD,
                    arrowcolor=ACCENT_TEXT, lightcolor=ACCENT_HOVER, darkcolor=ACCENT_DARK)
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
    """Vertically scrollable area; ``self.body`` is the frame to fill.
    The body is stretched to at least the visible height so its background
    (the stud texture) always covers the window."""

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
        self.body.bind("<Configure>", self._sync, add="+")
        self.canvas.bind("<Configure>", self._sync, add="+")
        self.canvas.bind_all("<MouseWheel>", self._on_wheel, add="+")
        self.canvas.bind_all("<Button-4>", lambda e: self._scroll(-1), add="+")
        self.canvas.bind_all("<Button-5>", lambda e: self._scroll(1), add="+")

    def _sync(self, _event=None):
        needed = self.body.winfo_reqheight()
        visible = self.canvas.winfo_height()
        self.canvas.itemconfigure(self._window, width=self.canvas.winfo_width(), height=max(needed, visible))
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))
        needs_bar = needed > visible
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
