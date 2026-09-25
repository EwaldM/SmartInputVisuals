; SmartKeyPressOSD plugin: DragIndicator
; Shows a straight dashed drag line with an arrowhead at the current position.

class DragIndicatorPlugin {
	static Enabled := true
	static ScopeMode := ""
	static PauseWhileTyping := true
	static RequireClientArea := true

	static DragThreshold := 6
	static StrokeWidth := 3.0
	static ArrowLength := 15.0
	static ArrowHalfWidth := 7.0
	static UpdateInterval := 33
	static MinMovement := 2
	static SurfaceQuantum := 32

	static Gui := 0
	static Hdc := 0
	static Hbm := 0
	static OldHbm := 0
	static Graphics := 0
	static CapacityWidth := 0
	static CapacityHeight := 0
	static DashedPens := Map()
	static SolidPens := Map()

	static ActiveButton := ""
	static StartX := 0
	static StartY := 0
	static LastEndX := -2147483648
	static LastEndY := -2147483648
	static LastRenderTick := 0
	static FadeStartTick := 0
	static Fading := false
	static Opacity := 255
	static LastPresentX := 0
	static LastPresentY := 0
	static LastPresentWidth := 0
	static LastPresentHeight := 0
	static Visible := false

	static Init() {
		this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
		this.Gui.Show("Hide w1 h1 x0 y0")
		this.CreatePens()
	}

	static WantsTick(state) {
		return this.ActiveButton != "" || this.Visible
	}

	static Deactivated(reason, state) {
		this.Reset()
	}

	static MouseDown(button, state) {
		if this.ActiveButton != ""
			return

		if this.Visible {
			this.Hide()
			this.DestroySurface()
		}

		this.Fading := false
		this.FadeStartTick := 0
		this.Opacity := 255
		this.ActiveButton := button
		this.StartX := state.X
		this.StartY := state.Y
		this.LastEndX := state.X
		this.LastEndY := state.Y
		this.LastRenderTick := 0
	}

	static MouseUp(button, state) {
		if button = this.ActiveButton
			this.EndDrag()
	}

	static Tick(state) {
		if this.ActiveButton = "" {
			if this.Fading
				this.TickFade()
			return
		}

		if !state.IsButtonDown(this.ActiveButton) {
			this.EndDrag()
			return
		}

		moveX := state.X - this.LastEndX
		moveY := state.Y - this.LastEndY
		if moveX * moveX + moveY * moveY < this.MinMovement * this.MinMovement
			return

		dx := state.X - this.StartX
		dy := state.Y - this.StartY
		distance := Sqrt(dx * dx + dy * dy)

		if distance < this.DragThreshold {
			if this.Visible {
				this.Hide()
				this.DestroySurface()
			}
			return
		}

		now := A_TickCount
		if this.LastRenderTick && now - this.LastRenderTick < this.UpdateInterval
			return

		this.LastEndX := state.X
		this.LastEndY := state.Y
		this.LastRenderTick := now
		this.Render(this.StartX, this.StartY, state.X, state.Y, this.ActiveButton, distance)
	}

	static CreatePens() {
		for button, colour in SmartKeyPressTheme.MouseColors {
			dashed := this.CreatePen(colour)
			status := DllCall(
				"gdiplus\GdipSetPenDashStyle",
				"Ptr", dashed,
				"Int", 1,
				"Int"
			)
			GDIPlusHost.Check(status, "DragIndicator GdipSetPenDashStyle")
			this.DashedPens[button] := dashed
			this.SolidPens[button] := this.CreatePen(colour)
		}
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
		GDIPlusHost.Check(status, "DragIndicator GdipCreatePen1")
		return pen
	}

	static Render(startX, startY, endX, endY, button, distance) {
		padding := Ceil(this.ArrowLength + this.ArrowHalfWidth + this.StrokeWidth + 4)
		left := Min(startX, endX) - padding
		top := Min(startY, endY) - padding
		right := Max(startX, endX) + padding
		bottom := Max(startY, endY) + padding
		width := Max(1, right - left)
		height := Max(1, bottom - top)

		this.EnsureSurface(width, height)

		status := DllCall(
			"gdiplus\GdipGraphicsClear",
			"Ptr", this.Graphics,
			"UInt", 0x00000000,
			"Int"
		)
		GDIPlusHost.Check(status, "DragIndicator GdipGraphicsClear")

		sx := startX - left
		sy := startY - top
		ex := endX - left
		ey := endY - top

		status := DllCall(
			"gdiplus\GdipDrawLine",
			"Ptr", this.Graphics,
			"Ptr", this.DashedPens[button],
			"Float", sx,
			"Float", sy,
			"Float", ex,
			"Float", ey,
			"Int"
		)
		GDIPlusHost.Check(status, "DragIndicator GdipDrawLine")

		ux := (endX - startX) / distance
		uy := (endY - startY) / distance
		perpX := -uy
		perpY := ux
		baseX := ex - ux * this.ArrowLength
		baseY := ey - uy * this.ArrowLength
		leftArrowX := baseX + perpX * this.ArrowHalfWidth
		leftArrowY := baseY + perpY * this.ArrowHalfWidth
		rightArrowX := baseX - perpX * this.ArrowHalfWidth
		rightArrowY := baseY - perpY * this.ArrowHalfWidth

		pen := this.SolidPens[button]
		this.DrawSolidLine(pen, ex, ey, leftArrowX, leftArrowY)
		this.DrawSolidLine(pen, ex, ey, rightArrowX, rightArrowY)

		this.Present(left, top, width, height, 255)
	}

	static DrawSolidLine(pen, x1, y1, x2, y2) {
		status := DllCall(
			"gdiplus\GdipDrawLine",
			"Ptr", this.Graphics,
			"Ptr", pen,
			"Float", x1,
			"Float", y1,
			"Float", x2,
			"Float", y2,
			"Int"
		)
		GDIPlusHost.Check(status, "DragIndicator arrow GdipDrawLine")
	}

	static EnsureSurface(requiredWidth, requiredHeight) {
		if this.Graphics && requiredWidth <= this.CapacityWidth && requiredHeight <= this.CapacityHeight
			return

		newWidth := Ceil(requiredWidth / this.SurfaceQuantum) * this.SurfaceQuantum
		newHeight := Ceil(requiredHeight / this.SurfaceQuantum) * this.SurfaceQuantum

		this.DestroySurface()

		this.Hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
		if !this.Hdc
			throw OSError()

		bmi := Buffer(40, 0)
		NumPut("UInt", 40, bmi, 0)
		NumPut("Int", newWidth, bmi, 4)
		NumPut("Int", -newHeight, bmi, 8)
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
		GDIPlusHost.Check(status, "DragIndicator GdipCreateFromHDC")
		this.Graphics := graphics

		status := DllCall(
			"gdiplus\GdipSetCompositingMode",
			"Ptr", this.Graphics,
			"Int", 1,
			"Int"
		)
		GDIPlusHost.Check(status, "DragIndicator GdipSetCompositingMode")

		status := DllCall(
			"gdiplus\GdipSetSmoothingMode",
			"Ptr", this.Graphics,
			"Int", 4,
			"Int"
		)
		GDIPlusHost.Check(status, "DragIndicator GdipSetSmoothingMode")

		this.CapacityWidth := newWidth
		this.CapacityHeight := newHeight
	}

	static Present(x, y, width, height, opacity := 255) {
		dst := Buffer(8, 0)
		NumPut("Int", x, dst, 0)
		NumPut("Int", y, dst, 4)

		size := Buffer(8, 0)
		NumPut("Int", width, size, 0)
		NumPut("Int", height, size, 4)

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
		this.Opacity := opacity
		this.LastPresentX := x
		this.LastPresentY := y
		this.LastPresentWidth := width
		this.LastPresentHeight := height
	}

	static EndDrag() {
		this.ActiveButton := ""
		this.LastRenderTick := 0

		if !this.Visible {
			this.Reset()
			return
		}

		if SmartKeyPressTheme.FadeDuration <= 0 {
			this.Reset()
			return
		}

		this.FadeStartTick := A_TickCount
		this.Fading := true
	}

	static TickFade() {
		if !this.Visible {
			this.Reset()
			return
		}

		elapsed := A_TickCount - this.FadeStartTick
		if elapsed >= SmartKeyPressTheme.FadeDuration {
			this.Reset()
			return
		}

		opacity := Round(255 * (1 - elapsed / SmartKeyPressTheme.FadeDuration))
		opacity := Max(0, Min(255, opacity))

		if opacity != this.Opacity {
			this.Present(
				this.LastPresentX,
				this.LastPresentY,
				this.LastPresentWidth,
				this.LastPresentHeight,
				opacity
			)
		}
	}

	static Hide() {
		if this.Gui && this.Visible
			DllCall("user32\ShowWindow", "Ptr", this.Gui.Hwnd, "Int", 0)
		this.Visible := false
	}

	static Reset() {
		this.Hide()
		this.DestroySurface()
		this.ActiveButton := ""
		this.Fading := false
		this.FadeStartTick := 0
		this.Opacity := 255
		this.LastPresentX := 0
		this.LastPresentY := 0
		this.LastPresentWidth := 0
		this.LastPresentHeight := 0
		this.StartX := 0
		this.StartY := 0
		this.LastEndX := -2147483648
		this.LastEndY := -2147483648
		this.LastRenderTick := 0
	}

	static DestroySurface() {
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

		this.OldHbm := 0
		this.CapacityWidth := 0
		this.CapacityHeight := 0
	}

	static Shutdown() {
		this.Reset()
		this.DestroySurface()

		for _, pen in this.DashedPens {
			if pen
				DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
		}
		this.DashedPens.Clear()

		for _, pen in this.SolidPens {
			if pen
				DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
		}
		this.SolidPens.Clear()

		if this.Gui {
			this.Gui.Destroy()
			this.Gui := 0
		}
	}
}

PluginManager.Register(DragIndicatorPlugin, "DragIndicator")
