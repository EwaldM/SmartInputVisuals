; SmartKeyPressOSD
; Mouse-button and modifier on-screen display for AutoHotkey v2

#Requires AutoHotkey v2.0
#SingleInstance Force
#DllLoad "gdiplus.dll"

InstallKeybdHook()
InstallMouseHook()
CoordMode("Mouse", "Screen")

; =============================================================================
; Configuration
; =============================================================================
OSD_POLL_INTERVAL := 20    ; ms; also controls drag-follow smoothness
OSD_HOLD_DELAY    := 700   ; ms to remain fully visible after mouse release
OSD_FADE_DURATION := 450   ; ms fade-out duration
OSD_OFFSET_X      := 20
OSD_OFFSET_Y      := 80

OSD_MAX_WIDTH     := 420   ; maximum backing-surface width
OSD_HEIGHT        := 42
OSD_PADDING_X     := 5
OSD_PADDING_Y     := 7
OSD_FONT_NAME     := "Segoe UI"
OSD_FONT_SIZE     := 19    ; GDI+ pixels, not points

; Window background: yellow at 25% opacity.
; 25% of 255 is approximately 64 = 0x40 alpha.
OSD_BACKGROUND_ARGB := 0x40FFFF00

; ARGB colours used by GDI+.
OSD_COLORS := Map(
    "Ctrl",    0xFFFFA500,  ; orange
    "Shift",   0xFFFFA500,
    "Alt",     0xFFFFA500,
    "LeftM",   0xFF0000FF,  ; blue
    "MiddleM", 0xFF008000,  ; green
    "RightM",  0xFFFF0000,  ; red
    "+",       0xFF000000   ; black
)

; =============================================================================
; Persistent click-through layered window
;
; WS_EX_LAYERED     0x00080000
; WS_EX_TRANSPARENT 0x00000020
; WS_EX_NOACTIVATE  0x08000000
; =============================================================================
OSDGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
OSDGui.Show("Hide w1 h1 x0 y0")

; =============================================================================
; GDI+ / rendering state
; =============================================================================
GdipToken := 0
OSDFontFamily := 0
OSDFont := 0
OSDStringFormat := 0
OSDBrushes := Map()
OSDTextWidths := Map()

OSDHdc := 0
OSDHbm := 0
OSDOldHbm := 0
OSDGraphics := 0

OSDVisible := false
OSDCurrentText := ""
OSDLastX := 0
OSDLastY := 0
OSDLastActiveTick := 0
OSDOpacity := 255
OSDCurrentWidth := 1

InitGDIPlus()
CreateRenderSurface()
CacheTextWidths()
OnExit(Cleanup)

SetTimer(OSDTick, OSD_POLL_INTERVAL)

; =============================================================================
; Main loop
; =============================================================================
OSDTick() {
    global OSDVisible, OSDCurrentText, OSDLastActiveTick, OSDOpacity
    global OSDLastX, OSDLastY
    global OSD_HOLD_DELAY, OSD_FADE_DURATION

    state := ReadPhysicalState()

    ; A display event exists only while at least one mouse button is physically
    ; down. Modifier-only typing therefore never creates or refreshes the OSD.
    if state.mouseDown {
        OSDLastActiveTick := A_TickCount

        contentChanged := (state.text != OSDCurrentText)
        if contentChanged {
            OSDCurrentText := state.text
            RenderOSD(state.parts)
        }

        ; Recompose the layered bitmap only when something visual changed, the
        ; window is not yet visible, or a new mouse press interrupts a fade.
        ; Ordinary drag-follow movement uses SetWindowPos() only.
        if contentChanged || !OSDVisible || OSDOpacity != 255 {
            OSDOpacity := 255
            PresentOSDAtMouse(255, true)
        } else {
            MoveOSDToMouse()
        }
        return
    }

    if !OSDVisible
        return

    elapsed := A_TickCount - OSDLastActiveTick

    ; Keep the final mouse/modifier snapshot fully visible for a short time.
    if elapsed < OSD_HOLD_DELAY {
        if OSDOpacity != 255 {
            OSDOpacity := 255
            PresentOSD(OSDLastX, OSDLastY, OSDOpacity, true)
        }
        RaiseOSD()
        return
    }

    fadeElapsed := elapsed - OSD_HOLD_DELAY

    ; Fade smoothly using UpdateLayeredWindow's SourceConstantAlpha. The bitmap
    ; itself is not redrawn, so the antialiased glyph edges remain unchanged.
    if fadeElapsed < OSD_FADE_DURATION {
        opacity := Round(255 * (1 - fadeElapsed / OSD_FADE_DURATION))
        opacity := Max(0, Min(255, opacity))

        if opacity != OSDOpacity {
            OSDOpacity := opacity
            PresentOSD(OSDLastX, OSDLastY, OSDOpacity, true)
        }
        return
    }

    HideOSD()
}

ReadPhysicalState() {
    parts := []

    lmbDown := GetKeyState("LButton", "P")
    mmbDown := GetKeyState("MButton", "P")
    rmbDown := GetKeyState("RButton", "P")
    mouseDown := lmbDown || mmbDown || rmbDown

    ; Do not show modifiers by themselves. They are included only as context for
    ; an actual mouse-button press/drag.
    if !mouseDown {
        return {
            text: "",
            parts: parts,
            mouseDown: false
        }
    }

    ctrlDown := GetKeyState("LCtrl", "P") || GetKeyState("RCtrl", "P")
    shiftDown := GetKeyState("LShift", "P") || GetKeyState("RShift", "P")
    altDown := GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P")

    if ctrlDown
        parts.Push("Ctrl")
    if shiftDown
        parts.Push("Shift")
    if altDown
        parts.Push("Alt")
    if lmbDown
        parts.Push("LeftM")
    if mmbDown
        parts.Push("MiddleM")
    if rmbDown
        parts.Push("RightM")

    return {
        text: JoinParts(parts),
        parts: parts,
        mouseDown: true
    }
}

JoinParts(parts) {
    text := ""
    for index, part in parts
        text .= (index > 1 ? "+" : "") part
    return text
}

; =============================================================================
; Crisp per-pixel-alpha text rendering
; =============================================================================
InitGDIPlus() {
    global GdipToken, OSDFontFamily, OSDFont, OSDStringFormat, OSDBrushes
    global OSD_FONT_NAME, OSD_FONT_SIZE, OSD_COLORS

    startupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, startupInput, 0)

    status := DllCall(
        "gdiplus\GdiplusStartup",
        "UPtr*", &GdipToken,
        "Ptr", startupInput.Ptr,
        "Ptr", 0,
        "Int"
    )
    CheckGdip(status, "GdiplusStartup")

    status := DllCall(
        "gdiplus\GdipCreateFontFamilyFromName",
        "WStr", OSD_FONT_NAME,
        "Ptr", 0,
        "Ptr*", &OSDFontFamily,
        "Int"
    )
    CheckGdip(status, "GdipCreateFontFamilyFromName")

    ; FontStyleRegular = 0, UnitPixel = 2.
    status := DllCall(
        "gdiplus\GdipCreateFont",
        "Ptr", OSDFontFamily,
        "Float", OSD_FONT_SIZE,
        "Int", 0,
        "Int", 2,
        "Ptr*", &OSDFont,
        "Int"
    )
    CheckGdip(status, "GdipCreateFont")

    genericFormat := 0
    status := DllCall(
        "gdiplus\GdipStringFormatGetGenericTypographic",
        "Ptr*", &genericFormat,
        "Int"
    )
    CheckGdip(status, "GdipStringFormatGetGenericTypographic")

    status := DllCall(
        "gdiplus\GdipCloneStringFormat",
        "Ptr", genericFormat,
        "Ptr*", &OSDStringFormat,
        "Int"
    )
    CheckGdip(status, "GdipCloneStringFormat")

    for token, argb in OSD_COLORS {
        brush := 0
        status := DllCall(
            "gdiplus\GdipCreateSolidFill",
            "UInt", argb,
            "Ptr*", &brush,
            "Int"
        )
        CheckGdip(status, "GdipCreateSolidFill")
        OSDBrushes[token] := brush
    }
}

CreateRenderSurface() {
    global OSDHdc, OSDHbm, OSDOldHbm, OSDGraphics
    global OSD_MAX_WIDTH, OSD_HEIGHT

    OSDHdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
    if !OSDHdc
        throw OSError()

    bmi := Buffer(40, 0)
    NumPut("UInt", 40, bmi, 0)             ; BITMAPINFOHEADER.biSize
    NumPut("Int", OSD_MAX_WIDTH, bmi, 4)
    NumPut("Int", -OSD_HEIGHT, bmi, 8)    ; top-down DIB
    NumPut("UShort", 1, bmi, 12)          ; planes
    NumPut("UShort", 32, bmi, 14)         ; BGRA
    NumPut("UInt", 0, bmi, 16)            ; BI_RGB

    bits := 0
    OSDHbm := DllCall(
        "gdi32\CreateDIBSection",
        "Ptr", 0,
        "Ptr", bmi.Ptr,
        "UInt", 0,
        "Ptr*", &bits,
        "Ptr", 0,
        "UInt", 0,
        "Ptr"
    )
    if !OSDHbm
        throw OSError()

    OSDOldHbm := DllCall(
        "gdi32\SelectObject",
        "Ptr", OSDHdc,
        "Ptr", OSDHbm,
        "Ptr"
    )

    status := DllCall(
        "gdiplus\GdipCreateFromHDC",
        "Ptr", OSDHdc,
        "Ptr*", &OSDGraphics,
        "Int"
    )
    CheckGdip(status, "GdipCreateFromHDC")

    ; SourceCopy preserves GDI+'s antialiased per-pixel alpha exactly.
    status := DllCall(
        "gdiplus\GdipSetCompositingMode",
        "Ptr", OSDGraphics,
        "Int", 1,  ; CompositingModeSourceCopy
        "Int"
    )
    CheckGdip(status, "GdipSetCompositingMode")

    ; TextRenderingHintAntiAliasGridFit = 3. Unlike ClearType, grayscale
    ; antialiasing works correctly on a transparent per-pixel-alpha surface.
    status := DllCall(
        "gdiplus\GdipSetTextRenderingHint",
        "Ptr", OSDGraphics,
        "Int", 3,
        "Int"
    )
    CheckGdip(status, "GdipSetTextRenderingHint")
}

RenderOSD(parts) {
    global OSDGraphics, OSDFont, OSDStringFormat, OSDBrushes, OSDTextWidths
    global OSD_MAX_WIDTH, OSD_HEIGHT, OSD_PADDING_X, OSD_PADDING_Y
    global OSDCurrentWidth
    global OSD_BACKGROUND_ARGB

    ; Fill the complete layered-window surface with a 25%-opaque yellow.
    ; The later SourceConstantAlpha fade multiplies this alpha as the OSD fades.
    status := DllCall(
        "gdiplus\GdipGraphicsClear",
        "Ptr", OSDGraphics,
        "UInt", OSD_BACKGROUND_ARGB,
        "Int"
    )
    CheckGdip(status, "GdipGraphicsClear")

    x := OSD_PADDING_X
    y := OSD_PADDING_Y

    for index, part in parts {
        if index > 1 {
            DrawTextSegment("+", x, y, OSDBrushes["+"])
            x += OSDTextWidths["+"]
        }

        DrawTextSegment(part, x, y, OSDBrushes[part])
        x += OSDTextWidths[part]
    }

    ; Present only the width actually needed for the rendered text, including
    ; left/right padding. The backing bitmap remains fixed-size for efficiency.
    OSDCurrentWidth := Min(OSD_MAX_WIDTH, Max(1, Ceil(x + OSD_PADDING_X)))
}

DrawTextSegment(text, x, y, brush) {
    global OSDGraphics, OSDFont, OSDStringFormat, OSD_MAX_WIDTH, OSD_HEIGHT

    layout := Buffer(16, 0)
    NumPut("Float", x, layout, 0)
    NumPut("Float", y, layout, 4)
    NumPut("Float", OSD_MAX_WIDTH - x, layout, 8)
    NumPut("Float", OSD_HEIGHT - y, layout, 12)

    status := DllCall(
        "gdiplus\GdipDrawString",
        "Ptr", OSDGraphics,
        "WStr", text,
        "Int", -1,
        "Ptr", OSDFont,
        "Ptr", layout.Ptr,
        "Ptr", OSDStringFormat,
        "Ptr", brush,
        "Int"
    )
    CheckGdip(status, "GdipDrawString")
}

MeasureTextWidth(text) {
    global OSDGraphics, OSDFont, OSDStringFormat

    layout := Buffer(16, 0)
    NumPut("Float", 0, layout, 0)
    NumPut("Float", 0, layout, 4)
    NumPut("Float", 1000, layout, 8)
    NumPut("Float", 100, layout, 12)

    bounds := Buffer(16, 0)
    charsFitted := 0
    linesFilled := 0

    status := DllCall(
        "gdiplus\GdipMeasureString",
        "Ptr", OSDGraphics,
        "WStr", text,
        "Int", -1,
        "Ptr", OSDFont,
        "Ptr", layout.Ptr,
        "Ptr", OSDStringFormat,
        "Ptr", bounds.Ptr,
        "UInt*", &charsFitted,
        "UInt*", &linesFilled,
        "Int"
    )
    CheckGdip(status, "GdipMeasureString")

    return Ceil(NumGet(bounds, 8, "Float"))
}

CacheTextWidths() {
    global OSDTextWidths

    ; These are the only strings the OSD renders. Measure each one once at
    ; startup instead of calling GdipMeasureString whenever modifiers change.
    for _, text in ["Ctrl", "Shift", "Alt", "LeftM", "MiddleM", "RightM", "+"]
        OSDTextWidths[text] := MeasureTextWidth(text)
}

; =============================================================================
; Presentation / position / fade
; UpdateLayeredWindow is used only for bitmap/size/opacity changes.
; Drag movement itself is handled by SetWindowPos().
; =============================================================================
PresentOSDAtMouse(opacity := 255, showWindow := false) {
    global OSD_OFFSET_X, OSD_OFFSET_Y
    global OSDLastX, OSDLastY

    MouseGetPos(&mx, &my)
    OSDLastX := mx + OSD_OFFSET_X
    OSDLastY := my + OSD_OFFSET_Y

    PresentOSD(OSDLastX, OSDLastY, opacity, showWindow)
}

MoveOSDToMouse() {
    global OSDGui, OSDVisible, OSD_OFFSET_X, OSD_OFFSET_Y
    global OSDLastX, OSDLastY

    if !OSDVisible
        return

    MouseGetPos(&mx, &my)
    x := mx + OSD_OFFSET_X
    y := my + OSD_OFFSET_Y

    ; Movement does not require UpdateLayeredWindow. SetWindowPos moves the
    ; already-composited layered window and reasserts HWND_TOPMOST.
    ; SWP_NOSIZE | SWP_NOACTIVATE = 0x0001 | 0x0010.
    DllCall(
        "user32\SetWindowPos",
        "Ptr", OSDGui.Hwnd,
        "Ptr", -1,                    ; HWND_TOPMOST
        "Int", x,
        "Int", y,
        "Int", 0,
        "Int", 0,
        "UInt", 0x0001 | 0x0010,
        "Int"
    )

    OSDLastX := x
    OSDLastY := y
}

PresentOSD(x, y, opacity, showWindow := false) {
    global OSDGui, OSDHdc, OSDCurrentWidth, OSD_HEIGHT, OSDVisible

    dst := Buffer(8, 0)
    NumPut("Int", x, dst, 0)
    NumPut("Int", y, dst, 4)

    size := Buffer(8, 0)
    NumPut("Int", OSDCurrentWidth, size, 0)
    NumPut("Int", OSD_HEIGHT, size, 4)

    src := Buffer(8, 0) ; source point 0,0

    blend := Buffer(4, 0)
    NumPut("UChar", 0, blend, 0)        ; AC_SRC_OVER
    NumPut("UChar", 0, blend, 1)
    NumPut("UChar", opacity, blend, 2)  ; SourceConstantAlpha
    NumPut("UChar", 1, blend, 3)        ; AC_SRC_ALPHA

    ok := DllCall(
        "user32\UpdateLayeredWindow",
        "Ptr", OSDGui.Hwnd,
        "Ptr", 0,
        "Ptr", dst.Ptr,
        "Ptr", size.Ptr,
        "Ptr", OSDHdc,
        "Ptr", src.Ptr,
        "UInt", 0,
        "Ptr", blend.Ptr,
        "UInt", 0x2, ; ULW_ALPHA
        "Int"
    )
    if !ok
        throw OSError()

    ; Reassert the topmost Z-order. This also keeps the OSD above Windows' drag
    ; image while a drag operation is in progress.
    flags := 0x0002 | 0x0001 | 0x0010 ; NOMOVE | NOSIZE | NOACTIVATE
    if showWindow
        flags |= 0x0040                ; SHOWWINDOW

    DllCall(
        "user32\SetWindowPos",
        "Ptr", OSDGui.Hwnd,
        "Ptr", -1,                    ; HWND_TOPMOST
        "Int", 0,
        "Int", 0,
        "Int", 0,
        "Int", 0,
        "UInt", flags,
        "Int"
    )

    if showWindow
        OSDVisible := true
}

RaiseOSD() {
    global OSDGui, OSDVisible

    if !OSDVisible
        return

    DllCall(
        "user32\SetWindowPos",
        "Ptr", OSDGui.Hwnd,
        "Ptr", -1,
        "Int", 0,
        "Int", 0,
        "Int", 0,
        "Int", 0,
        "UInt", 0x0002 | 0x0001 | 0x0010,
        "Int"
    )
}

HideOSD() {
    global OSDGui, OSDVisible, OSDCurrentText, OSDLastActiveTick, OSDOpacity, OSDCurrentWidth

    DllCall("user32\ShowWindow", "Ptr", OSDGui.Hwnd, "Int", 0)
    OSDVisible := false
    OSDCurrentText := ""
    OSDLastActiveTick := 0
    OSDOpacity := 255
    OSDCurrentWidth := 1
}

; =============================================================================
; Cleanup / helpers
; =============================================================================
Cleanup(*) {
    global OSDGraphics, OSDHdc, OSDHbm, OSDOldHbm
    global OSDBrushes, OSDTextWidths, OSDStringFormat, OSDFont, OSDFontFamily, GdipToken

    if OSDGraphics {
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", OSDGraphics)
        OSDGraphics := 0
    }

    if OSDHdc && OSDOldHbm
        DllCall("gdi32\SelectObject", "Ptr", OSDHdc, "Ptr", OSDOldHbm, "Ptr")

    if OSDHbm {
        DllCall("gdi32\DeleteObject", "Ptr", OSDHbm)
        OSDHbm := 0
    }

    if OSDHdc {
        DllCall("gdi32\DeleteDC", "Ptr", OSDHdc)
        OSDHdc := 0
    }

    for _, brush in OSDBrushes {
        if brush
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }
    OSDBrushes.Clear()
    OSDTextWidths.Clear()

    if OSDStringFormat {
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", OSDStringFormat)
        OSDStringFormat := 0
    }

    if OSDFont {
        DllCall("gdiplus\GdipDeleteFont", "Ptr", OSDFont)
        OSDFont := 0
    }

    if OSDFontFamily {
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", OSDFontFamily)
        OSDFontFamily := 0
    }

    if GdipToken {
        ; Keep gdiplus.dll resident until the matching shutdown call.
        ; Clear the global token first so Cleanup() remains idempotent.
        token := GdipToken
        GdipToken := 0
        DllCall("gdiplus\GdiplusShutdown", "UPtr", token)
    }
}

CheckGdip(status, operation) {
    if status != 0
        throw Error(operation " failed (GDI+ status " status ").")
}
