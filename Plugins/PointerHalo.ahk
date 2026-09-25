; SmartKeyPressOSD plugin: PointerHalo
; Draws a hollow ring centred on the pointer and fades it after mouse inactivity.

class PointerHaloPlugin {
	static Enabled := true
	static ScopeMode := "HoverOnly"
	static PauseWhileTyping := true
	static RequireClientArea := true

	static Diameter := 65
	static StrokeWidth := 3.0
	static NeutralColor := 0xA08B008B

	static IdleFadeEnabled := true
	static IdleDelay := 2500

	static Gui := 0
	static Hdc := 0
	static Hbm := 0
	static OldHbm := 0
	static Graphics := 0
	static Pens := Map()

	static Visible := false
	static CurrentStyle := ""
	static Opacity := 255
	static LastX := -2147483648
	static LastY := -2147483648

	static Init() {
		this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
		this.Gui.Show("Hide w1 h1 x0 y0")

		this.CreateSurface()
		this.CreatePens()
	}

	static WantsTick(state) {
		; The halo needs host ticks to follow motion and detect idle/resume state.
		return !!this.Gui
	}

	static Deactivated(reason, state) {
		this.Hide(true)
	}

	static Tick(state) {
		if state.LeftM
			style := "LeftM"
		else if state.MiddleM
			style := "MiddleM"
		else if state.RightM
			style := "RightM"
		else
			style := "Neutral"

		opacity := 255

		if this.IdleFadeEnabled && !state.MouseDown {
			idleElapsed := A_TickCount - state.LastMouseMoveTick

			if idleElapsed >= this.IdleDelay + SmartKeyPressTheme.IdleFadeDuration {
				this.Hide(false)
				return
			}

			if idleElapsed >= this.IdleDelay && SmartKeyPressTheme.IdleFadeDuration > 0 {
				fadeElapsed := idleElapsed - this.IdleDelay
				opacity := Round(255 * (1 - fadeElapsed / SmartKeyPressTheme.IdleFadeDuration))
				opacity := Max(0, Min(255, opacity))
			}
		}

		styleChanged := (style != this.CurrentStyle)
		if styleChanged {
			this.Render(style)
			this.CurrentStyle := style
		}

		if !this.Visible || styleChanged || opacity != this.Opacity {
			this.Opacity := opacity
			this.Present(state.X, state.Y, opacity, true)
		} else if state.MouseMoved {
			this.Move(state.X, state.Y)
		}
	}

	static CreateSurface() {
		size := this.Diameter

		this.Hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
		if !this.Hdc
			throw OSError()

		bmi := Buffer(40, 0)
		NumPut("UInt", 40, bmi, 0)
		NumPut("Int", size, bmi, 4)
		NumPut("Int", -size, bmi, 8)
		NumPut("UShort", 1, bmi, 12)
		NumPut("UShort", 32, bmi, 14)
		NumPut("UInt", 0, bmi, 16)

		bits := 0
		this.Hbm := DllCall(
			"gdi32\CreateDIBSection",
			"Ptr", 0,
			"Ptr", bmi.Ptr,
			"UInt", 0,
			"Ptr*", &bits,
			"Ptr", 0,
			"UInt", 0,
			"Ptr"
		)
		if !this.Hbm
			throw OSError()

		this.OldHbm := DllCall(
			"gdi32\SelectObject",
			"Ptr", this.Hdc,
			"Ptr", this.Hbm,
			"Ptr"
		)

		graphics := 0
		status := DllCall(
			"gdiplus\GdipCreateFromHDC",
			"Ptr", this.Hdc,
			"Ptr*", &graphics,
			"Int"
		)
		GDIPlusHost.Check(status, "PointerHalo GdipCreateFromHDC")
		this.Graphics := graphics

		status := DllCall(
			"gdiplus\GdipSetCompositingMode",
			"Ptr", this.Graphics,
			"Int", 1,
			"Int"
		)
		GDIPlusHost.Check(status, "PointerHalo GdipSetCompositingMode")

		status := DllCall(
			"gdiplus\GdipSetSmoothingMode",
			"Ptr", this.Graphics,
			"Int", 4,
			"Int"
		)
		GDIPlusHost.Check(status, "PointerHalo GdipSetSmoothingMode")
	}

	static CreatePens() {
		this.Pens["Neutral"] := this.CreatePen(this.NeutralColor)

		for button, colour in SmartKeyPressTheme.MouseColors
			this.Pens[button] := this.CreatePen(colour)
	}

	static CreatePen(argb) {
		pen := 0
		status := DllCall(
			"gdiplus\GdipCreatePen1",
			"UInt", argb,
			"Float", this.StrokeWidth,
			"Int", 2,
			"Ptr*", &pen,
			"Int"
		)
		GDIPlusHost.Check(status, "PointerHalo GdipCreatePen1")
		return pen
	}

	static Render(style) {
		status := DllCall(
			"gdiplus\GdipGraphicsClear",
			"Ptr", this.Graphics,
			"UInt", 0x00000000,
			"Int"
		)
		GDIPlusHost.Check(status, "PointerHalo GdipGraphicsClear")

		inset := Ceil(this.StrokeWidth / 2) + 1
		diameter := this.Diameter - (inset * 2)

		status := DllCall(
			"gdiplus\GdipDrawEllipse",
			"Ptr", this.Graphics,
			"Ptr", this.Pens[style],
			"Float", inset,
			"Float", inset,
			"Float", diameter,
			"Float", diameter,
			"Int"
		)
		GDIPlusHost.Check(status, "PointerHalo GdipDrawEllipse")
	}

	static Present(mouseX, mouseY, opacity := 255, showWindow := false) {
		x := Round(mouseX - this.Diameter / 2)
		y := Round(mouseY - this.Diameter / 2)

		dst := Buffer(8, 0)
		NumPut("Int", x, dst, 0)
		NumPut("Int", y, dst, 4)

		size := Buffer(8, 0)
		NumPut("Int", this.Diameter, size, 0)
		NumPut("Int", this.Diameter, size, 4)

		src := Buffer(8, 0)

		blend := Buffer(4, 0)
		NumPut("UChar", 0, blend, 0)
		NumPut("UChar", 0, blend, 1)
		NumPut("UChar", opacity, blend, 2)
		NumPut("UChar", 1, blend, 3)

		ok := DllCall(
			"user32\UpdateLayeredWindow",
			"Ptr", this.Gui.Hwnd,
			"Ptr", 0,
			"Ptr", dst.Ptr,
			"Ptr", size.Ptr,
			"Ptr", this.Hdc,
			"Ptr", src.Ptr,
			"UInt", 0,
			"Ptr", blend.Ptr,
			"UInt", 0x2,
			"Int"
		)
		if !ok
			throw OSError()

		flags := 0x0002 | 0x0001 | 0x0010
		if showWindow
			flags |= 0x0040

		DllCall(
			"user32\SetWindowPos",
			"Ptr", this.Gui.Hwnd,
			"Ptr", -1,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"UInt", flags,
			"Int"
		)

		this.Visible := true
		this.LastX := x
		this.LastY := y
	}

	static Move(mouseX, mouseY) {
		x := Round(mouseX - this.Diameter / 2)
		y := Round(mouseY - this.Diameter / 2)

		if x = this.LastX && y = this.LastY
			return

		DllCall(
			"user32\SetWindowPos",
			"Ptr", this.Gui.Hwnd,
			"Ptr", -1,
			"Int", x,
			"Int", y,
			"Int", 0,
			"Int", 0,
			"UInt", 0x0001 | 0x0010,
			"Int"
		)

		this.LastX := x
		this.LastY := y
	}

	static Hide(resetStyle := false) {
		if this.Gui && this.Visible
			DllCall("user32\ShowWindow", "Ptr", this.Gui.Hwnd, "Int", 0)

		this.Visible := false
		this.Opacity := 255
		this.LastX := -2147483648
		this.LastY := -2147483648

		if resetStyle
			this.CurrentStyle := ""
	}

	static Shutdown() {
		if !this.Gui && !this.Hdc && !this.Graphics
			return

		this.Hide(true)

		for _, pen in this.Pens {
			if pen
				DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
		}
		this.Pens.Clear()

		if this.Graphics {
			DllCall("gdiplus\GdipDeleteGraphics", "Ptr", this.Graphics)
			this.Graphics := 0
		}

		if this.Hdc && this.OldHbm
			DllCall("gdi32\SelectObject", "Ptr", this.Hdc, "Ptr", this.OldHbm, "Ptr")

		if this.Hbm {
			DllCall("gdi32\DeleteObject", "Ptr", this.Hbm)
			this.Hbm := 0
		}

		if this.Hdc {
			DllCall("gdi32\DeleteDC", "Ptr", this.Hdc)
			this.Hdc := 0
		}

		if this.Gui {
			this.Gui.Destroy()
			this.Gui := 0
		}
	}
}

PluginManager.Register(PointerHaloPlugin, "PointerHalo")
