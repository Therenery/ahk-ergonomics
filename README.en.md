# AHK Ergonomics

A single AutoHotkey v2 script that fills in a few ergonomic gaps in Windows: hold `Win` to summon a terminal, `CapsLock` as a modifier layer, and extended mouse side buttons.

[中文说明](README.md)

## Features

### 1. Hold Left Win to open a terminal

- Hold left `Win` for 600 ms → Windows Terminal opens running PowerShell
- Or double-tap `Win` within 400 ms and keep the second press held
- If File Explorer has focus, the terminal opens in that window's current folder; on Windows 11 the active tab is detected, so the path never comes from a background tab
- If the foreground window changes while `Win` is held (i.e. you are using a `Win + key` shortcut), the gesture is abandoned
- The terminal is brought to the foreground afterwards, and `Esc` clears the Start menu that appears when `Win` is released

### 2. CapsLock modifier layer

A tap toggles Caps Lock (on release, so it never interferes with combos). Held down, CapsLock becomes a modifier:

| Keys | Action |
| --- | --- |
| `CapsLock + Q` | Close active window (Alt+F4) |
| `CapsLock + E` | Search selection in Edge, or just open Edge |
| `CapsLock + W / A / S / D` | Arrow up / left / down / right |
| `CapsLock + M` | Minimize active window |
| `CapsLock + F` | Maximize active window |
| `CapsLock + ,` / `.` | Left / right mouse click |
| `CapsLock + ↑` / `↓` | Wheel up / down |
| `CapsLock + PgUp` / `PgDn` | Mouse button X1 / X2 |
| `CapsLock + LButton` / `RButton` | Previous / next virtual desktop |

### 3. Mouse button XButton1 (usually "Back")

| Gesture | Action |
| --- | --- |
| Click | Native Back |
| Hold + wheel up / down | Switch virtual desktop, wrapping around at both ends |
| Hold + middle click | Task View |
| Hold + left click | Enter |
| Hold + right click | Backspace |

### 4. Mouse button XButton2 (usually "Forward")

| Gesture | Action |
| --- | --- |
| Click | Native Forward |
| Hold + left click | Copy the selection; if nothing is selected, select all without copying |
| Hold + right click | Paste on release |

### 5. Both side buttons held: screenshot

Hold the upper and lower side buttons together → `Win + Shift + S` opens the system snipping overlay (region / window / full screen, copied to the clipboard). Single-click Back / Forward and the other hold gestures are unaffected.

## Requirements

- Windows 10 / 11
- [AutoHotkey v2.0](https://www.autohotkey.com/) or later
- Windows Terminal (`wt.exe`)
- Microsoft Edge (used by the search hotkey; easy to change)

## Install

1. Install AutoHotkey v2
2. Download `ahk-ergonomics.ahk`
3. Double-click it — the tray icon means it is running
4. To autostart, press `Win + R`, type `shell:startup`, and put a shortcut to the script in that folder

## Why it runs elevated

The script checks for administrator rights on startup and relaunches itself elevated, so you will see one UAC prompt per launch.

Elevation is needed because Windows blocks synthesized keystrokes from a lower-integrity process to elevated windows (Task Manager, some installers), and `Win + Ctrl + Arrow` desktop switching is subject to the same restriction.

## Configuration

Two constants near the middle of the script:

```ahk
global totalDesktops := 6   ; number of virtual desktops
global currentDesktop := 2  ; which desktop you are on at launch (1-based)
```

The search hotkey hardcodes `msedge.exe`; edit the two `Run(...)` calls under `CapsLock & e` to use another browser.

## Known limitations

- The virtual desktop index is tracked by the script itself, so it stays accurate only for gestures made through this script. Switching desktops by other means (Task View, touchpad gestures, other tools) makes the counter drift; restart the script or adjust `currentDesktop`
- Explorer path detection only handles `CabinetWClass` windows whose current location is a real folder; virtual locations fall back to the user profile
- `CapsLock + E` relies on `Ctrl + C` producing a selection, which usually fails in terminal-style apps

## License

MIT
