; SmartKeyPressOSD plugin: ClickRipples
; Creates expanding concentric rings at each mouse-button press.

class ClickRipplesPlugin {
	static Enabled := true
	static ScopeMode := "" ; empty = inherit SmartAppScope.Mode
	static PauseWhileTyping := true
	static RequireClientArea := true

	static Lifetime := 650
	static MaxRadius := 52
	static MinRadius := 7
	static RingGap := 6
	static RingCount := 3
	static StrokeWidth := 3.0
	static MaxActiveRipples := 6

	static Ripples := []

	static WantsTick(state) {
		; No animation means no Tick calls for this plugin.
		return this.Enabled && this.Ripples.Length > 0
	}

	static Deactivated(reason, state) {
		this.ClearRipples()
	}

	static MouseDown(button, state) {
		if !this.Enabled
			return

		while this.Ripples.Length >= this.MaxActiveRipples {
			oldRipple := this.Ripples.RemoveAt(1)
			oldRipple.Dispose()
		}

		colour := SmartKeyPressTheme.MouseColors[button]
		this.Ripples.Push(
			ClickRippleEffect(
				state.X,
				state.Y,
				colour,
				this.Lifetime,
				this.MinRadius,
				this.MaxRadius,
				this.RingGap,
				this.RingCount,
				this.StrokeWidth
			)
		)
	}

	static Tick(state) {
		now := A_TickCount

		Loop this.Ripples.Length {
			index := this.Ripples.Length - A_Index + 1
			ripple := this.Ripples[index]

			if !ripple.Update(now) {
				ripple.Dispose()
				this.Ripples.RemoveAt(index)
			}
		}
	}

	static ClearRipples() {
		for ripple in this.Ripples
			ripple.Dispose()
		this.Ripples := []
	}

	static Shutdown() {
		this.ClearRipples()
	}
}

class ClickRippleEffect {
	__New(x, y, colour, lifetime, minRadius, maxRadius, ringGap, ringCount, strokeWidth) {
		this.X := x
		this.Y := y
		this.BaseRGB := colour & 0x00FFFFFF
		this.StartTick := A_TickCount

		this.Lifetime := lifetime
		this.MinRadius := minRadius
		this.MaxRadius := maxRadius
		this.RingGap := ringGap
		this.RingCount := ringCount
		this.StrokeWidth := strokeWidth

		this.Size := Ceil((maxRadius + strokeWidth + 3) * 2)

		this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
		this.Gui.Show("Hide w1 h1 x0 y0")

		this.Hdc := 0
		this.Hbm := 0
		this.OldHbm := 0
		this.Graphics := 0
		this.Pen := 0
		this.Visible := false
		this.Disposed := false

		this.CreateSurface()
		this.CreatePen()
	}

	CreateSurface() {
		this.Hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
		if !this.Hdc
			throw OSError()

		bmi := Buffer(40, 0)
		NumPut("UInt", 40, bmi, 0)
		NumPut("Int", this.Size, bmi, 4)
		NumPut("Int", -this.Size, bmi, 8)
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
		GDIPlusHost.Check(status, "ClickRipples GdipCreateFromHDC")
		this.Graphics := graphics

		status := DllCall(
			"gdiplus\GdipSetCompositingMode",
			"Ptr", this.Graphics,
			"Int", 1,
			"Int"
		)
		GDIPlusHost.Check(status, "ClickRipples GdipSetCompositingMode")

		status := DllCall(
			"gdiplus\GdipSetSmoothingMode",
			"Ptr", this.Graphics,
			"Int", 4,
			"Int"
		)
		GDIPlusHost.Check(status, "ClickRipples GdipSetSmoothingMode")
	}

	CreatePen() {
		pen := 0
		status := DllCall(
			"gdiplus\GdipCreatePen1",
			"UInt", 0xFF000000 | this.BaseRGB,
			"Float", this.StrokeWidth,
			"Int", 2,
			"Ptr*", &pen,
			"Int"
		)
		GDIPlusHost.Check(status, "ClickRipples GdipCreatePen1")
		this.Pen := pen
	}

	Update(now) {
		if this.Disposed
			return false

		elapsed := now - this.StartTick
		if elapsed >= this.Lifetime
			return false

		progress := elapsed / this.Lifetime
		radius := this.MinRadius + ((this.MaxRadius - this.MinRadius) * progress)
		alpha := Round(220 * (1 - progress))
		alpha := Max(0, Min(255, alpha))

		status := DllCall(
			"gdiplus\GdipGraphicsClear",
			"Ptr", this.Graphics,
			"UInt", 0x00000000,
			"Int"
		)
		GDIPlusHost.Check(status, "ClickRipples GdipGraphicsClear")

		centre := this.Size / 2

		Loop this.RingCount {
			ringRadius := radius - ((A_Index - 1) * this.RingGap)
			if ringRadius <= 2
				continue

			ringAlpha := Max(0, Round(alpha * (1 - ((A_Index - 1) * 0.16))))
			argb := ((ringAlpha & 0xFF) << 24) | this.BaseRGB

			status := DllCall(
				"gdiplus\GdipSetPenColor",
				"Ptr", this.Pen,
				"UInt", argb,
				"Int"
			)
			GDIPlusHost.Check(status, "ClickRipples GdipSetPenColor")

			status := DllCall(
				"gdiplus\GdipDrawEllipse",
				"Ptr", this.Graphics,
				"Ptr", this.Pen,
				"Float", centre - ringRadius,
				"Float", centre - ringRadius,
				"Float", ringRadius * 2,
				"Float", ringRadius * 2,
				"Int"
			)
			GDIPlusHost.Check(status, "ClickRipples GdipDrawEllipse")
		}

		this.Present()
		return true
	}

	Present() {
		x := Round(this.X - this.Size / 2)
		y := Round(this.Y - this.Size / 2)

		dst := Buffer(8, 0)
		NumPut("Int", x, dst, 0)
		NumPut("Int", y, dst, 4)

		size := Buffer(8, 0)
		NumPut("Int", this.Size, size, 0)
		NumPut("Int", this.Size, size, 4)

		src := Buffer(8, 0)

		blend := Buffer(4, 0)
		NumPut("UChar", 0, blend, 0)
		NumPut("UChar", 0, blend, 1)
		NumPut("UChar", 255, blend, 2)
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
		if !this.Visible
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
	}

	Dispose() {
		if this.Disposed
			return

		this.Disposed := true

		if this.Gui
			DllCall("user32\ShowWindow", "Ptr", this.Gui.Hwnd, "Int", 0)

		if this.Pen {
			DllCall("gdiplus\GdipDeletePen", "Ptr", this.Pen)
			this.Pen := 0
		}

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

PluginManager.Register(ClickRipplesPlugin, "ClickRipples")
