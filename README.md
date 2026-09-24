# SmartKeyPressOSD

[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC_BY_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

SmartKeyPressOSD is an AutoHotkey v2 input-visualisation host with optional same-process plugins for text OSD, pointer highlighting, click ripples and drag visualisation.

## Features

- `KeyPressOSD` — modifier/mouse-button text display
- `PointerHalo` — hollow pointer halo with idle fade
- `ClickRipples` — expanding concentric click rings
- `DragIndicator` — dashed drag line with an arrowhead
- globally shared mouse-button colours
- application focus/hover filtering
- application-specific plugin profiles
- pause visualisations while ordinary keyboard typing is active
- one shared 20 ms input/presentation timer
- central GDI+ lifetime management
- no external libraries

## Requirements

- Windows
- AutoHotkey v2

## Project structure

```text
SmartKeyPressOSD/
├─ SmartKeyPressOSD.ahk
├─ README.md
├─ LICENSE.md
├─ Core/
│  ├─ AppScope.ahk
│  ├─ GDIPlusHost.ahk
│  ├─ InputActivity.ahk
│  ├─ InputState.ahk
│  ├─ PluginManager.ahk
│  ├─ ProfileManager.ahk
│  └─ SharedTheme.ahk
├─ Profiles/
│  ├─ Default.ahk
│  └─ AppProfiles.ahk
└─ Plugins/
   ├─ ClickRipples.ahk
   ├─ DragIndicator.ahk
   ├─ KeyPressOSD.ahk
   └─ PointerHalo.ahk
```

## Installation

1. Install AutoHotkey v2.
2. Keep the complete directory structure together.
3. Run `SmartKeyPressOSD.ahk`.

To start it with Windows, place a shortcut to `SmartKeyPressOSD.ahk` in the Startup folder (`Win + R`, then `shell:startup`).

## Shared colours

Mouse-button colours are defined once in `Core/SharedTheme.ahk` and reused by all plugins:

```ahk
static MouseColors := Map(
	"LeftM",   0xFF0000FF,
	"MiddleM", 0xFF008000,
	"RightM",  0xFFFF0000
)
```

## KeyPressOSD

A plain left click is intentionally suppressed. If another modifier or mouse button participates, the complete combination is displayed.

| Input | Display |
|---|---|
| Left click | No text OSD |
| Middle click | `MiddleM` |
| Right click | `RightM` |
| Ctrl + left click | `Ctrl+LeftM` |
| Ctrl + Shift + left click | `Ctrl+Shift+LeftM` |
| Shift + middle click | `Shift+MiddleM` |
| Shift + right click | `Shift+RightM` |

Default position/timing settings in `Plugins/KeyPressOSD.ahk`:

```ahk
static HoldDelay := 700
static FadeDuration := 450
static OffsetX := 30
static OffsetY := -35
```

## PointerHalo and IdleFade

`Plugins/PointerHalo.ahk` draws a hollow ring centred on the pointer. It defaults to `HoverOnly` application scope, so it disappears as soon as the pointer leaves an allowed application.

```ahk
static Diameter := 65
static StrokeWidth := 3.0
static NeutralColor := 0x80FFFF00

static IdleFadeEnabled := true
static IdleDelay := 1500
static IdleFadeDuration := 500
```

After `IdleDelay` milliseconds without pointer movement, the halo fades over `IdleFadeDuration`. Moving the pointer or holding a mouse button restores full visibility immediately.

## ClickRipples

`Plugins/ClickRipples.ahk` creates expanding rings at each mouse-button press. The button colour comes from `SmartKeyPressTheme.MouseColors`.

```ahk
static Lifetime := 650
static MaxRadius := 52
static MinRadius := 7
static RingGap := 6
static RingCount := 3
static StrokeWidth := 3.0
static MaxActiveRipples := 6
```

## DragIndicator

`Plugins/DragIndicator.ahk` displays a straight dashed line from the drag start point to the current pointer position. A solid arrowhead marks the current position, and the entire indicator uses the colour of the mouse button which started the drag.

```ahk
static DragThreshold := 6
static StrokeWidth := 3.0
static ArrowLength := 15.0
static ArrowHalfWidth := 7.0
static UpdateInterval := 33
static MinMovement := 2
```

The indicator does not appear until the pointer has moved at least `DragThreshold` pixels, so ordinary clicks do not flash a line. Rendering is limited to roughly 30 FPS and movements below `MinMovement` pixels are ignored between rendered frames.

The original single layered backing DIB is used for reliable rendering. It grows in 32-pixel blocks only when needed and is released when the drag ends, so drag memory is not retained while the plugin is idle. A very long diagonal drag can still require a temporarily large backing surface because the bitmap must cover the line's bounding rectangle.

## Pause while typing

Keyboard activity is tracked centrally by `Core/InputActivity.ahk` using a non-blocking `InputHook`.

```ahk
static PauseWhileTyping := true
static TypingPauseDuration := 750
```

Modifier-only presses (`Ctrl`, `Shift`, `Alt`, Windows keys) do not count as typing. A normal key in a combination does; for example, pressing `Ctrl` alone does not pause visualisations, while `Ctrl+C` does.

A plugin opts into this behaviour with:

```ahk
static PauseWhileTyping := true
```

All included visual plugins opt in. While typing suppression is active, `PluginManager` does not dispatch mouse or tick callbacks to those plugins. A currently visible plugin receives one `Deactivated("Typing", state)` callback so it can remove its existing visualisation, then receives no normal callbacks until it becomes eligible again.

## Application scope

Configure `Core/AppScope.ahk` to restrict plugins to selected applications:

```ahk
static Enabled := true
static Mode := "FocusOrHover"
static Applications := [
	"devenv.exe",
	"msedge.exe"
]
```

Supported modes:

| Mode | Behaviour |
|---|---|
| `Always` | Ignore the application list for that plugin |
| `FocusOnly` | Configured application must have focus |
| `HoverOnly` | Pointer must be over a configured application |
| `FocusOrHover` | Either condition is sufficient |
| `FocusAndHover` | Both conditions are required |

Plugins may override the global mode with `static ScopeMode := "..."`. `PointerHalo` defaults to `HoverOnly`; the other included plugins inherit the global mode.

Process names are cached and are resolved again only when the relevant window handle changes. SmartKeyPressOSD's own topmost click-through windows are skipped when resolving the application beneath the pointer.

## Application-specific profiles

Profiles control **which plugins are enabled for particular applications**. This is independent of application scope: profiles choose a plugin set, while `AppScope` controls where a plugin is permitted to display.

Profiles are enabled by default in `Core/ProfileManager.ahk`:

```ahk
static Enabled := true
static SelectionMode := "HoverThenFocus"
```

Supported selection modes:

- `HoverThenFocus` — the hovered application determines the profile; focus is used only when no hovered process can be resolved
- `FocusThenHover` — the focused application determines the profile; hover is used only when no focused process can be resolved
- `HoverOnly` — the hovered application determines the profile
- `FocusOnly` — the focused application determines the profile

For every selected application, an application-specific profile is used when one is registered; otherwise the `Default` profile is used immediately. This means moving the pointer from a profiled application to an unprofiled application switches to the Default profile without requiring a focus change.

`Profiles/Default.ahk` defines the fallback plugin set and enables only `KeyPressOSD`. `Profiles/AppProfiles.ahk` contains the application-specific profiles.

Example profile definition:

```ahk
class PowerPointProfile {
	static Name := "PowerPoint"
	static Applications := ["POWERPNT.EXE"]
	static Plugins := Map(
		"KeyPressOSD", true,
		"PointerHalo", true,
		"ClickRipples", true,
		"DragIndicator", false
	)
}
```

Plugin names omitted from an application-specific profile fall back to the corresponding setting in the Default profile. Executable names are matched case-insensitively. Duplicate executable mappings are rejected during startup.

When a profile disables an already-visible plugin, the manager sends one `Deactivated("Profile", state)` callback so the plugin can clear its visualisation, then stops dispatching normal callbacks to it.

## Plugin eligibility and lifecycle

The manager applies eligibility centrally in this order:

1. plugin's own `Enabled` flag
2. active application profile
3. application scope
4. pause-while-typing policy

A plugin with `Enabled := false` is not initialised and receives no plugin calls at all. Changing `Enabled` in source therefore requires a reload/restart.

For profile, scope or typing transitions, an active plugin may receive one `Deactivated(reason, state)` cleanup callback. Once blocked, it receives no `WantsTick`, `Tick`, `MouseDown` or `MouseUp` calls.

Optional plugin callbacks are:

```text
Init()
Activated(state)
Deactivated(reason, state)
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

## Shared input state

The host allocates one `SmartInputState` instance and updates it in place. Plugins share it instead of allocating per-tick Maps.

Useful properties include:

```text
state.X
state.Y
state.MouseMoved
state.LastMouseMoveTick
state.LeftM
state.MiddleM
state.RightM
state.MouseDown
state.Ctrl
state.Shift
state.Alt
state.TypingActive
state.LastTypingTick
state.HoverProcess
state.ActiveProcess
state.ProfileName
state.ProfileProcess
```

## Performance design

SmartKeyPressOSD uses one 20 ms host timer. Pointer position and mouse-button state are sampled once per tick and shared with all plugins.

The architecture avoids unnecessary work by:

- skipping globally disabled plugins before initialisation and dispatch;
- skipping plugins disabled by the active profile;
- skipping out-of-scope plugins;
- skipping pause-while-typing plugins while typing is active;
- calling `WantsTick()` only after all eligibility checks pass;
- using persistent input state instead of per-tick Maps;
- caching application process names;
- using `SetWindowPos()` for unchanged moving visuals where possible;
- redrawing `PointerHalo` only when its style/opacity changes;
- ticking `ClickRipples` only while animations are active;
- throttling `DragIndicator` rendering to roughly 30 FPS, ignoring sub-2-pixel movement and releasing its backing surface after each drag.

## GDI+ lifetime

`gdiplus.dll` is kept loaded for the script lifetime. `GDIPlusHost` starts GDI+ exactly once; plugins create and release their own drawing resources but never start or stop GDI+ themselves.

At exit the host stops the timer, shuts down plugins, stops keyboard activity tracking, then shuts GDI+ down last.

## Licence

This project is licensed under the **Creative Commons Attribution 4.0 International licence (CC BY 4.0)**.

See [`LICENSE.md`](LICENSE.md) for details.

Official licence information: <https://creativecommons.org/licenses/by/4.0/>

SPDX identifier: `CC-BY-4.0`
