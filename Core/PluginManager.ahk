; SmartKeyPressOSD - same-process plugin manager
;
; Optional plugin configuration overrides:
;     static ScopeMode := "HoverOnly"       ; absent = inherit SmartAppScope.DefaultMode
;     static AllowWhileTyping := true       ; absent = pause while typing
;     static AllowOutsideClientArea := true ; absent = require client/content area
;
; Optional callbacks:
;     Init()
;     Activated(state)
;     Deactivated(reason, state)
;     WantsTick(state) -> true/false
;     Tick(state)
;     MouseDown(button, state)
;     MouseUp(button, state)
;     Shutdown()

class PluginManager {
	static Plugins := []
	static Initialised := false

	static PreviousLeftM := false
	static PreviousMiddleM := false
	static PreviousRightM := false

	static Register(plugin, name) {
		for record in this.Plugins {
			if StrLower(record.Name) = StrLower(name)
				throw Error("Duplicate SmartKeyPressOSD plugin name '" name "'.")
		}

		this.Plugins.Push({
			Plugin: plugin,
			Name: name,
			Healthy: true,
			Initialised: false,
			Active: false
		})
	}

	static GetRegisteredPluginNames() {
		names := []
		for record in this.Plugins
			names.Push(record.Name)
		return names
	}

	static Init() {
		if this.Initialised
			return

		this.Initialised := true

		for record in this.Plugins {
			if !record.Healthy
				continue

			record.Initialised := true

			try {
				if HasMethod(record.Plugin, "Init")
					record.Plugin.Init()
			} catch Error as err {
				this.DisableAfterError(record, "Init", err)
			}
		}
	}

	static Process(state) {
		if !this.Initialised
			return

		leftDown := state.LeftM && !this.PreviousLeftM
		leftUp := !state.LeftM && this.PreviousLeftM
		middleDown := state.MiddleM && !this.PreviousMiddleM
		middleUp := !state.MiddleM && this.PreviousMiddleM
		rightDown := state.RightM && !this.PreviousRightM
		rightUp := !state.RightM && this.PreviousRightM

		; Transitions are maintained centrally even while a plugin is blocked.
		this.PreviousLeftM := state.LeftM
		this.PreviousMiddleM := state.MiddleM
		this.PreviousRightM := state.RightM

		for record in this.Plugins {
			if !record.Initialised || !record.Healthy
				continue

			blockReason := this.GetBlockReason(record, state)
			if blockReason != "" {
				if record.Active
					this.Deactivate(record, blockReason, state)
				continue
			}

			if !record.Active {
				record.Active := true
				if HasMethod(record.Plugin, "Activated") {
					try record.Plugin.Activated(state)
					catch Error as err {
						this.DisableAfterError(record, "Activated", err)
						continue
					}
				}
			}

			if leftDown && !this.CallMouse(record, "MouseDown", "LeftM", state)
				continue
			if leftUp && !this.CallMouse(record, "MouseUp", "LeftM", state)
				continue
			if middleDown && !this.CallMouse(record, "MouseDown", "MiddleM", state)
				continue
			if middleUp && !this.CallMouse(record, "MouseUp", "MiddleM", state)
				continue
			if rightDown && !this.CallMouse(record, "MouseDown", "RightM", state)
				continue
			if rightUp && !this.CallMouse(record, "MouseUp", "RightM", state)
				continue

			if !HasMethod(record.Plugin, "Tick")
				continue

			try {
				if HasMethod(record.Plugin, "WantsTick") && !record.Plugin.WantsTick(state)
					continue

				record.Plugin.Tick(state)
			} catch Error as err {
				this.DisableAfterError(record, "Tick", err)
			}
		}
	}

	static DeactivateAll(reason, state) {
		if !this.Initialised
			return

		for record in this.Plugins {
			if !record.Initialised || !record.Healthy || !record.Active
				continue

			this.Deactivate(record, reason, state)
		}
	}

	static SynchroniseInputState(state) {
		this.PreviousLeftM := state.LeftM
		this.PreviousMiddleM := state.MiddleM
		this.PreviousRightM := state.RightM
	}

	static GetBlockReason(record, state) {
		; Never draw over the Windows taskbar/notification area. In particular,
		; tray-icon clicks must not produce OSD text, ripples, halos or drag visuals.
		if state.HoverIsTraySurface
			return "TraySurface"

		if !SmartProfileManager.IsPluginEnabled(record.Name) {
			if SmartProfileManager.HasRuntimePluginState(record.Name)
				return "RuntimeToggle"
			return "Profile"
		}

		try {
			if !SmartAppScope.IsPluginAllowed(record.Plugin, state)
				return "AppScope"
		} catch Error as err {
			this.DisableAfterError(record, "scope evaluation", err)
			return "Error"
		}

		try {
			if !SmartDisplayScope.IsPluginAllowed(record.Plugin, state)
				return "DisplayScope"
		} catch Error as err {
			this.DisableAfterError(record, "display scope evaluation", err)
			return "Error"
		}

		if state.TypingActive {
			allowWhileTyping := false
			try allowWhileTyping := !!record.Plugin.AllowWhileTyping
			catch
				allowWhileTyping := false

			if !allowWhileTyping
				return "Typing"
		}

		return ""
	}

	static Deactivate(record, reason, state) {
		record.Active := false

		try {
			if HasMethod(record.Plugin, "Deactivated")
				record.Plugin.Deactivated(reason, state)
		} catch Error as err {
			this.DisableAfterError(record, "Deactivated", err)
		}
	}

	static CallMouse(record, callbackName, button, state) {
		if !HasMethod(record.Plugin, callbackName)
			return true

		try {
			if callbackName = "MouseDown"
				record.Plugin.MouseDown(button, state)
			else
				record.Plugin.MouseUp(button, state)

			return true
		} catch Error as err {
			this.DisableAfterError(record, callbackName, err)
			return false
		}
	}

	static Shutdown() {
		if !this.Initialised
			return

		this.Initialised := false

		Loop this.Plugins.Length {
			index := this.Plugins.Length - A_Index + 1
			record := this.Plugins[index]

			if !record.Initialised
				continue

			try {
				if HasMethod(record.Plugin, "Shutdown")
					record.Plugin.Shutdown()
			} catch Error as err {
				OutputDebug(
					"SmartKeyPressOSD plugin '" record.Name
					"' Shutdown error: " err.Message
				)
			}

			record.Initialised := false
			record.Active := false
		}
	}

	static DisableAfterError(record, callbackName, err) {
		if !record.Healthy
			return

		record.Healthy := false
		record.Active := false

		OutputDebug(
			"SmartKeyPressOSD plugin '" record.Name
			"' disabled after " callbackName " error: " err.Message
		)

		if record.Initialised && HasMethod(record.Plugin, "Shutdown") {
			try record.Plugin.Shutdown()
			catch Error as shutdownErr
				OutputDebug(
					"SmartKeyPressOSD plugin '" record.Name
					"' cleanup error: " shutdownErr.Message
				)
		}

		record.Initialised := false
	}
}
