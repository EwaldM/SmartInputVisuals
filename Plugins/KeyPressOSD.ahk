; SmartKeyPressOSD plugin: KeyPressOSD
; Original text OSD functionality, implemented as an optional same-process plugin.

class KeyPressOSDPlugin {

	static HoldDelay := 700
	static OffsetX := 30
	static OffsetY := -35

	static MaxWidth := 420
	static Height := 42
	static PaddingX := 5
	static PaddingY := 7
	static FontName := "Segoe UI"
	static FontSize := 19

	static Gui := 0

	static FontFamily := 0
	static Font := 0
	static StringFormat := 0
	static Brushes := Map()
	static TextWidths := Map()

	static Hdc := 0
	static Hbm := 0
	static OldHbm := 0
	static Graphics := 0

	static Visible := false
	static CurrentMask := -1
	static CurrentText := ""
	static LastX := 0
	static LastY := 0
	static LastActiveTick := 0
	static Opacity := 255
	static CurrentWidth := 1

	static Init() {
		this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020")
		this.Gui.Show("Hide w1 h1 x0 y0")

		this.CreateTextResources()
		this.CreateRenderSurface()
		this.CacheTextWidths()
	}

	static WantsTick(state) {
		; Hidden and idle means no Tick call at all.
		return state.MouseDown || this.Visible
	}

	static Deactivated(reason, state) {
		this.Hide()
	}

	static Tick(state) {
		if !this.Gui
			return

		if state.MouseDown {
			; A plain left click intentionally produces no text OSD. If a modifier
			; or another mouse button participates, show the complete combination.
			if !this.ShouldDisplay(state) {
				if this.Visible
					this.Hide()
				return
			}

			this.LastActiveTick := A_TickCount

			mask := this.GetDisplayMask(state)
			contentChanged := (mask != this.CurrentMask)

			if contentChanged {
				parts := this.BuildParts(state)
				this.CurrentMask := mask
				this.CurrentText := this.JoinParts(parts)
				this.RenderOSD(parts)
			}

			if contentChanged || !this.Visible || this.Opacity != 255 {
				this.Opacity := 255
				this.PresentAtPointer(state.X, state.Y, 255, true)
			} else {
				this.MoveToPointer(state.X, state.Y)
			}
			return
		}

		if !this.Visible
			return

		elapsed := A_TickCount - this.LastActiveTick

		if elapsed < this.HoldDelay {
			if this.Opacity != 255 {
				this.Opacity := 255
				this.Present(this.LastX, this.LastY, this.Opacity, true)
			}
			this.Raise()
			return
		}

		fadeElapsed := elapsed - this.HoldDelay
		if fadeElapsed < SmartKeyPressTheme.FadeDuration {
			opacity := Round(255 * (1 - fadeElapsed / SmartKeyPressTheme.FadeDuration))
			opacity := Max(0, Min(255, opacity))

			if opacity != this.Opacity {
				this.Opacity := opacity
				this.Present(this.LastX, this.LastY, this.Opacity, true)
			}
			return
		}

		this.Hide()
	}

	static ShouldDisplay(state) {
		return state.MiddleM || state.RightM || state.Ctrl || state.Shift || state.Alt
	}

	static GetDisplayMask(state) {
		mask := 0
		if state.Ctrl
			mask |= 0x01
		if state.Shift
			mask |= 0x02
		if state.Alt
			mask |= 0x04
		if state.LeftM
			mask |= 0x08
		if state.MiddleM
			mask |= 0x10
		if state.RightM
			mask |= 0x20
		return mask
	}

	static BuildParts(state) {
		parts := []

		if state.Ctrl
			parts.Push("Ctrl")
		if state.Shift
			parts.Push("Shift")
		if state.Alt
			parts.Push("Alt")
		if state.LeftM
			parts.Push("LeftM")
		if state.MiddleM
			parts.Push("MiddleM")
		if state.RightM
			parts.Push("RightM")

		return parts
	}

	static JoinParts(parts) {
		text := ""
		for index, part in parts
			text .= (index > 1 ? "+" : "") part
		return text
	}

	static CreateTextResources() {
		fontFamily := 0
		status := DllCall(
			"gdiplus\GdipCreateFontFamilyFromName",
			"WStr", this.FontName,
			"Ptr", 0,
			"Ptr*", &fontFamily,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipCreateFontFamilyFromName")
		this.FontFamily := fontFamily

		font := 0
		status := DllCall(
			"gdiplus\GdipCreateFont",
			"Ptr", this.FontFamily,
			"Float", this.FontSize,
			"Int", 0,
			"Int", 2,
			"Ptr*", &font,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipCreateFont")
		this.Font := font

		genericFormat := 0
		status := DllCall(
			"gdiplus\GdipStringFormatGetGenericTypographic",
			"Ptr*", &genericFormat,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipStringFormatGetGenericTypographic")

		stringFormat := 0
		status := DllCall(
			"gdiplus\GdipCloneStringFormat",
			"Ptr", genericFormat,
			"Ptr*", &stringFormat,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipCloneStringFormat")
		this.StringFormat := stringFormat

		colours := Map(
			"Ctrl", SmartKeyPressTheme.ModifierColor,
			"Shift", SmartKeyPressTheme.ModifierColor,
			"Alt", SmartKeyPressTheme.ModifierColor,
			"LeftM", SmartKeyPressTheme.MouseColors["LeftM"],
			"MiddleM", SmartKeyPressTheme.MouseColors["MiddleM"],
			"RightM", SmartKeyPressTheme.MouseColors["RightM"],
			"+", SmartKeyPressTheme.OtherTextColor
		)

		for token, argb in colours {
			brush := 0
			status := DllCall(
				"gdiplus\GdipCreateSolidFill",
				"UInt", argb,
				"Ptr*", &brush,
				"Int"
			)
			GDIPlusHost.Check(status, "KeyPressOSD GdipCreateSolidFill")
			this.Brushes[token] := brush
		}
	}

	static CreateRenderSurface() {
		this.Hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
		if !this.Hdc
			throw OSError()

		bmi := Buffer(40, 0)
		NumPut("UInt", 40, bmi, 0)
		NumPut("Int", this.MaxWidth, bmi, 4)
		NumPut("Int", -this.Height, bmi, 8)
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
		GDIPlusHost.Check(status, "KeyPressOSD GdipCreateFromHDC")
		this.Graphics := graphics

		status := DllCall(
			"gdiplus\GdipSetCompositingMode",
			"Ptr", this.Graphics,
			"Int", 1,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipSetCompositingMode")

		status := DllCall(
			"gdiplus\GdipSetTextRenderingHint",
			"Ptr", this.Graphics,
			"Int", 3,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipSetTextRenderingHint")
	}

	static RenderOSD(parts) {
		status := DllCall(
			"gdiplus\GdipGraphicsClear",
			"Ptr", this.Graphics,
			"UInt", SmartKeyPressTheme.BackgroundColor,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipGraphicsClear")

		x := this.PaddingX
		y := this.PaddingY

		for index, part in parts {
			if index > 1 {
				this.DrawTextSegment("+", x, y, this.Brushes["+"])
				x += this.TextWidths["+"]
			}

			this.DrawTextSegment(part, x, y, this.Brushes[part])
			x += this.TextWidths[part]
		}

		this.CurrentWidth := Min(this.MaxWidth, Max(1, Ceil(x + this.PaddingX)))
	}

	static DrawTextSegment(text, x, y, brush) {
		layout := Buffer(16, 0)
		NumPut("Float", x, layout, 0)
		NumPut("Float", y, layout, 4)
		NumPut("Float", this.MaxWidth - x, layout, 8)
		NumPut("Float", this.Height - y, layout, 12)

		status := DllCall(
			"gdiplus\GdipDrawString",
			"Ptr", this.Graphics,
			"WStr", text,
			"Int", -1,
			"Ptr", this.Font,
			"Ptr", layout.Ptr,
			"Ptr", this.StringFormat,
			"Ptr", brush,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipDrawString")
	}

	static MeasureTextWidth(text) {
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
			"Ptr", this.Graphics,
			"WStr", text,
			"Int", -1,
			"Ptr", this.Font,
			"Ptr", layout.Ptr,
			"Ptr", this.StringFormat,
			"Ptr", bounds.Ptr,
			"UInt*", &charsFitted,
			"UInt*", &linesFilled,
			"Int"
		)
		GDIPlusHost.Check(status, "KeyPressOSD GdipMeasureString")

		return Ceil(NumGet(bounds, 8, "Float"))
	}

	static CacheTextWidths() {
		for _, text in ["Ctrl", "Shift", "Alt", "LeftM", "MiddleM", "RightM", "+"]
			this.TextWidths[text] := this.MeasureTextWidth(text)
	}

	static PresentAtPointer(mouseX, mouseY, opacity := 255, showWindow := false) {
		this.LastX := mouseX + this.OffsetX
		this.LastY := mouseY + this.OffsetY
		this.Present(this.LastX, this.LastY, opacity, showWindow)
	}

	static MoveToPointer(mouseX, mouseY) {
		if !this.Visible
			return

		x := mouseX + this.OffsetX
		y := mouseY + this.OffsetY

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

	static Present(x, y, opacity, showWindow := false) {
		dst := Buffer(8, 0)
		NumPut("Int", x, dst, 0)
		NumPut("Int", y, dst, 4)

		size := Buffer(8, 0)
		NumPut("Int", this.CurrentWidth, size, 0)
		NumPut("Int", this.Height, size, 4)

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

		if showWindow
			this.Visible := true
	}

	static Raise() {
		if !this.Visible
			return

		DllCall(
			"user32\SetWindowPos",
			"Ptr", this.Gui.Hwnd,
			"Ptr", -1,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"UInt", 0x0002 | 0x0001 | 0x0010,
			"Int"
		)
	}

	static Hide() {
		if this.Gui
			DllCall("user32\ShowWindow", "Ptr", this.Gui.Hwnd, "Int", 0)

		this.Visible := false
		this.CurrentMask := -1
		this.CurrentText := ""
		this.LastActiveTick := 0
		this.Opacity := 255
		this.CurrentWidth := 1
	}

	static Shutdown() {
		if !this.Gui && !this.Hdc && !this.Graphics
			return

		this.Hide()

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

		for _, brush in this.Brushes {
			if brush
				DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
		}
		this.Brushes.Clear()
		this.TextWidths.Clear()

		if this.StringFormat {
			DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", this.StringFormat)
			this.StringFormat := 0
		}

		if this.Font {
			DllCall("gdiplus\GdipDeleteFont", "Ptr", this.Font)
			this.Font := 0
		}

		if this.FontFamily {
			DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", this.FontFamily)
			this.FontFamily := 0
		}

		if this.Gui {
			this.Gui.Destroy()
			this.Gui := 0
		}
	}
}

PluginManager.Register(KeyPressOSDPlugin, "KeyPressOSD")
