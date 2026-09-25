; SmartKeyPressOSD - application focus/hover scope
; Applies plugin focus/hover rules to the application selected by ProfileManager.

class SmartAppScope {
	static DefaultMode := "FocusOrHover"

	static LastActiveHwnd := 0
	static LastActiveProcess := ""
	static LastActiveClass := ""
	static LastHoverHwnd := 0
	static LastHoverProcess := ""
	static LastHoverClass := ""
	static OwnProcessId := 0

	static Init() {
		this.OwnProcessId := ProcessExist()
		this.MatchMode(this.DefaultMode, false, false)
	}

	static Update(state) {
		activeHwnd := WinExist("A")
		hoverHwnd := this.ResolveHoverWindow(state.HoverHwnd, state.X, state.Y)

		if activeHwnd != this.LastActiveHwnd {
			this.LastActiveHwnd := activeHwnd
			this.LastActiveProcess := this.GetProcessName(activeHwnd)
			this.LastActiveClass := this.GetWindowClass(activeHwnd)
		}

		if hoverHwnd != this.LastHoverHwnd {
			this.LastHoverHwnd := hoverHwnd
			this.LastHoverProcess := this.GetProcessName(hoverHwnd)
			this.LastHoverClass := this.GetWindowClass(hoverHwnd)
		}

		state.ActiveHwnd := activeHwnd
		state.HoverHwnd := hoverHwnd
		state.ActiveProcess := this.LastActiveProcess
		state.HoverProcess := this.LastHoverProcess
		state.ActiveClass := this.LastActiveClass
		state.HoverClass := this.LastHoverClass
		state.HoverIsTraySurface := this.IsTraySurface(hoverHwnd, this.LastHoverClass)
	}

	static IsPluginAllowed(plugin, state) {
		mode := this.DefaultMode
		pluginMode := ""

		try pluginMode := plugin.ScopeMode
		catch
			pluginMode := ""

		if pluginMode != ""
			mode := pluginMode

		if mode = "Always"
			return true

		if state.ProfileProcess = ""
			return false

		focusMatches := SmartProfileManager.ContextMatchesSelectedApplication(
			state.ActiveProcess,
			state.ActiveClass,
			state
		)
		hoverMatches := SmartProfileManager.ContextMatchesSelectedApplication(
			state.HoverProcess,
			state.HoverClass,
			state
		)
		return this.MatchMode(mode, focusMatches, hoverMatches)
	}

	static MatchMode(mode, focusMatches, hoverMatches) {
		switch mode {
			case "Always":
				return true
			case "FocusOnly":
				return focusMatches
			case "HoverOnly":
				return hoverMatches
			case "FocusOrHover":
				return focusMatches || hoverMatches
			case "FocusAndHover":
				return focusMatches && hoverMatches
			default:
				throw Error(
					"Unknown SmartAppScope mode '" mode "'. "
					"Use Always, FocusOnly, HoverOnly, FocusOrHover, or FocusAndHover."
				)
		}
	}

	static IsTraySurface(hwnd, className := "") {
		if !hwnd
			return false

		if className = ""
			className := this.GetWindowClass(hwnd)

		switch className {
			case "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "NotifyIconOverflowWindow", "TopLevelWindowForOverflowXamlIsland":
				return true
		}

		return false
	}

	static GetProcessName(hwnd) {
		if !hwnd
			return ""

		try return WinGetProcessName("ahk_id " hwnd)
		catch
			return ""
	}

	static GetWindowClass(hwnd) {
		if !hwnd
			return ""

		try return WinGetClass("ahk_id " hwnd)
		catch
			return ""
	}

	static ResolveHoverWindow(hwnd, x, y) {
		if !hwnd
			return 0

		rootHwnd := DllCall(
			"user32\GetAncestor",
			"Ptr", hwnd,
			"UInt", 2,
			"Ptr"
		)

		if !rootHwnd
			rootHwnd := hwnd

		if this.GetWindowProcessId(rootHwnd) != this.OwnProcessId
			return rootHwnd

		; SmartKeyPressOSD's layered windows are click-through and topmost. If one
		; is returned, walk down the Z-order to the first visible external window
		; which still contains the current pointer position.
		candidate := rootHwnd
		Loop 100 {
			candidate := DllCall(
				"user32\GetWindow",
				"Ptr", candidate,
				"UInt", 2,
				"Ptr"
			)

			if !candidate
				break
			if !DllCall("user32\IsWindowVisible", "Ptr", candidate, "Int")
				continue
			if this.GetWindowProcessId(candidate) = this.OwnProcessId
				continue
			if !this.WindowContainsPoint(candidate, x, y)
				continue

			return candidate
		}

		return 0
	}

	static GetWindowProcessId(hwnd) {
		if !hwnd
			return 0

		pid := 0
		DllCall(
			"user32\GetWindowThreadProcessId",
			"Ptr", hwnd,
			"UInt*", &pid,
			"UInt"
		)
		return pid
	}

	static WindowContainsPoint(hwnd, x, y) {
		rect := Buffer(16, 0)
		if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect.Ptr, "Int")
			return false

		left := NumGet(rect, 0, "Int")
		top := NumGet(rect, 4, "Int")
		right := NumGet(rect, 8, "Int")
		bottom := NumGet(rect, 12, "Int")

		return x >= left && x < right && y >= top && y < bottom
	}
}
