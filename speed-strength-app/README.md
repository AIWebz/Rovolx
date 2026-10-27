# Steal And Break Eggs — Speed & Strength

A desktop app (Python + Tkinter, no third-party runtime dependencies) for setting a
player's **Speed** and **Strength**. It has sliders, number inputs, on/off switches,
Apply and Reset buttons, a live connection status, saved preferences and logging.

> **Important: what this app can and cannot do**
>
> * **Break and Steal an Egg (the public Roblox game by ILGames x Eggs):** this app
>   **cannot change Speed or Strength in that game.** The game has no API, mod loader
>   or plugin system. Its player stats are controlled by Roblox's game servers. The
>   only other way to change them is to inject code into the Roblox client and get
>   past Roblox's anti-cheat. That breaks Roblox's Terms of Use, risks a ban and
>   affects other players, so this app does not do it. When this game is selected,
>   the status says **"Game functionality unavailable"** and Apply reports that
>   nothing was changed.
> * **A Roblox experience you own:** the app sends Speed and Strength to your live
>   servers through Roblox's documented **Open Cloud Messaging API**. A short server
>   script, `src/ServerScriptService/SpeedStrengthBridge.server.lua`, receives the
>   message and applies the values. This needs the owner's API key and a one-time
>   publish of the script.

## Phase 1 findings (verification)

| Question | Finding |
|---|---|
| Platform and version | Roblox experience "Break and Steal an Egg" (listed as game 10765288803 on rotrends.com; not confirmed on roblox.com, which this environment cannot reach). It runs in the Roblox client on Windows, macOS and mobile, and the server version is updated live by the developer. |
| How speed and strength are represented | Movement speed in Roblox is `Humanoid.WalkSpeed` (engine default 16). It is set by the game's server scripts. "Strength" is a game-specific stat that is not documented publicly and is held on the server. |
| Supported interface | **None for the public game.** Roblox offers Open Cloud APIs, but only to the experience owner (API keys are tied to the owner's universe). Messaging needs a subscriber script that only the owner can publish. |
| OS and installation | Windows 10/11 (main target), macOS and Linux. Needs Python 3.10+ with Tkinter, or the PyInstaller executable. |
| Limitations | Server-side stats; the client cannot be modified; anti-cheat; Open Cloud works only for experiences you own; Open Cloud's HTTP 200 confirms delivery to Roblox, not the in-game effect. |

The Open Cloud endpoint was checked against Roblox's official docs repository
(`Roblox/creator-docs`, `cloud/guides/usage-messaging.md`):
`POST https://apis.roblox.com/cloud/v2/universes/{universe}:publishMessage` with header
`x-api-key` and body `{"topic": "...", "message": "..."}`. On success it returns HTTP 200
with an empty body. Messages are limited to 1 KiB and topic names to 80 characters.

## Install

### Windows

1. Install Python 3.10 or newer, with Tcl/Tk (on by default):
   `winget install Python.Python.3.12`
2. Double-click **`setup.bat`**, or run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File setup.ps1
   ```
   Setup creates `.venv\`, installs the app, adds the Start Menu shortcut
   **"Steal And Break Eggs - Speed & Strength"**, and runs a launch smoke test.
3. Start it from the Start Menu or with **`run.bat`**.

### macOS / Linux

```bash
# Linux prerequisites: sudo apt install python3 python3-venv python3-tk   (Debian/Ubuntu)
# macOS prerequisites: brew install python-tk   (or the python.org installer)
./setup.sh
./run.sh
```
`setup.sh` picks the first Python 3.10+ that has Tkinter. To choose one yourself, set
`PYTHON=/path/to/python3`. On Linux it also adds an application-menu entry.

### Standalone executable

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1   # Windows -> dist\SBESpeedStrength.exe
```
```bash
./build.sh                                           # Linux -> dist/SBESpeedStrength, macOS -> dist/SBESpeedStrength.app
```
The build script installs `requirements-dev.txt`, runs the full test suite and stops
if any test fails. Then it runs PyInstaller using `packaging/sbe_speed_strength.spec`.
PyInstaller cannot cross-compile, so build the Windows `.exe` on Windows.

## Use

1. **Game integration**: pick the target.
   * *Break and Steal an Egg (public game)*: the status shows **Game functionality
     unavailable**. You can still configure and save values.
   * *Roblox Open Cloud — an experience you own*: fill in **Universe ID**, **Topic**
     (default `SBESpeedStrength`), **Target User ID** (your Roblox user ID) and **API key**.
     Press **Check Connection**. The app sends a `ping` message, and **Connected** means
     Roblox accepted the key and universe.
2. **Speed** (0–200, default 16) and **Strength** (1–1000, default 1): drag the slider
   or type a whole number (the Up/Down arrow keys change it by 1). The large number next
   to the slider is the value that will be sent. Invalid input is outlined in red with
   an explanation, and **Apply Changes** stays disabled until it is fixed.
3. Turn each modifier on or off with its switch. When a modifier is off, Apply asks the
   game to restore that stat's default.
4. **Apply Changes** saves your settings and sends them. **Reset to Default** restores
   Speed 16 / Strength 1 with both switches off (connection fields are kept). Reset does
   not send anything until you press Apply.

Status colours: grey = not configured, amber = configured / checking / applying,
green = connected (Roblox accepted the request), red = unavailable or error. The text
under the status gives the exact reason, for example "HTTP 401 — API key lacks
universe-messaging-service:publish".

### Setting up an experience you own (Open Cloud)

1. Copy `src/ServerScriptService/SpeedStrengthBridge.server.lua` into
   **ServerScriptService** and publish the experience. If you change `TOPIC` in the
   script, use the same topic in the app.
2. On the Creator Dashboard, go to **Credentials → API Keys → Create**. Add
   **messaging-service**, select your experience, and add the
   **universe-messaging-service:publish** operation.
3. Copy the **Universe ID** (experience **⋯** menu → *Copy Universe ID*).
4. Enter the Universe ID, your User ID and the API key in the app. The API key is never
   written to disk. To avoid typing it every time, set the environment variable
   `SBE_OPENCLOUD_API_KEY`.
5. Join your experience, then press **Apply Changes**. The bridge sets
   `Humanoid.WalkSpeed`, the `Speed` and `Strength` player attributes, and
   `leaderstats.Strength` if it exists, so it works with `StatCommands.server.lua`.
   It also clamps values on the server.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1                  # keeps settings/logs
powershell -ExecutionPolicy Bypass -File uninstall.ps1 -RemoveUserData  # also deletes them
```
```bash
./uninstall.sh            # keeps settings/logs
./uninstall.sh --purge    # also deletes them
```
These scripts remove `.venv`, the `build` and `dist` folders, and the Start Menu or
application-menu entry. After that, delete the project folder.

## Files and locations

| Item | Windows | macOS | Linux |
|---|---|---|---|
| Settings | `%APPDATA%\SBESpeedStrength\settings.json` | `~/Library/Application Support/SBESpeedStrength/` | `~/.config/sbe-speed-strength/` |
| Log (rotating, 3 × 1 MB) | `…\logs\app.log` | same folder `/logs` | same folder `/logs` |

Set `SBE_MODIFIER_HOME` to use a different folder (portable installs, tests). Both paths
are also shown at the bottom of the window.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Python 3.10+ with Tkinter not found` | Windows: reinstall Python with "tcl/tk and IDLE" ticked. Debian/Ubuntu: `sudo apt install python3-tk python3-venv`. macOS: `brew install python-tk`. |
| `cannot open a window` | You need a desktop session. Over SSH, use X forwarding; for headless CI, use `xvfb-run`. |
| PowerShell says scripts are disabled | Use `setup.bat`/`run.bat`, or run with `-ExecutionPolicy Bypass` as shown above. |
| Status **Game functionality unavailable** | Expected for the public Break and Steal an Egg game; see the note at the top. |
| HTTP 401 / 403 | The API key is wrong, lacks `universe-messaging-service:publish`, or is not for that universe. |
| HTTP 404 | Wrong Universe ID. |
| HTTP 429 | Roblox rate limit. Wait a minute. |
| Connected, but nothing changes in-game | The bridge script is not published, the topic does not match, or you are not in a live server (Studio play-test servers do not receive Open Cloud messages). Check the server output for `[SpeedStrengthBridge]` lines. |
| "Saved settings were unreadable" | The settings file was corrupt. It was renamed to `settings.corrupt.json` and the app went back to defaults. |
| Anything else | Run `run.bat --debug` / `./run.sh --debug` and check `app.log`. |

## Development

```bash
./setup.sh --dev                      # or: setup.ps1 -Dev
xvfb-run -a .venv/bin/python -m pytest -q   # drop xvfb-run on a desktop
```

```
speed-strength-app/
├── sbe_modifier/
│   ├── app.py              entry point, logging, signals, clean exit
│   ├── settings.py         state model, validation limits, JSON persistence
│   ├── paths.py            per-OS settings/log locations
│   ├── ui.py               main window (talks only to GameIntegration)
│   ├── widgets.py          dark theme, toggle switch, scroll container
│   └── integration/
│       ├── base.py         GameIntegration interface, ModifierRequest, states
│       ├── unsupported.py  Break and Steal an Egg: reports "unavailable" (no interface exists)
│       └── opencloud.py    Roblox Open Cloud Messaging (owned experiences)
├── tests/                  settings, integration (mock HTTP server), UI (real Tk window)
├── packaging/              PyInstaller spec + launcher
├── setup.* run.* build.* uninstall.*   install / launch / build / remove
├── pyproject.toml  requirements.txt  requirements-dev.txt
```

To add another integration, subclass `GameIntegration` (`initial_state`,
`check_connection`, `apply`, `close`) and register it in `integration/__init__.py`.
Integrations must raise `IntegrationError` rather than report a success they cannot
verify.
