; SmartInputVisuals plugin: DragIndicator
; Shows a straight dashed drag line with an arrowhead at the current position.

class DragIndicatorPlugin {

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

	static RetiredGui := 0
	static RetiredHdc := 0
	static RetiredHbm := 0
	static RetiredOldHbm := 0
	static RetiredVisible := false
	static RetiredOpacity := 255
	static RetiredFadeStartTick := 0
	static RetiredPresentX := 0
	static RetiredPresentY := 0
	static RetiredPresentWidth := 0
	static RetiredPresentHeight := 0

	static ActiveButton := ""
	static StartX := 0
	static StartY := 0
	static LastEndX := -2147483648
	static LastEndY := -2147483648
	static LastRenderTick := 0
	static DragVisualStarted := false
	static Holding := false
	static HoldStartTick := 0
	static Opacity := 255
	static LastPresentX := 0
	static LastPresentY := 0
	static LastPresentWidth := 0
	static LastPresentHeight := 0
	static Visible := false

	static Init() {
		this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
		this.Gui.Show("Hide w1 h1 x0 y0")

		this.RetiredGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
		this.RetiredGui.Show("Hide w1 h1 x0 y0")

		this.CreatePens()
	}

	static WantsTick(state) {
		return this.ActiveButton != "" || this.Visible || this.RetiredVisible
	}

	static Deactivated(reason, state) {
		this.Reset()
	}

	static MouseDown(button, state) {
		if this.ActiveButton != ""
			return

		this.ActiveButton := button
		this.StartX := state.X
		this.StartY := state.Y
		this.LastEndX := state.X
		this.LastEndY := state.Y
		this.LastRenderTick := 0
		this.DragVisualStarted := false
	}

	static MouseUp(button, state) {
		if button = this.ActiveButton
			this.EndDrag()
	}

	static Tick(state) {
		if this.RetiredVisible
			this.TickRetiredFade()

		if this.Holding
			this.TickHold()

		if this.ActiveButton = ""
			return

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
			if this.DragVisualStarted {
				if this.Visible {
					this.Hide()
					this.DestroySurface()
				}
				this.DragVisualStarted := false
			}
			return
		}

		now := A_TickCount
		if this.LastRenderTick && now - this.LastRenderTick < this.UpdateInterval
			return

		if !this.DragVisualStarted {
			if this.Holding && this.Visible
				this.StartRetiredFade()
			this.DragVisualStarted := true
		}

		this.LastEndX := state.X
		this.LastEndY := state.Y
		this.LastRenderTick := now
		this.Render(this.StartX, this.StartY, state.X, state.Y, this.ActiveButton, distance)
	}

	static CreatePens() {
		for button, colour in SmartInputVisualsTheme.MouseColors {
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

		if this.DragVisualStarted && this.Visible {
			this.Holding := true
			this.HoldStartTick := A_TickCount
			this.Opacity := 255
		}

		this.DragVisualStarted := false
	}

	static TickHold() {
		if !this.Visible {
			this.Holding := false
			this.HoldStartTick := 0
			return
		}

		if A_TickCount - this.HoldStartTick >= SmartInputVisualsTheme.IdleDelay
			this.StartRetiredFade()
	}

	static StartRetiredFade() {
		if !this.Visible || !this.Hdc {
			this.Holding := false
			this.HoldStartTick := 0
			return
		}

		if SmartInputVisualsTheme.FadeDuration <= 0 {
			this.Hide()
			this.DestroySurface()
			this.Holding := false
			this.HoldStartTick := 0
			return
		}

		this.ResetRetired()
		this.EnsureRetiredSurface(this.LastPresentWidth, this.LastPresentHeight)

		ok := DllCall(
			"gdi32\BitBlt",
			"Ptr", this.RetiredHdc,
			"Int", 0,
			"Int", 0,
			"Int", this.LastPresentWidth,
			"Int", this.LastPresentHeight,
			"Ptr", this.Hdc,
			"Int", 0,
			"Int", 0,
			"UInt", 0x00CC0020,
			"Int"
		)
		if !ok
			throw OSError()

		this.PresentRetired(
			this.LastPresentX,
			this.LastPresentY,
			this.LastPresentWidth,
			this.LastPresentHeight,
			255
		)
		this.RetiredFadeStartTick := A_TickCount

		this.Hide()
		this.DestroySurface()
		this.Holding := false
		this.HoldStartTick := 0
	}

	static TickRetiredFade() {
		if !this.RetiredVisible
			return

		elapsed := A_TickCount - this.RetiredFadeStartTick
		if elapsed >= SmartInputVisualsTheme.FadeDuration {
			this.ResetRetired()
			return
		}

		opacity := Round(255 * (1 - elapsed / SmartInputVisualsTheme.FadeDuration))
		opacity := Max(0, Min(255, opacity))

		if opacity != this.RetiredOpacity {
			this.PresentRetired(
				this.RetiredPresentX,
				this.RetiredPresentY,
				this.RetiredPresentWidth,
				this.RetiredPresentHeight,
				opacity
			)
		}
	}

	static EnsureRetiredSurface(width, height) {
		this.DestroyRetiredSurface()

		this.RetiredHdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
		if !this.RetiredHdc
			throw OSError()

		bmi := Buffer(40, 0)
		NumPut("UInt", 40, bmi, 0)
		NumPut("Int", width, bmi, 4)
		NumPut("Int", -height, bmi, 8)
		NumPut("UShort", 1, bmi, 12)
		NumPut("UShort", 32, bmi, 14)
		NumPut("UInt", 0, bmi, 16)

		bits := 0
		this.RetiredHbm := DllCall(
			"gdi32\CreateDIBSection",
			"Ptr", 0,
			"Ptr", bmi.Ptr,
			"UInt", 0,
			"Ptr*", &bits,
			"Ptr", 0,
			"UInt", 0,
			"Ptr"
		)
		if !this.RetiredHbm
			throw OSError()

		this.RetiredOldHbm := DllCall(
			"gdi32\SelectObject",
			"Ptr", this.RetiredHdc,
			"Ptr", this.RetiredHbm,
			"Ptr"
		)

	}

	static PresentRetired(x, y, width, height, opacity := 255) {
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
			"Ptr", this.RetiredGui.Hwnd,
			"Ptr", 0,
			"Ptr", dst.Ptr,
			"Ptr", size.Ptr,
			"Ptr", this.RetiredHdc,
			"Ptr", src.Ptr,
			"UInt", 0,
			"Ptr", blend.Ptr,
			"UInt", 0x2,
			"Int"
		)
		if !ok
			throw OSError()

		flags := 0x0002 | 0x0001 | 0x0010
		if !this.RetiredVisible
			flags |= 0x0040

		DllCall(
			"user32\SetWindowPos",
			"Ptr", this.RetiredGui.Hwnd,
			"Ptr", -1,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"UInt", flags,
			"Int"
		)

		this.RetiredVisible := true
		this.RetiredOpacity := opacity
		this.RetiredPresentX := x
		this.RetiredPresentY := y
		this.RetiredPresentWidth := width
		this.RetiredPresentHeight := height
	}

	static Hide() {
		if this.Gui && this.Visible
			DllCall("user32\ShowWindow", "Ptr", this.Gui.Hwnd, "Int", 0)
		this.Visible := false
	}

	static HideRetired() {
		if this.RetiredGui && this.RetiredVisible
			DllCall("user32\ShowWindow", "Ptr", this.RetiredGui.Hwnd, "Int", 0)
		this.RetiredVisible := false
	}

	static Reset() {
		this.Hide()
		this.DestroySurface()
		this.ResetRetired()
		this.ActiveButton := ""
		this.DragVisualStarted := false
		this.Holding := false
		this.HoldStartTick := 0
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

	static ResetRetired() {
		this.HideRetired()
		this.DestroyRetiredSurface()
		this.RetiredOpacity := 255
		this.RetiredFadeStartTick := 0
		this.RetiredPresentX := 0
		this.RetiredPresentY := 0
		this.RetiredPresentWidth := 0
		this.RetiredPresentHeight := 0
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

	static DestroyRetiredSurface() {
		if this.RetiredHdc && this.RetiredOldHbm
			DllCall("gdi32\SelectObject", "Ptr", this.RetiredHdc, "Ptr", this.RetiredOldHbm, "Ptr")

		if this.RetiredHbm {
			DllCall("gdi32\DeleteObject", "Ptr", this.RetiredHbm)
			this.RetiredHbm := 0
		}

		if this.RetiredHdc {
			DllCall("gdi32\DeleteDC", "Ptr", this.RetiredHdc)
			this.RetiredHdc := 0
		}

		this.RetiredOldHbm := 0
	}

	static Shutdown() {
		this.Reset()

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

		if this.RetiredGui {
			this.RetiredGui.Destroy()
			this.RetiredGui := 0
		}
	}
}

PluginManager.Register(DragIndicatorPlugin, "DragIndicator")
