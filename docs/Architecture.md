# Architecture

Runtime architecture and implementation notes for SmartInputVisuals, including capture behaviour, DPI handling, plugin lifecycle, shared state and performance design.

[Back to README](../README.md) · [Configuration](Configuration.md) · [Plugins](Plugins.md)

## Screen sharing

When sharing an entire desktop or monitor in Microsoft Teams or Zoom, SmartInputVisuals overlays are normally included because they are ordinary top-level windows and are not marked for capture exclusion. When sharing a single application window, they are normally not included because the overlays belong to the AutoHotkey process rather than the shared application. File-based presentation modes such as PowerPoint Live do not include them.

Capture behaviour can vary: Teams and Zoom may use different capture backends depending on the Windows version, graphics hardware and application version. Test the intended sharing mode on the target system when reliable overlay visibility matters.

## Mixed-DPI displays


`Core/DpiContext.ahk` temporarily switches visual-plugin initialisation and each complete host tick to per-monitor DPI awareness. Pointer sampling, application/window geometry, display-scope checks, layered-window creation and plugin positioning therefore use one consistent physical-pixel coordinate space, including on mixed-DPI multi-monitor setups and monitors with negative screen coordinates. The previous thread DPI context is restored immediately afterwards, so SmartInputVisuals does not globally change AutoHotkey's DPI behaviour or the tray menu. On Windows versions where the thread DPI API is unavailable, the helper safely falls back to the normal AutoHotkey DPI context.

## Plugin eligibility and lifecycle

The manager applies eligibility centrally in this order:

1. taskbar/notification-area exclusion
2. SmartInputVisuals interactive-host-UI exclusion
3. effective per-profile plugin state (`PluginStates` plus any session override)
4. focus/hover application scope
5. client-area display scope
6. pause-while-typing policy

Only registered plugins that are present in the `PluginDefinitions` whitelist are initialised at startup. A missing Default `PluginStates` entry means OFF, application profiles may override the Default state, and each available plugin's tray or toolbar toggle can override the effective profile state for the session. Registered but non-whitelisted plugins remain unavailable without an error. If a plugin callback throws an error, only that plugin is marked unhealthy, shut down and removed from further dispatch; the other plugins continue running, the failed plugin disappears from the toolbar, and its tray item becomes disabled.

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

