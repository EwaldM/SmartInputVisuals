# Plugins

Detailed configuration and behaviour of the visual plugins included with SmartInputVisuals.

[Back to README](../README.md) · [Configuration](Configuration.md) · [Architecture](Architecture.md)

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

`Core/OverlayRegistry.ahk` tracks SmartInputVisuals' top-level overlay windows. `MagnifierLens` supplies that list to the Windows magnifier filter so `KeyPressOSD`, `PointerHalo`, `ClickRipples`, `DragIndicator`, the plugin toolbar and the lens host itself are excluded from the magnified source. Existing visual indicators and host controls therefore remain crisp above the lens instead of appearing a second time inside it. The filter list is refreshed only when the registered overlay-window set changes.

The lens uses the shared host timer and refreshes at most every `UpdateInterval` milliseconds; it does not create a separate polling timer. It is hidden immediately when profile, application scope, display scope, typing suppression, tray-surface suppression or the global `Enabled` switch makes the plugin ineligible.

