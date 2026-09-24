; SmartKeyPressOSD - application scope filtering
; Restricts enabled plugins to configured foreground and/or hovered applications.

class SmartAppScope {
	; Disabled by default to preserve the original all-applications behaviour.
	static Enabled := false
	static Mode := "FocusOrHover"

	; Add executable names here, for example:
	; static Applications := ["devenv.exe", "msedge.exe"]
	static Applications := []

	static AllowedProcesses := Map()

	static LastActiveHwnd := 0
	static LastActiveProcess := ""
	static LastHoverHwnd := 0
	static LastHoverProcess := ""
	static OwnProcessId := 0

	static Init() {
		this.OwnProcessId := ProcessExist()
		this.AllowedProcesses.Clear()

		for processName in this.Applications {
			normalized := StrLower(Trim(processName))
			if normalized != ""
				this.AllowedProcesses[normalized] := true
		}

		this.MatchMode(this.Mode, false, false)
	}

	static Update(state, needProcessContext := false) {
		if !this.Enabled && !needProcessContext {
			state.ActiveHwnd := 0
			state.ActiveProcess := ""
			state.HoverProcess := ""
			state.FocusAllowed := true
			state.HoverAllowed := true
			state.ScopeAllowed := true
			return
		}

		activeHwnd := WinExist("A")
		hoverHwnd := this.ResolveHoverWindow(state.HoverHwnd, state.X, state.Y)

		if activeHwnd != this.LastActiveHwnd {
			this.LastActiveHwnd := activeHwnd
			this.LastActiveProcess := this.GetProcessName(activeHwnd)
		}

		if hoverHwnd != this.LastHoverHwnd {
			this.LastHoverHwnd := hoverHwnd
			this.LastHoverProcess := this.GetProcessName(hoverHwnd)
		}

		state.ActiveHwnd := activeHwnd
		state.HoverHwnd := hoverHwnd
		state.ActiveProcess := this.LastActiveProcess
		state.HoverProcess := this.LastHoverProcess

		if this.Enabled {
			state.FocusAllowed := this.IsProcessAllowed(state.ActiveProcess)
			state.HoverAllowed := this.IsProcessAllowed(state.HoverProcess)
			state.ScopeAllowed := this.MatchMode(
				this.Mode,
				state.FocusAllowed,
				state.HoverAllowed
			)
		} else {
			state.FocusAllowed := true
			state.HoverAllowed := true
			state.ScopeAllowed := true
		}
	}

	static IsPluginAllowed(plugin, state) {
		if !this.Enabled
			return true

		mode := this.Mode
		pluginMode := ""

		try pluginMode := plugin.ScopeMode
		catch
			pluginMode := ""

		if pluginMode != ""
			mode := pluginMode

		return this.MatchMode(mode, state.FocusAllowed, state.HoverAllowed)
	}

	static MatchMode(mode, focusAllowed, hoverAllowed) {
		switch mode {
			case "Always":
				return true
			case "FocusOnly":
				return focusAllowed
			case "HoverOnly":
				return hoverAllowed
			case "FocusOrHover":
				return focusAllowed || hoverAllowed
			case "FocusAndHover":
				return focusAllowed && hoverAllowed
			default:
				throw Error(
					"Unknown SmartAppScope mode '" mode "'. "
					"Use Always, FocusOnly, HoverOnly, FocusOrHover, or FocusAndHover."
				)
		}
	}

	static IsProcessAllowed(processName) {
		if processName = ""
			return false

		return this.AllowedProcesses.Has(StrLower(processName))
	}

	static GetProcessName(hwnd) {
		if !hwnd
			return ""

		try return WinGetProcessName("ahk_id " hwnd)
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
