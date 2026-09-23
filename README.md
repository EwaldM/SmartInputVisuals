# SmartKeyPressOSD

[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC_BY_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

A lightweight AutoHotkey v2 on-screen display for mouse clicks and modifier-assisted mouse actions.

The OSD follows the mouse pointer while a mouse button is held, displays the current mouse button and any accompanying `Ctrl`, `Shift`, or `Alt` modifiers, stays visible briefly after release, then fades out smoothly.

## Features

- AutoHotkey **v2.0**
- Shows:
  - `LMB` in blue
  - `RMB` in red
  - `Ctrl`, `Shift`, and `Alt` in orange
  - separators and other text in black
- Modifiers are shown **only when a mouse button is also pressed**
  - ordinary typing with `Ctrl`, `Shift`, or `Alt` does not trigger the OSD
- Follows the pointer during click-and-drag operations
- Uses a click-through, non-activating, always-on-top layered window
- Crisp antialiased text rendered with GDI+
- Yellow background at approximately 25% opacity
- Dynamically resizes to the width required by the displayed text
- Holds the final state briefly after release
- Smooth fade-out before hiding
- Optimised drag handling:
  - `SetWindowPos()` is used for normal movement
  - `UpdateLayeredWindow()` is used only when the bitmap, size, or opacity changes
- Text widths are cached at startup to avoid repeated measurements
- No external libraries required

## Requirements

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/)

The script uses Windows APIs and GDI+ directly through `DllCall`, so it is Windows-specific.

## Installation

1. Install AutoHotkey v2.
2. Download `SmartKeyPressOSD.ahk`.
3. Run the script.

To start it automatically with Windows, place a shortcut to the script in your Windows Startup folder.

You can open the Startup folder with:

```text
Win + R
shell:startup
```

## Behaviour

The OSD appears only when the left or right mouse button is physically held.

Examples:

| Input | OSD |
|---|---|
| Left click | `LMB` |
| Right click | `RMB` |
| Ctrl + left click | `Ctrl+LMB` |
| Shift + right click | `Shift+RMB` |
| Ctrl + Shift + left click | `Ctrl+Shift+LMB` |
| Ctrl while typing | No OSD |
| Shift while typing | No OSD |
| Alt while typing | No OSD |

During a drag operation, the OSD follows the mouse pointer.

After the mouse button is released, the last displayed state remains visible for a short period and then fades out.

## Default appearance

The current defaults are:

| Item | Setting |
|---|---|
| Horizontal offset | `20 px` |
| Vertical offset | `80 px` |
| Font | `Segoe UI` |
| Font size | `19 px` |
| Background | Yellow |
| Background opacity | ~25% |
| LMB colour | Blue |
| RMB colour | Red |
| Modifier colour | Orange |
| Separator colour | Black |
| Hold time | `700 ms` |
| Fade duration | `450 ms` |
| Poll interval | `20 ms` |

## Configuration

The main settings are near the top of the script.

### Position

```ahk
OSD_OFFSET_X := 20
OSD_OFFSET_Y := 80
```

These values control the OSD position relative to the mouse pointer.

### Timing

```ahk
OSD_POLL_INTERVAL := 20
OSD_HOLD_DELAY    := 700
OSD_FADE_DURATION := 450
```

- `OSD_POLL_INTERVAL` controls how often physical input and pointer movement are checked.
- `OSD_HOLD_DELAY` controls how long the OSD remains fully visible after release.
- `OSD_FADE_DURATION` controls the fade-out duration.

### Font

```ahk
OSD_FONT_NAME := "Segoe UI"
OSD_FONT_SIZE := 19
```

The font size is specified in GDI+ pixels.

### Background

```ahk
OSD_BACKGROUND_ARGB := 0x40FFFF00
```

The colour uses ARGB format:

```text
0xAARRGGBB
```

For the default value:

```text
40 FF FF 00
│  └────── yellow
└───────── alpha (~25%)
```

### Text colours

```ahk
OSD_COLORS := Map(
    "Ctrl",  0xFFFFA500,
    "Shift", 0xFFFFA500,
    "Alt",   0xFFFFA500,
    "LMB",   0xFF0000FF,
    "RMB",   0xFFFF0000,
    "+",     0xFF000000
)
```

Colours also use ARGB format.

## Performance

The script is designed to keep work during dragging relatively small.

A timer checks the physical mouse-button state every `20 ms`. While dragging, the already-rendered layered window is normally moved using `SetWindowPos()` rather than retransmitting its bitmap on every pointer update.

`UpdateLayeredWindow()` is used when necessary, such as when:

- the displayed text changes
- the dynamic width changes
- the OSD becomes visible
- fade opacity changes

Text widths for all fixed tokens are measured once during startup and cached.

The backing bitmap has a fixed maximum width, while the visible layered window is dynamically sized to the actual rendered text width.

## How it works

The script combines:

- AutoHotkey v2 physical key/mouse state detection
- a click-through AutoHotkey GUI
- Windows layered-window APIs
- GDI+ text rendering
- `SetWindowPos()` for efficient pointer following
- `UpdateLayeredWindow()` for per-pixel alpha and fade effects

The GUI uses extended window styles that prevent it from taking focus or intercepting mouse input.

## Notes

- The OSD is intentionally tied to mouse-button activity. Modifier keys alone are ignored.
- The script monitors the physical state of the left and right mouse buttons.
- The maximum backing-surface width is currently `320 px`. The visible OSD width is calculated dynamically from the rendered text.
- The OSD is intended for visual feedback during demonstrations, presentations, screen recordings, training sessions, and similar workflows.

## Licence

This project is licensed under the **Creative Commons Attribution 4.0 International licence (CC BY 4.0)**.

You are free to share and adapt the project, including for commercial purposes, provided that appropriate attribution is given, a link to the licence is provided, and changes are indicated.

See [`LICENSE.md`](LICENSE.md) for details.

Official licence information: <https://creativecommons.org/licenses/by/4.0/>

SPDX identifier: `CC-BY-4.0`
