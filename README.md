# SmartKeyPressOSD

[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC_BY_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

SmartKeyPressOSD is a small AutoHotkey v2 host for optional, same-process mouse visualisation plugins. The host samples input once, maintains a reusable shared state object, owns the GDI+ lifetime, and dispatches input events to the enabled plugins.

The original text OSD is now itself a plugin, so all visual features are optional and follow the same architecture.

## Included plugins

- `KeyPressOSD` - displays mouse buttons and accompanying `Ctrl`, `Shift`, and `Alt` modifiers in a layered OSD near the pointer.
- `PointerHalo` - draws a hollow ring around the pointer and changes its colour when a mouse button is held.
- `ClickRipples` - draws expanding concentric circles at the click position.

All three plugins run inside the **same AutoHotkey process**. No plugin starts a second AutoHotkey process.

## Requirements

- Windows
- AutoHotkey v2

The project uses Windows APIs and GDI+ directly through `DllCall`, so it is Windows-specific.

## Project structure

```text
SmartKeyPressOSD/
|-- SmartKeyPressOSD.ahk
|-- README.md
|-- LICENSE.md
|-- Core/
|   |-- SharedTheme.ahk
|   |-- GDIPlusHost.ahk
|   |-- InputState.ahk
|   `-- PluginManager.ahk
`-- Plugins/
    |-- KeyPressOSD.ahk
    |-- PointerHalo.ahk
    `-- ClickRipples.ahk
```

### Host and core

`SmartKeyPressOSD.ahk` is deliberately small. It:

1. starts GDI+ once;
2. runs one application timer;
3. updates one persistent `SmartInputState` object;
4. dispatches that state to plugins;
5. shuts plugins down before shutting GDI+ down.

`Core/InputState.ahk` contains the reusable input state object.

`Core/PluginManager.ahk` detects button transitions centrally and dispatches plugin callbacks.

`Core/SharedTheme.ahk` contains colours shared by every plugin.

`Core/GDIPlusHost.ahk` owns the single `GdiplusStartup()` / `GdiplusShutdown()` pair.

## Installation

1. Install AutoHotkey v2.
2. Keep the complete directory structure intact.
3. Run `SmartKeyPressOSD.ahk`.

To start it automatically with Windows, create a shortcut to `SmartKeyPressOSD.ahk` in the Windows Startup folder.

Open that folder with:

```text
Win + R
shell:startup
```

## Shared mouse-button colours

The button colours are defined once in `Core/SharedTheme.ahk`:

```ahk
class SmartKeyPressTheme {
    static MouseColors := Map(
        "LeftM",   0xFF0000FF,  ; blue
        "MiddleM", 0xFF008000,  ; green
        "RightM",  0xFFFF0000   ; red
    )
}
```

`KeyPressOSD`, `PointerHalo`, and `ClickRipples` all use this same map. Changing a button colour here changes it everywhere.

Colours use ARGB format:

```text
0xAARRGGBB
```

## KeyPressOSD plugin

`Plugins/KeyPressOSD.ahk` contains the original text OSD functionality.

Examples:

| Input | Display |
|---|---|
| Left click | No text OSD entry by default |
| Middle click | `MiddleM` |
| Right click | `RightM` |
| Ctrl + left click | `Ctrl+LeftM` |
| Shift + middle click | `Shift+MiddleM` |
| Shift + right click | `Shift+RightM` |
| Ctrl + Shift + left click | `Ctrl+Shift+LeftM` |
| Ctrl while typing | No text OSD |
| Shift while typing | No text OSD |
| Alt while typing | No text OSD |

The plugin follows the pointer during a drag, keeps the final text visible for a short period after release, then fades it out.

Important configuration values are near the top of `Plugins/KeyPressOSD.ahk`:

```ahk
static HoldDelay := 700
static FadeDuration := 450
static OffsetX := 30
static OffsetY := -35

static MaxWidth := 420
static Height := 42
static PaddingX := 5
static PaddingY := 7
static FontName := "Segoe UI"
static FontSize := 19
```

The background colour, mouse-button colours, modifier colour and separator colour come from `SmartKeyPressTheme`.

## PointerHalo plugin

`Plugins/PointerHalo.ahk` draws a hollow ring centred on the pointer.

Default configuration:

```ahk
static Enabled := true
static Diameter := 65
static StrokeWidth := 3.0
static NeutralColor := 0x80FFFF00
```

The neutral colour is used when no mouse button is held. While a button is held, the halo uses that button's globally shared colour.

The halo bitmap is redrawn only when its visual style changes. Ordinary pointer movement uses `SetWindowPos()`.

## ClickRipples plugin

`Plugins/ClickRipples.ahk` creates expanding concentric rings on mouse-button press.

Default configuration:

```ahk
static Enabled := true
static Lifetime := 650
static MaxRadius := 52
static MinRadius := 7
static RingGap := 6
static RingCount := 3
static StrokeWidth := 3.0
static MaxActiveRipples := 6
```

Each ripple uses the globally shared colour for the mouse button which created it.

The plugin is not ticked while no ripple animation is active.

## Plugin system

Plugins are ordinary `.ahk` files included at script startup:

```ahk
#Include "*i Plugins\KeyPressOSD.ahk"
#Include "*i Plugins\PointerHalo.ahk"
#Include "*i Plugins\ClickRipples.ahk"
```

The `*i` option makes each include optional. If a plugin file is missing, the host still starts normally.

Because `#Include` is processed at script startup, adding or removing a plugin requires a **reload or restart**. Plugins are not compiled into an already-running AutoHotkey script dynamically.

### Plugin callbacks

A plugin may implement any of these callbacks:

```text
Init()
WantsTick(state)
Tick(state)
MouseDown(button, state)
MouseUp(button, state)
Shutdown()
```

Register a plugin with:

```ahk
PluginManager.Register(MyPlugin, "MyPlugin")
```

`WantsTick(state)` is optional. If present and it returns `false`, the manager skips that plugin's `Tick()` call for the current host tick.

This lets animation or OSD plugins become effectively idle when they have nothing to do.

### Shared state object

The host allocates one `SmartInputState` object and updates it in place. Plugins receive the same object rather than new Maps or state objects being allocated every 20 ms.

Available properties are:

```text
state.X
state.Y
state.LeftM
state.MiddleM
state.RightM
state.MouseDown
state.Ctrl
state.Shift
state.Alt
```

The current plugins only need modifiers while a mouse button is held, so modifier key state is queried only in that situation.

### Plugin isolation

If a plugin callback raises an AutoHotkey `Error`, the manager disables that plugin, attempts to release its resources, and writes diagnostic information with `OutputDebug`.

Other plugins continue running.

## Enabling or disabling plugins

The included plugins are enabled by default.

You can disable one either by removing/renaming its file and restarting, or by changing its `Enabled` setting. For example:

```ahk
class PointerHaloPlugin {
    static Enabled := false
```

## Performance design

The refactored architecture is designed to avoid performance regressions from modularisation.

### One timer

There is exactly one application timer by default:

```ahk
APP_POLL_INTERVAL := 20
```

At the default value, the host runs at up to 50 polling ticks per second.

Plugins do not create their own polling timers.

### Input is sampled once

Each host tick reads the pointer and mouse buttons exactly once into the persistent `SmartInputState` object. All plugins consume that same state.

No plugin repeats `MouseGetPos()` or physical button polling.

### Persistent state, no per-tick state Maps

The host does not create new button/modifier Maps on every poll. The same `SmartInputState` instance is updated in place.

### Transition events are centralised

The plugin manager detects `MouseDown` and `MouseUp` transitions once and dispatches them to interested plugins. Individual plugins do not maintain duplicate transition detectors.

### Inactive plugins are skipped

`WantsTick(state)` allows plugins to avoid normal tick processing while idle:

- `KeyPressOSD` is skipped while hidden and no mouse button is down.
- `ClickRipples` is skipped while there are no active animations.
- `PointerHalo` receives every tick because it must follow the pointer.

### Rendering is event-driven where possible

`KeyPressOSD` retains the important optimisations from the original implementation:

- fixed backing DIB;
- cached text widths;
- cached GDI+ brushes;
- text redraw only when the displayed combination changes;
- `SetWindowPos()` for normal drag-follow movement;
- `UpdateLayeredWindow()` only when bitmap, size or opacity changes;
- fade without rerendering text.

`PointerHalo` redraws its GDI+ surface only when the halo colour/style changes. Normal movement uses `SetWindowPos()`.

`ClickRipples` necessarily redraws while an animation is active, but the number of simultaneous animations is capped by `MaxActiveRipples` and the plugin receives no tick calls when idle.

## GDI+ lifetime

`gdiplus.dll` is explicitly kept loaded for the complete script lifetime.

`GDIPlusHost` starts GDI+ once. Plugins create and destroy their own GDI/GDI+ drawing objects but must **not** call `GdiplusStartup()` or `GdiplusShutdown()` themselves.

During exit:

1. the host timer is stopped;
2. plugins release their resources;
3. the host performs the single GDI+ shutdown call.

This preserves the shutdown fix which prevents the earlier access violation during script exit.

## Creating another plugin

A minimal plugin can be written as:

```ahk
class MyPlugin {
    static Enabled := true

    static Init() {
    }

    static WantsTick(state) {
        return true
    }

    static Tick(state) {
    }

    static MouseDown(button, state) {
        colour := SmartKeyPressTheme.MouseColors[button]
        x := state.X
        y := state.Y
    }

    static MouseUp(button, state) {
    }

    static Shutdown() {
    }
}

PluginManager.Register(MyPlugin, "MyPlugin")
```

Add an optional include to `SmartKeyPressOSD.ahk`, then reload or restart the host.

## Licence

This project is licensed under the **Creative Commons Attribution 4.0 International licence (CC BY 4.0)**.

You are free to share and adapt the project, including for commercial purposes, provided that appropriate attribution is given, a link to the licence is provided, and changes are indicated.

See [`LICENSE.md`](LICENSE.md) for details.

Official licence information: <https://creativecommons.org/licenses/by/4.0/>

SPDX identifier: `CC-BY-4.0`
