; SmartKeyPressOSD - same-process plugin manager
;
; Plugin configuration:
;     static Enabled := true
;     static ScopeMode := ""          ; empty = inherit SmartAppScope.Mode
;     static PauseWhileTyping := true
;     static RequireClientArea := true ; pointer-driven visualisations
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
		this.Plugins.Push({
			Plugin: plugin,
			Name: name,
			Enabled: true,
			Initialised: false,
			Active: false
		})
	}

	static Init() {
		if this.Initialised
			return

		this.Initialised := true

		for record in this.Plugins {
			; A plugin whose own Enabled property is false receives no calls at all,
			; including Init(). Configuration changes require a reload/restart.
			if !this.IsPluginEnabled(record)
				continue

			record.Initialised := true

			try {
				if HasMethod(record.Plugin, "Init")
					record.Plugin.Init()
			} catch Error as err {
				this.Disable(record, "Init", err)
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
			if !record.Initialised || !this.IsPluginEnabled(record)
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
						this.Disable(record, "Activated", err)
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
				this.Disable(record, "Tick", err)
			}
		}
	}

	static GetBlockReason(record, state) {
		if !SmartProfileManager.IsPluginAvailable(record.Name)
			return "Profile"
		if !SmartProfileManager.IsPluginRuntimeEnabled(record.Name)
			return "RuntimeToggle"

		try {
			if !SmartAppScope.IsPluginAllowed(record.Plugin, state)
				return "AppScope"
		} catch Error as err {
			this.Disable(record, "scope evaluation", err)
			return "Error"
		}

		try {
			if !SmartDisplayScope.IsPluginAllowed(record.Plugin, state)
				return "DisplayScope"
		} catch Error as err {
			this.Disable(record, "display scope evaluation", err)
			return "Error"
		}

		if SmartInputActivity.PauseWhileTyping && state.TypingActive {
			pausePlugin := false
			try pausePlugin := !!record.Plugin.PauseWhileTyping
			catch
				pausePlugin := false

			if pausePlugin
				return "Typing"
		}

		return ""
	}

	static Deactivate(record, reason, state) {
		record.Active := false

		try {
			if HasMethod(record.Plugin, "Deactivated")
				record.Plugin.Deactivated(reason, state)
			else if reason = "AppScope" && HasMethod(record.Plugin, "ScopeLost")
				record.Plugin.ScopeLost()
		} catch Error as err {
			this.Disable(record, "Deactivated", err)
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
			this.Disable(record, callbackName, err)
			return false
		}
	}

	static IsPluginEnabled(record) {
		if !record.Enabled
			return false

		try return !!record.Plugin.Enabled
		catch
			return true
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

	static Disable(record, callbackName, err) {
		if !record.Enabled
			return

		record.Enabled := false
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
