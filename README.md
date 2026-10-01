# SmartInputVisuals

[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC_BY_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

SmartInputVisuals is an AutoHotkey v2 input-visualisation host with optional same-process plugins for text OSD, pointer highlighting, click ripples, drag visualisation and a magnifier lens.

## Features

- `KeyPressOSD` — modifier/mouse-button text display
- `PointerHalo` — hollow pointer halo with idle fade
- `ClickRipples` — expanding concentric click rings
- `DragIndicator` — dashed drag line with an arrowhead
- `MagnifierLens` — configurable click-through magnifier lens around the pointer
- globally shared mouse-button colours
- application focus/hover filtering
- application-specific plugin profiles
- dynamic per-profile tray toggles for installed plugins
- compact always-on-top plugin toolbar with current-profile title
- global tray enable/disable control with zero host polling while disabled
- pause visualisations while ordinary keyboard typing is active
- one shared 20 ms input/presentation timer
- central GDI+ lifetime management
- no external libraries

## Screen sharing

SmartInputVisuals overlays are normally included when an entire desktop or monitor is shared, but not when only a single application window is shared. Capture behaviour varies by conferencing application and Windows/graphics configuration. See [Architecture — Screen sharing](docs/Architecture.md#screen-sharing) for details.

## Requirements

- Windows
- AutoHotkey v2

## Installation

1. Install AutoHotkey v2.
2. Keep the complete directory structure together.
3. Run `SmartInputVisuals.ahk`.

To start it with Windows, place a shortcut to `SmartInputVisuals.ahk` in the Startup folder (`Win + R`, then `shell:startup`).

The application name used by the tray tooltip and `Exit ...` command is configured once in `SmartInputVisuals.ahk` with `APP_NAME := "SmartInputVisuals"`.

## Documentation

- [Configuration](docs/Configuration.md) — profiles, plugin availability/state, toolbar, application scope and runtime controls.
- [Plugins](docs/Plugins.md) — detailed behaviour and settings for KeyPressOSD, PointerHalo, ClickRipples, DragIndicator and MagnifierLens.
- [Architecture](docs/Architecture.md) — screen sharing, mixed-DPI handling, plugin lifecycle, shared input state and performance design.

## Quick configuration

The primary user configuration is in `Profiles/Default.ahk` and `Profiles/AppProfiles.ahk`.

- `PluginDefinitions` is the explicit availability whitelist for plugins.
- `PluginStates` defines Default and application-specific ON/OFF states; a missing Default state means OFF.
- `Toolbar` controls startup position, opacity, colours, title mode, layout and optional touch-oriented button sizing.

See [Configuration](docs/Configuration.md) for the complete reference.

## Project structure

```text
SmartInputVisuals/
├─ SmartInputVisuals.ahk
├─ README.md
├─ LICENSE.md
├─ docs/
│  ├─ Architecture.md
│  ├─ Configuration.md
│  └─ Plugins.md
├─ Core/
│  ├─ AppScope.ahk
│  ├─ DisplayScope.ahk
│  ├─ DpiContext.ahk
│  ├─ GDIPlusHost.ahk
│  ├─ InputActivity.ahk
│  ├─ InputState.ahk
│  ├─ OverlayRegistry.ahk
│  ├─ PluginDefinition.ahk
│  ├─ PluginManager.ahk
│  ├─ PluginToolbar.ahk
│  ├─ ProfileManager.ahk
│  ├─ SharedTheme.ahk
│  └─ TrayController.ahk
├─ Profiles/
│  ├─ Default.ahk
│  └─ AppProfiles.ahk
└─ Plugins/
   ├─ ClickRipples.ahk
   ├─ DragIndicator.ahk
   ├─ KeyPressOSD.ahk
   ├─ MagnifierLens.ahk
   └─ PointerHalo.ahk
```

## Credits

SmartInputVisuals reflects a joint effort of human and machine: human design, testing and judgement combined with implementation assistance from ChatGPT.

## Licence

This project is licensed under the **Creative Commons Attribution 4.0 International licence (CC BY 4.0)**.

See [`LICENSE.md`](LICENSE.md) for details.

Official licence information: <https://creativecommons.org/licenses/by/4.0/>

SPDX identifier: `CC-BY-4.0`
