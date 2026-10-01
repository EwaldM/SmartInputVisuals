; SmartInputVisuals plugin: MagnifierLens
; Displays a click-through magnified lens around the pointer using the Windows Magnification API.

#DllLoad "Magnification.dll"

class MagnifierLensPlugin {
	static Magnification := 2.0
	static LensWidth := 400
	static LensHeight := 600
	static PointerPositionX := 0.25
	static PointerPositionY := 0.25
	static UpdateInterval := 33

	static Gui := 0
	static MagnifierHwnd := 0
	static RuntimeInitialised := false
	static Visible := false
	static FilterGeneration := -1
	static LastRefreshTick := 0
	static LastHostX := -2147483648
	static LastHostY := -2147483648

	static Init() {
		this.ValidateConfiguration()
	}

	static Activated(state) {
		this.EnsureReady()
		this.LastRefreshTick := 0
	}

	static Deactivated(reason, state) {
		this.Hide()
	}

	static WantsTick(state) {
		return true
	}

	static Tick(state) {
		this.EnsureReady()

		now := A_TickCount
		if this.Visible && now - this.LastRefreshTick < this.UpdateInterval
			return

		this.RefreshFilterList()
		geometry := this.CalculateGeometry(state.X, state.Y)

		if !this.SetSourceRectangle(
			geometry.SourceLeft,
			geometry.SourceTop,
			geometry.SourceRight,
			geometry.SourceBottom
		)
			throw OSError()

		if !this.Visible || geometry.HostX != this.LastHostX || geometry.HostY != this.LastHostY {
			flags := 0x0001 | 0x0004 | 0x0010 ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
			if !this.Visible
				flags |= 0x0040 ; SWP_SHOWWINDOW

			if !DllCall(
				"user32\SetWindowPos",
				"Ptr", this.Gui.Hwnd,
				"Ptr", 0,
				"Int", geometry.HostX,
				"Int", geometry.HostY,
				"Int", 0,
				"Int", 0,
				"UInt", flags,
				"Int"
			)
				throw OSError()

			this.Visible := true
			this.LastHostX := geometry.HostX
			this.LastHostY := geometry.HostY
		}

		DllCall(
			"user32\InvalidateRect",
			"Ptr", this.MagnifierHwnd,
			"Ptr", 0,
			"Int", true,
			"Int"
		)

		this.LastRefreshTick := now
	}

	static ValidateConfiguration() {
		if this.Magnification < 1.0
			throw Error("MagnifierLens Magnification must be at least 1.0.")
		if this.LensWidth < 1 || this.LensHeight < 1
			throw Error("MagnifierLens LensWidth and LensHeight must be positive.")
		if this.PointerPositionX < 0 || this.PointerPositionX > 1
			throw Error("MagnifierLens PointerPositionX must be between 0.0 and 1.0.")
		if this.PointerPositionY < 0 || this.PointerPositionY > 1
			throw Error("MagnifierLens PointerPositionY must be between 0.0 and 1.0.")
		if this.UpdateInterval < 0
			throw Error("MagnifierLens UpdateInterval must not be negative.")
	}

	static EnsureReady() {
		if !this.RuntimeInitialised {
			if !DllCall("Magnification\MagInitialize", "Int")
				throw OSError()
			this.RuntimeInitialised := true
		}

		if this.Gui
			return

		this.CreateWindow()
		this.SetTransform()
		this.RefreshFilterList(true)
	}

	static CreateWindow() {
		this.Gui := Gui(
			"+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020 +0x02000000"
		)
		this.Gui.Show(
			"Hide x0 y0 w" Round(this.LensWidth) " h" Round(this.LensHeight)
		)

		clientRect := Buffer(16, 0)
		if !DllCall(
			"user32\GetClientRect",
			"Ptr", this.Gui.Hwnd,
			"Ptr", clientRect.Ptr,
			"Int"
		)
			throw OSError()

		clientWidth := NumGet(clientRect, 8, "Int")
		clientHeight := NumGet(clientRect, 12, "Int")

		if !DllCall(
			"user32\SetLayeredWindowAttributes",
			"Ptr", this.Gui.Hwnd,
			"UInt", 0,
			"UChar", 255,
			"UInt", 0x00000002, ; LWA_ALPHA
			"Int"
		)
			throw OSError()

		instance := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
		this.MagnifierHwnd := DllCall(
			"user32\CreateWindowExW",
			"UInt", 0,
			"WStr", "Magnifier",
			"WStr", "SmartInputVisuals MagnifierLens",
			"UInt", 0x40000000 | 0x10000000, ; WS_CHILD | WS_VISIBLE
			"Int", 0,
			"Int", 0,
			"Int", clientWidth,
			"Int", clientHeight,
			"Ptr", this.Gui.Hwnd,
			"Ptr", 0,
			"Ptr", instance,
			"Ptr", 0,
			"Ptr"
		)
		if !this.MagnifierHwnd
			throw OSError()

		SmartOverlayRegistry.Register(this.Gui.Hwnd)
		SmartOverlayRegistry.PlaceBelowRegistered(this.Gui.Hwnd)
		this.FilterGeneration := -1
	}

	static SetTransform() {
		renderGeometry := this.GetRenderGeometry()
		transform := Buffer(36, 0)
		NumPut("Float", renderGeometry.ScaleX, transform, 0)
		NumPut("Float", renderGeometry.ScaleY, transform, 16)
		NumPut("Float", 1.0, transform, 32)

		if !DllCall(
			"Magnification\MagSetWindowTransform",
			"Ptr", this.MagnifierHwnd,
			"Ptr", transform.Ptr,
			"Int"
		)
			throw OSError()
	}

	static GetRenderGeometry() {
		lensWidth := Round(this.LensWidth)
		lensHeight := Round(this.LensHeight)
		sourceWidth := Max(1, Round(lensWidth / this.Magnification))
		sourceHeight := Max(1, Round(lensHeight / this.Magnification))

		; RECT uses integer source pixels. Derive the transform from those rounded
		; dimensions so fractional magnification does not leave a partial-pixel
		; mismatch at the lens edges. Integer factors remain exact.
		return {
			LensWidth: lensWidth,
			LensHeight: lensHeight,
			SourceWidth: sourceWidth,
			SourceHeight: sourceHeight,
			ScaleX: lensWidth / sourceWidth,
			ScaleY: lensHeight / sourceHeight
		}
	}

	static RefreshFilterList(force := false) {
		if !this.MagnifierHwnd
			return

		if !force && this.FilterGeneration = SmartOverlayRegistry.Generation
			return

		windows := SmartOverlayRegistry.GetWindows()
		count := windows.Length
		hwndBuffer := 0

		if count > 0 {
			hwndBuffer := Buffer(count * A_PtrSize, 0)
			for index, hwnd in windows
				NumPut("Ptr", hwnd, hwndBuffer, (index - 1) * A_PtrSize)
		}

		if !DllCall(
			"Magnification\MagSetWindowFilterList",
			"Ptr", this.MagnifierHwnd,
			"UInt", 0, ; MW_FILTERMODE_EXCLUDE
			"Int", count,
			"Ptr", count > 0 ? hwndBuffer.Ptr : 0,
			"Int"
		)
			throw OSError()

		this.FilterGeneration := SmartOverlayRegistry.Generation
	}

	static CalculateGeometry(mouseX, mouseY) {
		renderGeometry := this.GetRenderGeometry()
		lensWidth := renderGeometry.LensWidth
		lensHeight := renderGeometry.LensHeight

		virtualLeft := DllCall("user32\GetSystemMetrics", "Int", 76, "Int")
		virtualTop := DllCall("user32\GetSystemMetrics", "Int", 77, "Int")
		virtualWidth := DllCall("user32\GetSystemMetrics", "Int", 78, "Int")
		virtualHeight := DllCall("user32\GetSystemMetrics", "Int", 79, "Int")
		virtualRight := virtualLeft + virtualWidth
		virtualBottom := virtualTop + virtualHeight

		desiredHostX := Round(mouseX - lensWidth * this.PointerPositionX)
		desiredHostY := Round(mouseY - lensHeight * this.PointerPositionY)
		hostX := this.Clamp(desiredHostX, virtualLeft, virtualRight - lensWidth)
		hostY := this.Clamp(desiredHostY, virtualTop, virtualBottom - lensHeight)

		pointerOutputX := mouseX - hostX
		pointerOutputY := mouseY - hostY
		sourceWidth := renderGeometry.SourceWidth
		sourceHeight := renderGeometry.SourceHeight
		desiredSourceLeft := Round(mouseX - pointerOutputX / renderGeometry.ScaleX)
		desiredSourceTop := Round(mouseY - pointerOutputY / renderGeometry.ScaleY)
		sourceLeft := this.Clamp(
			desiredSourceLeft,
			virtualLeft,
			virtualRight - sourceWidth
		)
		sourceTop := this.Clamp(
			desiredSourceTop,
			virtualTop,
			virtualBottom - sourceHeight
		)

		return {
			HostX: hostX,
			HostY: hostY,
			SourceLeft: sourceLeft,
			SourceTop: sourceTop,
			SourceRight: sourceLeft + sourceWidth,
			SourceBottom: sourceTop + sourceHeight
		}
	}

	static Clamp(value, minimum, maximum) {
		if maximum < minimum
			return minimum
		return Min(maximum, Max(minimum, value))
	}

	static SetSourceRectangle(left, top, right, bottom) {
		if A_PtrSize = 8 {
			rect := Buffer(16, 0)
			NumPut("Int", left, rect, 0)
			NumPut("Int", top, rect, 4)
			NumPut("Int", right, rect, 8)
			NumPut("Int", bottom, rect, 12)

			; RECT is passed indirectly by the Windows x64 ABI.
			return DllCall(
				"Magnification\MagSetWindowSource",
				"Ptr", this.MagnifierHwnd,
				"Ptr", rect.Ptr,
				"Int"
			)
		}

		; On 32-bit Windows RECT is passed by value. Four Int arguments place the
		; same 16 bytes on the stdcall stack in the required order.
		return DllCall(
			"Magnification\MagSetWindowSource",
			"Ptr", this.MagnifierHwnd,
			"Int", left,
			"Int", top,
			"Int", right,
			"Int", bottom,
			"Int"
		)
	}

	static Hide() {
		if this.Gui && this.Visible
			DllCall("user32\ShowWindow", "Ptr", this.Gui.Hwnd, "Int", 0)

		this.Visible := false
		this.LastHostX := -2147483648
		this.LastHostY := -2147483648
		this.LastRefreshTick := 0
	}

	static Shutdown() {
		this.Hide()

		if this.Gui {
			SmartOverlayRegistry.Unregister(this.Gui.Hwnd)
			this.Gui.Destroy()
			this.Gui := 0
		}

		this.MagnifierHwnd := 0
		this.FilterGeneration := -1

		if this.RuntimeInitialised {
			DllCall("Magnification\MagUninitialize", "Int")
			this.RuntimeInitialised := false
		}
	}
}

PluginManager.Register(MagnifierLensPlugin, "MagnifierLens")
