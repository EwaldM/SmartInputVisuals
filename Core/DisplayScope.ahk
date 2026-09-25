; SmartInputVisuals - display scope filtering
; Keeps pointer-driven visualisations inside the selected application's client area.

class SmartDisplayScope {
	static LastHitHwnd := 0
	static LastHitX := 0
	static LastHitY := 0
	static LastHitIsClient := false
	static LastHitTick := 0
	static LastHitValid := false

	static HitTestInterval := 50
	static HitTestMovement := 3
	static HitTestTimeout := 5

	static Update(state) {
		if !state.HoverHwnd {
			state.DisplayAllowed := false
			return
		}

		; Profile selection and display eligibility are deliberately separate.
		; A focus-based profile may remain selected while the pointer moves, but
		; pointer-driven visuals are shown only over the selected application/window
		; context. This also distinguishes class-specific profiles which share a
		; process, such as the Windows Desktop and File Explorer.
		if state.ProfileProcess != "" {
			if !SmartProfileManager.ContextMatchesSelectedApplication(
				state.HoverProcess,
				state.HoverClass,
				state
			) {
				state.DisplayAllowed := false
				return
			}
		}

		state.DisplayAllowed := this.PointInInteractiveClientArea(
			state.HoverHwnd,
			state.X,
			state.Y
		)
	}

	static IsPluginAllowed(plugin, state) {
		allowOutsideClientArea := false
		try allowOutsideClientArea := !!plugin.AllowOutsideClientArea
		catch
			allowOutsideClientArea := false

		if allowOutsideClientArea
			return true

		return state.DisplayAllowed
	}

	static PointInInteractiveClientArea(hwnd, x, y) {
		if !this.PointInClientRect(hwnd, x, y)
			return false

		; GetClientRect excludes conventional non-client chrome. WM_NCHITTEST
		; additionally catches applications that extend or draw their title bar
		; inside the client rectangle but still report it as HTCAPTION or another
		; non-client hit-test result.
		return this.HitTestSaysClient(hwnd, x, y)
	}

	static PointInClientRect(hwnd, x, y) {
		if !hwnd
			return false

		rect := Buffer(16, 0)
		if !DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect.Ptr, "Int")
			return false

		width := NumGet(rect, 8, "Int")
		height := NumGet(rect, 12, "Int")
		if width <= 0 || height <= 0
			return false

		origin := Buffer(8, 0)
		if !DllCall("user32\ClientToScreen", "Ptr", hwnd, "Ptr", origin.Ptr, "Int")
			return false

		left := NumGet(origin, 0, "Int")
		top := NumGet(origin, 4, "Int")

		return x >= left && x < left + width && y >= top && y < top + height
	}

	static HitTestSaysClient(hwnd, x, y) {
		now := A_TickCount

		if this.LastHitValid && hwnd = this.LastHitHwnd {
			dx := x - this.LastHitX
			dy := y - this.LastHitY
			movedEnough := dx * dx + dy * dy >= this.HitTestMovement * this.HitTestMovement
			intervalElapsed := now - this.LastHitTick >= this.HitTestInterval

			; Require both sufficient movement and the minimum interval. This caps
			; cross-window hit testing at about 20 calls per second per hovered HWND.
			if !movedEnough || !intervalElapsed
				return this.LastHitIsClient
		}

		; WM_NCHITTEST = 0x0084, HTCLIENT = 1.
		; SendMessageTimeout avoids allowing an unresponsive target application to
		; stall SmartInputVisuals. The cached result caps hit-test traffic while the
		; cheap client-rectangle test still runs every host tick.
		packedPoint := (x & 0xFFFF) | ((y & 0xFFFF) << 16)
		result := Buffer(A_PtrSize, 0)
		ok := DllCall(
			"user32\SendMessageTimeoutW",
			"Ptr", hwnd,
			"UInt", 0x0084,
			"UPtr", 0,
			"Ptr", packedPoint,
			"UInt", 0x0002,
			"UInt", this.HitTestTimeout,
			"Ptr", result.Ptr,
			"Ptr"
		)

		; If the target does not answer quickly, keep the already-established
		; client-rectangle result rather than delaying visualisation. Cache that
		; fallback too so a hung application is not queried every 20 ms.
		isClient := true
		if ok {
			hitResult := NumGet(result, 0, "UPtr")
			isClient := hitResult = 1
		}

		this.LastHitHwnd := hwnd
		this.LastHitX := x
		this.LastHitY := y
		this.LastHitIsClient := isClient
		this.LastHitTick := now
		this.LastHitValid := true

		return isClient
	}
}
