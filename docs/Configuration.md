# Configuration

User-facing configuration for typing suppression, application scope, profiles, plugin availability/state, toolbar behaviour and tray controls.

[Back to README](../README.md) · [Plugins](Plugins.md) · [Architecture](Architecture.md)

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

Process names and window classes are cached and are resolved again only when the relevant window handle changes. SmartInputVisuals' own topmost windows are skipped when resolving the application beneath the pointer. Interactive host windows such as the plugin toolbar preserve the underlying external application/profile instead of becoming a profile-selection target themselves, and visual plugins are suppressed while the pointer is over that host UI. Visual plugins are also suppressed over Windows taskbar/notification-area surfaces, so clicking tray icons never produces SmartInputVisuals visualisations.

### Client-area display restriction

`Core/DisplayScope.ahk` applies a separate display rule to pointer-driven visualisations. Requiring the pointer to be inside the selected application's interactive client area is the default plugin policy. Standard title bars and window borders are excluded without changing which application profile is selected.

Focus-based profile selection remains unchanged: the focused application's profile can stay selected while the pointer moves, but its pointer-driven visuals are suppressed unless the pointer is inside that selected application's interactive client area. The check combines the Windows client rectangle with `WM_NCHITTEST`, so custom title bars that are drawn inside the client rectangle but report a non-client hit-test result are excluded as well.

A plugin which intentionally needs to display outside the client area can explicitly opt out with:

```ahk
static AllowOutsideClientArea := true
```

The inexpensive client-rectangle test runs every host tick. `WM_NCHITTEST` is cached and refreshed immediately when the hovered window changes; within the same window it refreshes only after the pointer has moved at least 3 pixels and at least 50 ms have elapsed. This caps cross-window hit testing at about 20 calls per second while the pointer moves. Its timeout is limited to 5 ms; if the target application does not answer in time, the already-established client-rectangle result is used.

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

### Toolbar configuration

`Profiles/Default.ahk` defines the toolbar's startup position, shared opacity and RGB colours together:

```ahk
static Toolbar := {
    X: 20,
    Y: 20,
    Opacity: 170,
    ShowProfileName: true,
    Layout: "H",
    ButtonHeight: 44,
    ButtonPaddingX: 14,
    ButtonSpacing: 6,
    BackgroundColor: 0x202020,
    ButtonColor: 0x404040,
    TextColor: 0xFFFFFF
}
```

`X` and `Y` are the initial screen coordinates. Positioning uses the toolbar HWND directly, so the configured position is applied even while the GUI is initially hidden. `Opacity` uses the Windows transparency range `1..255`, where `255` is fully opaque and lower values make the complete toolbar more translucent; the default is `170`. `ShowProfileName: true` shows the active profile name in the toolbar title. When set to `false`, the title shows the SmartInputVisuals application name, i.e. the same name used by the `Exit SmartInputVisuals` tray item. `Layout` accepts the deliberately short values `"H"` (horizontal) and `"V"` (vertical). AutoHotkey has no native enum type, so the two validated string values keep the configuration concise without introducing opaque numeric constants. In horizontal layout, buttons remain in one row and use individual widths. In vertical layout, buttons form one column and all use the width required by the longest button caption. The title never determines the toolbar width; if its text is longer than the width established by the buttons, it is truncated with an ellipsis.

`ButtonHeight`, `ButtonPaddingX` and `ButtonSpacing` are optional touch-oriented sizing settings. The supplied Default profile uses `44`, `14` and `6` respectively to provide larger touch targets and more separation. They may be removed independently for backward-compatible behaviour: missing `ButtonHeight` falls back to the previous `26` px height, missing `ButtonSpacing` falls back to the previous `4` px gap, and missing `ButtonPaddingX` preserves the original width formula exactly (`Max(64, 20 + textWidth)`) rather than inventing an equivalent padding value. When `ButtonPaddingX` is configured, the calculated text width receives that many pixels of padding on both the left and right sides. The same sizing rules apply to horizontal and vertical layouts; vertical layout still makes all buttons as wide as the longest required caption.

`BackgroundColor` sets the toolbar/title background, `ButtonColor` sets the plugin-button face, and `TextColor` is used for both the title and button captions. Colours are `0xRRGGBB` integer values. The buttons remain normal AutoHotkey `Button` controls for interaction. SmartInputVisuals explicitly changes their Win32 button type to `BS_OWNERDRAW` and handles `WM_DRAWITEM`, allowing `ButtonColor` and `TextColor` to control their painted appearance while retaining normal button click/focus behaviour. The toolbar is clamped to the virtual desktop when it starts. Dragging the title area moves the toolbar for the current session only; SmartInputVisuals does not rewrite `Default.ahk`.

### Plugin definitions and profile states

**`PluginDefinitions` is the explicit availability whitelist for plugins.** A plugin implementation can be present and register successfully without appearing in this Map; in that case it remains unavailable, is not initialised, does not appear on the toolbar, and is shown disabled in the tray/context menu. This makes removing one definition sufficient to take a plugin out of service without changing its source or deleting its preserved profile states.

`Profiles/Default.ahk` owns this whitelist. The `PluginDefinitions` Map key is the sole stable internal plugin name; it is not repeated inside the definition object:

```ahk
static PluginDefinitions := Map(
    "KeyPressOSD", PluginDefinition("Keys"),
    "PointerHalo", PluginDefinition("Halo"),
    "ClickRipples", PluginDefinition("Clicks"),
    "DragIndicator", PluginDefinition("Drag"),
    "MagnifierLens", PluginDefinition("Lens")
)
```

A `PluginDefinition` currently contains only `DisplayName`:

```text
PluginDefinitions Map key = internal/canonical plugin name and whitelist membership
PluginDefinition.DisplayName = user-facing name
```

An empty `DisplayName` is accepted; the effective display name then falls back to the Map key. A registered plugin with no definition therefore also falls back to its registered internal name in the disabled tray entry.

Although `PluginDefinition` currently wraps only one property, the class is intentionally retained rather than replacing definitions with plain strings. It gives plugin metadata an explicit type, keeps validation and configuration self-describing, and provides a stable extension point if genuine plugin-level metadata is added later. Such additions can then be made without changing the `PluginDefinitions` Map shape or conflating metadata with profile state.

Enable/disable state is deliberately **not** part of `PluginDefinition`, because it is profile configuration rather than plugin identity. Every profile uses a `PluginStates` Map. The Default profile supplies explicit baseline states where needed:

```ahk
static PluginStates := Map(
    "KeyPressOSD", false,
    "PointerHalo", false,
    "ClickRipples", true,
    "DragIndicator", false,
    "MagnifierLens", false
)
```

For a whitelisted plugin, a missing entry in Default `PluginStates` means **OFF**. Application profiles may still override that default. `PluginStates` entries for names which are currently outside the `PluginDefinitions` whitelist are intentionally inert rather than erroneous; they can remain in Default or application profiles and become effective again if that plugin is later added back to the whitelist.

Plugin source files are loaded by the host through the optional `#Include` directives in `SmartInputVisuals.ahk`. A plugin implemented by several source files keeps that structure inside its own source using further `#Include` directives; source paths are intentionally not part of `PluginDefinition`.

Definitions for optional plugin source files may remain in the whitelist even when those files are not installed; without registration there is simply no runtime plugin to list or initialise. Duplicate effective display names among definitions are rejected.

The included Default profile enables only `ClickRipples` by default.

### Application-profile states

Application profiles use the **same `PluginStates` structure** as the Default profile, but their Maps are partial: they contain only states that differ from or explicitly restate the Default baseline. They cannot redefine `DisplayName` or other plugin metadata, and entries for plugins outside the current whitelist remain inert.

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

An application-specific profile is enabled when `Enabled` is omitted; add `static Enabled := false` to disable it. Plugin names omitted from an application profile's `PluginStates` inherit the corresponding Default state; if that Default state is also omitted, the plugin is OFF. State values must be simple `true`/`false` values.

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

### Plugin toolbar

`Core/PluginToolbar.ahk` provides a compact always-on-top toolbar. It is built from the **available** registered plugins, so buttons appear in plugin registration order and use each plugin's `DisplayName`. Registered plugins which are outside the `PluginDefinitions` whitelist, or which are unhealthy, are not shown on the toolbar.

The toolbar title is left-aligned above the buttons. By default it shows the current profile name; `ShowProfileName: false` switches it to the SmartInputVisuals application name. `Layout: "H"` places the buttons in the current horizontal row. `Layout: "V"` places them in a vertical column with one common width based on the longest button caption, which is more suitable for longer display names. The title uses the width established by the buttons and is truncated with an ellipsis when necessary rather than widening the toolbar. The entire title region remains the drag handle; the button area itself does not drag the window. The toolbar has no close button. Its visibility is controlled only by the single `Toolbar` item in the tray menu, which is checked while the toolbar is visible. The toolbar starts visible by default.

Button captions intentionally use a compact textual state:

```text
✓ Keys    enabled for the current profile
  Halo    disabled for the current profile
```

Unavailable plugins are omitted from the toolbar entirely. Available buttons toggle the same session-only per-profile runtime state used by the tray menu. While SmartInputVisuals is globally paused, the buttons are disabled but retain their ON/OFF captions. The toolbar uses `WS_EX_NOACTIVATE`, so clicking it does not intentionally steal focus from the controlled application. It is also registered as a SmartInputVisuals host surface: profile resolution looks through it to the external application beneath it, while plugin mouse visualisations are suppressed over the toolbar itself.

### Per-profile plugin toggles

The tray menu builds one entry for every registered plugin. Optional plugin files that are absent are not listed. Items appear in plugin registration order. For whitelisted plugins, the matching `PluginDefinition` supplies the user-facing display name; registered plugins outside the whitelist fall back to their internal registration name.

- Each toggle targets the profile of the foreground application/window context. Entering the taskbar, notification area or tray popup preserves the previously captured target instead of switching to a shell profile. Desktop and File Explorer windows resolve normally.
- A check mark shows the plugin's effective state for the target profile. A profile value of `false` means initially unchecked, not unavailable, so the item remains enabled and can be switched on for the current session.
- A registered plugin outside the `PluginDefinitions` whitelist remains listed but is unchecked and disabled. A plugin that becomes unhealthy after a callback error behaves the same way. Neither condition produces a toolbar button. While SmartInputVisuals is globally paused, all available plugin toggles are disabled but retain their checked states.
- An accepted toggle briefly shows `<DisplayName>: ON` or `<DisplayName>: OFF` near the pointer.
- Runtime toggle states are stored separately for each profile, kept only for the current SmartInputVisuals session and reset when the script restarts.

The included definitions use concise display names (`Keys`, `Halo`, `Clicks`, `Drag`, `Lens`). Change the `PluginDefinition("...")` value to customise the user-facing tray and toolbar text; passing an empty string still falls back to the `PluginDefinitions` Map key.

### Global enable toggle

The tray menu also provides `Enabled` as the global master switch, independent of application profiles. Unchecking it immediately clears active visualisations, stops the shared 20 ms host timer and stops keyboard-activity tracking. The tray menu remains available so SmartInputVisuals can be re-enabled. When re-enabled, physical mouse-button state is resynchronised before polling restarts to avoid artificial button transitions.

The `Enabled` item is checked while SmartInputVisuals is active and unchecked while it is paused. Startup behaviour is configurable in `Core/TrayController.ahk` with `static ActiveByDefault := true`; set it to `false` to start paused/unchecked. Plugin toggles appear before the global switch. While globally paused, plugin toggles are disabled but keep their checked states, and the tray icon tooltip appends `(Paused)` to the configured `APP_NAME`. Re-enabling SmartInputVisuals restores the same per-profile plugin states.

The tray menu begins with a normal-looking informational item such as `Profile: PowerPoint`, followed by a separator. Selecting that item intentionally performs no action. This shows the profile currently targeted by the tray plugin toggles. Per-profile plugin toggles follow in plugin registration order, then `Toolbar`, the global `Enabled` master switch, and Exit. `Toolbar` is a single checked/unchecked item rather than a submenu. AutoHotkey's standard `Suspend Hotkeys` and `Pause Script` entries are intentionally removed in favour of these SmartInputVisuals-specific controls.

When the effective configured profile state disables an already-visible plugin, the manager sends one `Deactivated("Profile", state)` callback so the plugin can clear its visualisation, then stops dispatching normal callbacks to it. If any plugin is switched off with its runtime toggle, it receives `Deactivated("RuntimeToggle", state)` and is likewise skipped until that profile's runtime toggle is enabled again.

