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
- global tray enable/disable control with zero host polling while disabled
- pause visualisations while ordinary keyboard typing is active
- one shared 20 ms input/presentation timer
- central GDI+ lifetime management
- no external libraries

## Screen sharing

When sharing an entire desktop or monitor in Microsoft Teams or Zoom, SmartInputVisuals overlays are normally included because they are ordinary top-level windows and are not marked for capture exclusion. When sharing a single application window, they are normally not included because the overlays belong to the AutoHotkey process rather than the shared application. File-based presentation modes such as PowerPoint Live do not include them.

Capture behaviour can vary: Teams and Zoom may use different capture backends depending on the Windows version, graphics hardware and application version. Test the intended sharing mode on the target system when reliable overlay visibility matters.

## Requirements

- Windows
- AutoHotkey v2

## Project structure

```text
SmartInputVisuals/
├─ SmartInputVisuals.ahk
├─ README.md
├─ LICENSE.md
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

## Installation

1. Install AutoHotkey v2.
2. Keep the complete directory structure together.
3. Run `SmartInputVisuals.ahk`.

To start it with Windows, place a shortcut to `SmartInputVisuals.ahk` in the Startup folder (`Win + R`, then `shell:startup`).

The application name used by the tray tooltip and `Exit ...` command is configured once in `SmartInputVisuals.ahk` with `APP_NAME := "SmartInputVisuals"`.

## Shared colours

Mouse-button colours are defined once in `Core/SharedTheme.ahk` and reused by all plugins:

```ahk
static MouseColors := Map(
	"LeftM",   0xFF0000FF,
	"MiddleM", 0xFF008000,
	"RightM",  0xFFFF0000
)

static FadeDuration := 900
static IdleDelay := 2500
```

`FadeDuration` defines one shared fade duration for `KeyPressOSD`, `PointerHalo` and `DragIndicator`. `IdleDelay` defines how long idle `PointerHalo` and completed `DragIndicator` visuals remain fully visible before that fade begins.

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
static OSDHoldDuration := 700
static OffsetX := 30
static OffsetY := -35
```

## PointerHalo and IdleFade

`Plugins/PointerHalo.ahk` draws a hollow ring centred on the pointer. It defaults to `HoverOnly` application scope, so it disappears as soon as the pointer leaves an allowed application.

```ahk
static Diameter := 65
static StrokeWidth := 3.0
static NeutralColor := 0xA08B008B

static IdleFadeEnabled := true
```

After `SmartInputVisualsTheme.IdleDelay` milliseconds without pointer movement, the halo fades over `SmartInputVisualsTheme.FadeDuration`. Moving the pointer or holding a mouse button restores full visibility immediately.

## ClickRipples

`Plugins/ClickRipples.ahk` creates expanding rings at each mouse-button press. The button colour comes from `SmartInputVisualsTheme.MouseColors`.

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
static DragThreshold := 20
static StrokeWidth := 3.0
static ArrowLength := 15.0
static ArrowHalfWidth := 7.0
static UpdateInterval := 33
static MinMovement := 2
```

The indicator does not appear until the pointer has moved at least `DragThreshold` pixels, so ordinary clicks do not flash a line. Rendering is limited to roughly 30 FPS and movements below `MinMovement` pixels are ignored between rendered frames. After the drag ends, the final arrow line remains fully visible for `SmartInputVisualsTheme.IdleDelay`, then fades over `SmartInputVisualsTheme.FadeDuration`. If another drag starts drawing before that idle period finishes, the previous indicator starts fading immediately while the new drag is drawn at full opacity.

DragIndicator normally uses one layered backing DIB. During the brief overlap between a fading completed drag and a newly drawn drag, a second temporary DIB retains the previous indicator independently; it is released as soon as the shared fade finishes. Surfaces otherwise remain short-lived, and a very long diagonal drag can still require a temporarily large backing surface because the bitmap must cover the line's bounding rectangle.

## MagnifierLens

`Plugins/MagnifierLens.ahk` provides a click-through lens using the Windows Magnification API. The lens stays fixed during ordinary pointer movement and follows only when the pointer moves far enough from its configured anchor position. Lens geometry uses the same physical-pixel, mixed-DPI coordinate context as the other visual plugins.

```ahk
static Magnification := 2.0
static LensWidth := 400
static LensHeight := 600
static PointerPositionX := 0.25
static PointerPositionY := 0.15
static FollowStartDistance := 20
static FollowStopDistance := 12
static MinFollowMove := 4
static UpdateInterval := 33
```

`PointerPositionX` and `PointerPositionY` use normalised values from `0.0` to `1.0`; `0.5 / 0.5` centres the preferred pointer position in the lens. The default `0.25 / 0.15` defines an anchor 25% from the left edge and 15% from the top edge. The lens remains stationary while the pointer moves inside a dead zone around that anchor. Per-axis hysteresis starts following when the pointer is at least `FollowStartDistance` (20 px) from the anchor and stops only after the pointer returns within `FollowStopDistance` (12 px). While following, the lens moves only far enough to keep the pointer near the start-distance boundary rather than re-centring it on every update. Corrections smaller than `MinFollowMove` (4 px) are ignored, reducing small window-position changes and visible jitter. Lens dimensions and follow distances are physical screen pixels. The host GUI disables AutoHotkey DPI scaling so its client area and the native magnifier child use the same physical-pixel dimensions. Near virtual-desktop edges the lens is kept on-screen and the source rectangle is adjusted accordingly. The system pointer remains normal-sized rather than being magnified.

The default magnification is the integer factor `2.0`, which maps source pixels more cleanly to output pixels and generally keeps rasterised text crisper than fractional factors. Fractional values remain supported: the source rectangle is rounded to whole desktop pixels and the transform is adjusted minimally per axis so that it fills the configured lens without a partial-pixel edge mismatch.

`MagnifierLens` deliberately uses the Windows Magnification API rather than a custom Direct3D capture pipeline with bicubic-style filtering. The latter could offer more control over resampling, but would add substantial capture, GPU and resource-management complexity for limited benefit in this lightweight overlay host.

`Core/OverlayRegistry.ahk` tracks SmartInputVisuals' top-level overlay windows. `MagnifierLens` supplies that list to the Windows magnifier filter so `KeyPressOSD`, `PointerHalo`, `ClickRipples`, `DragIndicator` and the lens host itself are excluded from the magnified source. Existing visual indicators therefore remain crisp above the lens instead of appearing a second time inside it. The filter list is refreshed only when the registered overlay-window set changes.

The lens uses the shared host timer and refreshes at most every `UpdateInterval` milliseconds; it does not create a separate polling timer. It is hidden immediately when profile, application scope, display scope, typing suppression, tray-surface suppression or the global `Enabled` switch makes the plugin ineligible.

## Visuals while typing

Keyboard activity is tracked centrally by `Core/InputActivity.ahk` using a non-blocking `InputHook`.

```ahk
static VisualsWhileTyping := false
static VisualDelayAfterTyping := 750
```

Modifier-only presses (`Ctrl`, `Shift`, `Alt`, Windows keys) do not count as typing. A normal key in a combination does; for example, pressing `Ctrl` alone does not suppress visualisations, while `Ctrl+C` does.

`VisualsWhileTyping := false` makes typing suppression the default policy. Visuals resume `VisualDelayAfterTyping` milliseconds after the last relevant key press. While typing suppression is active, `PluginManager` does not dispatch mouse or tick callbacks to plugins. A currently visible plugin receives one `Deactivated("Typing", state)` callback so it can remove its existing visualisation, then receives no normal callbacks until it becomes eligible again.

A plugin which genuinely needs to remain active while typing can explicitly opt out with:

```ahk
static AllowWhileTyping := true
```

## Application scope

`Core/AppScope.ahk` controls the focus/hover relationship required by a plugin for the application currently selected by `ProfileManager`. Application profiles decide **which plugins are enabled**; `AppScope` only decides whether an enabled plugin is currently allowed by focus/hover context.

The default application scope mode is:

```ahk
static DefaultMode := "FocusOrHover"
```

Supported modes:

| Mode | Behaviour |
|---|---|
| `Always` | Ignore focus/hover context for that plugin |
| `FocusOnly` | The profile-selected application must have focus |
| `HoverOnly` | The pointer must be over the profile-selected application |
| `FocusOrHover` | Either condition is sufficient |
| `FocusAndHover` | The profile-selected application must both have focus and be under the pointer |

Plugins may override the default application scope mode with `static ScopeMode := "..."`. `PointerHalo` defaults to `HoverOnly`; the other included plugins, including `MagnifierLens`, inherit `SmartAppScope.DefaultMode`.

There is no separate application allow-list in `AppScope`. Where visualisations are available is controlled by `Profiles/Default.ahk` and the enabled application-specific profiles in `Profiles/AppProfiles.ahk`.

Process names and window classes are cached and are resolved again only when the relevant window handle changes. SmartInputVisuals' own topmost click-through windows are skipped when resolving the application beneath the pointer. Visual plugins are suppressed over Windows taskbar/notification-area surfaces, so clicking tray icons never produces SmartInputVisuals visualisations.

### Client-area display restriction

`Core/DisplayScope.ahk` applies a separate display rule to pointer-driven visualisations. Requiring the pointer to be inside the selected application's interactive client area is the default plugin policy. Standard title bars and window borders are excluded without changing which application profile is selected.

Focus-based profile selection remains unchanged: the focused application's profile can stay selected while the pointer moves, but its pointer-driven visuals are suppressed unless the pointer is inside that selected application's interactive client area. The check combines the Windows client rectangle with `WM_NCHITTEST`, so custom title bars that are drawn inside the client rectangle but report a non-client hit-test result are excluded as well.

A plugin which intentionally needs to display outside the client area can explicitly opt out with:

```ahk
static AllowOutsideClientArea := true
```

The inexpensive client-rectangle test runs every host tick. `WM_NCHITTEST` is cached and refreshed immediately when the hovered window changes; within the same window it refreshes only after the pointer has moved at least 3 pixels and at least 50 ms have elapsed. This caps cross-window hit testing at about 20 calls per second while the pointer moves. Its timeout is limited to 5 ms; if the target application does not answer in time, the already-established client-rectangle result is used.

### Mixed-DPI displays

`Core/DpiContext.ahk` temporarily switches visual-plugin initialisation and each complete host tick to per-monitor DPI awareness. Pointer sampling, application/window geometry, display-scope checks, layered-window creation and plugin positioning therefore use one consistent physical-pixel coordinate space, including on mixed-DPI multi-monitor setups and monitors with negative screen coordinates. The previous thread DPI context is restored immediately afterwards, so SmartInputVisuals does not globally change AutoHotkey's DPI behaviour or the tray menu. On Windows versions where the thread DPI API is unavailable, the helper safely falls back to the normal AutoHotkey DPI context.

## Application-specific profiles

Profiles control **which plugins are enabled for particular applications**. `AppScope` then applies the configured focus/hover rule to the profile-selected application.

Profile selection is always part of the host architecture. `Core/ProfileManager.ahk` controls only how the application context is selected:

```ahk
static SelectionMode := "HoverThenFocus"
```

Supported selection modes:

- `HoverThenFocus` — the hovered application determines the profile; focus is used only when no hovered process can be resolved
- `FocusThenHover` — the focused application determines the profile; hover is used only when no focused process can be resolved
- `HoverOnly` — the hovered application determines the profile
- `FocusOnly` — the focused application determines the profile

For every selected application/window context, an application-specific profile is used when one is registered; otherwise the `Default` profile is used immediately. This means moving the pointer from a profiled application to an unprofiled application switches to the Default profile without requiring a focus change.

### Plugin definitions and profile states

`Profiles/Default.ahk` owns the canonical definition for every plugin. The `PluginDefinitions` Map key is the sole stable internal plugin name; it is not repeated inside the definition object:

```ahk
static PluginDefinitions := Map(
    "KeyPressOSD", PluginDefinition("KeyPressOSD"),
    "ClickRipples", PluginDefinition("ClickRipples")
)
```

A `PluginDefinition` currently contains only `DisplayName`. The included Default profile deliberately repeats the plugin name as the display name for clarity:

```text
PluginDefinitions Map key = internal/canonical plugin name
PluginDefinition.DisplayName = user-facing name
```

An empty `DisplayName` is still accepted; the effective display name then falls back to the Map key.

Although `PluginDefinition` currently wraps only one property, the class is intentionally retained rather than replacing definitions with plain strings. It gives plugin metadata an explicit type, keeps validation and configuration self-describing, and provides a stable extension point if genuine plugin-level metadata is added later. Such additions can then be made without changing the `PluginDefinitions` Map shape or conflating metadata with profile state.

Enable/disable state is deliberately **not** part of `PluginDefinition`, because it is profile configuration rather than plugin identity. Every profile uses a `PluginStates` Map. The Default profile supplies the complete baseline:

```ahk
static PluginStates := Map(
    "KeyPressOSD", false,
    "PointerHalo", false,
    "ClickRipples", true,
    "DragIndicator", false,
    "MagnifierLens", false
)
```

Every plugin in `PluginDefinitions` must have a corresponding Default `PluginStates` entry, and Default `PluginStates` may not contain unknown plugin names. This makes the baseline unambiguous.

Plugin source files are loaded by the host through the optional `#Include` directives in `SmartInputVisuals.ahk`. A plugin implemented by several source files keeps that structure inside its own source using further `#Include` directives; source paths are intentionally not part of `PluginDefinition`.

`Default.ahk` is authoritative and fail-closed: every registered plugin must have a `PluginDefinition`, duplicate effective display names are rejected, and registered plugin names without definitions cause startup errors. Definitions and Default states for optional plugin files may remain even when those files are not installed.

The included Default profile enables only `ClickRipples` by default.

### Application-profile states

Application profiles use the **same `PluginStates` structure** as the Default profile, but their Maps are partial: they contain only states that differ from or explicitly restate the Default baseline. They cannot redefine `DisplayName` or other plugin metadata.

Example:

```ahk
class PowerPointProfile {
    static Enabled := false
    static Name := "PowerPoint"
    static Applications := ["POWERPNT.EXE"]
    static PluginStates := Map(
        "KeyPressOSD", true,
        "PointerHalo", true,
        "ClickRipples", true,
        "DragIndicator", true,
        "MagnifierLens", false
    )
}
```

An application-specific profile is enabled when `Enabled` is omitted; add `static Enabled := false` to disable it. Plugin names omitted from an application profile's `PluginStates` inherit the corresponding state from the Default profile. State values must be simple `true`/`false` values.

Simple `Applications` entries are executable-name strings matched case-insensitively. A class-specific entry can instead use `Map("Process", "...", "Class", "...")`; it takes precedence over a process-only mapping for the same executable. Duplicate process-only mappings and duplicate process/class mappings are rejected during startup.

For example, a Desktop-only profile can distinguish Windows Desktop windows from ordinary File Explorer windows even though both use `explorer.exe`:

```ahk
class DesktopProfile {
    ; static Enabled := false
    static Name := "Desktop"
    static Applications := [
        Map("Process", "explorer.exe", "Class", "Progman"),
        Map("Process", "explorer.exe", "Class", "WorkerW")
    ]
    static PluginStates := Map(
        "KeyPressOSD", false,
        "PointerHalo", false,
        "ClickRipples", false,
        "DragIndicator", false,
        "MagnifierLens", false
    )
}

SmartProfileManager.Register(DesktopProfile)
```

With no separate process-only `explorer.exe` profile, ordinary File Explorer windows continue to use the Default profile. In this Desktop example every plugin is explicitly set to `false`.

Useful `explorer.exe` window classes for profile matching:

| Area | Window class | Typical use |
| --- | --- | --- |
| File Explorer | `CabinetWClass` | Normal File Explorer windows |
| Desktop | `Progman` | Primary Desktop host |
| Desktop | `WorkerW` | Desktop worker/content host |
| Primary taskbar | `Shell_TrayWnd` | Main taskbar and notification-area shell surface |
| Secondary taskbar | `Shell_SecondaryTrayWnd` | Taskbar on additional monitors |

Taskbar classes are normally handled by SmartInputVisuals' built-in tray/taskbar exclusion rather than by application profiles.

### Per-profile plugin toggles

The tray menu builds one session-only runtime toggle for every registered plugin. Optional plugin files that are absent are not listed. Items appear in plugin registration order. Plugin registration supplies the stable internal name; the matching `PluginDefinition` supplies the user-facing display name.

- Each toggle targets the profile of the foreground application/window context. Entering the taskbar, notification area or tray popup preserves the previously captured target instead of switching to a shell profile. Desktop and File Explorer windows resolve normally.
- A check mark shows the plugin's effective state for the target profile. A profile value of `false` means initially unchecked, not unavailable, so the item remains enabled and can be switched on for the current session.
- A plugin that becomes unhealthy after a callback error remains listed but is unchecked and disabled. While SmartInputVisuals is globally paused, all plugin toggles are disabled but retain their checked states.
- An accepted toggle briefly shows `<DisplayName>: ON` or `<DisplayName>: OFF` near the pointer.
- Runtime toggle states are stored separately for each profile, kept only for the current SmartInputVisuals session and reset when the script restarts.

The included definitions explicitly repeat each internal plugin name as its `DisplayName` for clarity. Change the `PluginDefinition("...")` value when a friendlier tray caption is required; passing an empty string still falls back to the `PluginDefinitions` Map key.

### Global enable toggle

The tray menu also provides `Enabled` as the global master switch, independent of application profiles. Unchecking it immediately clears active visualisations, stops the shared 20 ms host timer and stops keyboard-activity tracking. The tray menu remains available so SmartInputVisuals can be re-enabled. When re-enabled, physical mouse-button state is resynchronised before polling restarts to avoid artificial button transitions.

The `Enabled` item is checked while SmartInputVisuals is active and unchecked while it is paused. Startup behaviour is configurable in `Core/TrayController.ahk` with `static ActiveByDefault := true`; set it to `false` to start paused/unchecked. Plugin toggles appear before the global switch. While globally paused, plugin toggles are disabled but keep their checked states, and the tray icon tooltip appends `(Paused)` to the configured `APP_NAME`. Re-enabling SmartInputVisuals restores the same per-profile plugin states.

The tray menu groups per-profile plugin toggles first, in plugin registration order, then the global `Enabled` master switch, followed by Exit. AutoHotkey's standard `Suspend Hotkeys` and `Pause Script` entries are intentionally removed in favour of these SmartInputVisuals-specific controls.

When the effective configured profile state disables an already-visible plugin, the manager sends one `Deactivated("Profile", state)` callback so the plugin can clear its visualisation, then stops dispatching normal callbacks to it. If any plugin is switched off with its runtime toggle, it receives `Deactivated("RuntimeToggle", state)` and is likewise skipped until that profile's runtime toggle is enabled again.

## Plugin eligibility and lifecycle

The manager applies eligibility centrally in this order:

1. taskbar/notification-area exclusion
2. effective per-profile plugin state (`PluginStates` plus any session override)
3. focus/hover application scope
4. client-area display scope
5. pause-while-typing policy

All registered plugins are initialised at startup. `Default.PluginStates` supplies the baseline active state, application profiles may override it, and each registered plugin's tray toggle can override the effective profile state for the session. If a plugin callback throws an error, only that plugin is marked unhealthy, shut down and removed from further dispatch; the other plugins continue running and the failed plugin's tray item becomes disabled.

For profile, runtime-toggle, scope or typing transitions, an active plugin may receive one `Deactivated(reason, state)` cleanup callback. Once blocked, it receives no `WantsTick`, `Tick`, `MouseDown` or `MouseUp` calls.

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

Register a plugin with its stable internal name:

```ahk
PluginManager.Register(MyPlugin, "MyPlugin")
```

The second argument is the stable internal name. `PluginManager` resolves the corresponding `PluginDefinition` from the Default profile and retains that definition with the runtime plugin record. Registration order determines the order of plugin items in the tray menu.

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
state.HoverProcess
state.ActiveProcess
state.HoverClass
state.ActiveClass
state.HoverIsTraySurface
state.ProfileProcess
```

## Performance design

SmartInputVisuals uses one 20 ms host timer. Pointer position and mouse-button state are sampled once per tick and shared with all plugins.

The architecture avoids unnecessary work by:

- skipping plugins disabled by the active profile;
- skipping plugins disabled by their per-profile runtime toggle;
- skipping out-of-scope plugins;
- suppressing plugins while typing is active unless they explicitly opt out;
- calling `WantsTick()` only after all eligibility checks pass;
- using persistent input state instead of per-tick Maps;
- caching application process names and window classes;
- using a lightweight client-area check every tick and throttling `WM_NCHITTEST` to at most about 20 refreshes per second while the pointer moves;
- switching DPI awareness once per host tick and restoring it afterwards, keeping mixed-DPI coordinates consistent without changing global script DPI behaviour;
- using `SetWindowPos()` for unchanged moving visuals where possible;
- redrawing `PointerHalo` only when its style/opacity changes;
- ticking `ClickRipples` only while animations are active;
- throttling `DragIndicator` rendering to roughly 30 FPS, ignoring sub-2-pixel movement and releasing completed-drag surfaces after the shared fade;
- throttling `MagnifierLens` refreshes independently of the 20 ms host tick and refreshing its overlay-exclusion filter only when registered overlay windows change.

## GDI+ lifetime

`gdiplus.dll` is kept loaded for the script lifetime. `GDIPlusHost` starts GDI+ exactly once; plugins create and release their own drawing resources but never start or stop GDI+ themselves.

At exit the host stops the timer, shuts down plugins, stops keyboard activity tracking, then shuts GDI+ down last.

## Credits

SmartInputVisuals reflects a joint effort of human and machine: human design, testing and judgement combined with implementation assistance from ChatGPT.

## Licence

This project is licensed under the **Creative Commons Attribution 4.0 International licence (CC BY 4.0)**.

See [`LICENSE.md`](LICENSE.md) for details.

Official licence information: <https://creativecommons.org/licenses/by/4.0/>

SPDX identifier: `CC-BY-4.0`
