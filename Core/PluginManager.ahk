; SmartKeyPressOSD - same-process plugin manager
;
; Plugin configuration:
;     static Enabled := true
;     static ScopeMode := ""  ; empty = inherit SmartAppScope.Mode
;
; Optional plugin callbacks:
;     Init()
;     WantsTick(state) -> true/false
;     Tick(state)
;     MouseDown(button, state)
;     MouseUp(button, state)
;     ScopeLost()
;     Shutdown()
;
; Plugins register at startup with:
;     PluginManager.Register(MyPlugin, "MyPlugin")

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
			ScopeAllowed: false
		})
	}

	static Init() {
		if this.Initialised
			return

		this.Initialised := true

		for record in this.Plugins {
			; The manager does not call a plugin at all when its own Enabled flag is
			; false. This check happens before Init().
			if !this.IsPluginEnabled(record)
				continue

			; Mark it initialised before Init() so Disable() can call Shutdown()
			; if the plugin fails after partially allocating resources.
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

		; Transition state is maintained centrally even while every plugin is
		; disabled or out of scope. Re-entering scope therefore does not replay a
		; click which happened elsewhere.
		this.PreviousLeftM := state.LeftM
		this.PreviousMiddleM := state.MiddleM
		this.PreviousRightM := state.RightM

		for record in this.Plugins {
			if !record.Initialised || !this.IsPluginEnabled(record)
				continue

			try {
				scopeAllowed := SmartAppScope.IsPluginAllowed(record.Plugin, state)
			} catch Error as err {
				this.Disable(record, "scope evaluation", err)
				continue
			}

			if !scopeAllowed {
				if record.ScopeAllowed {
					record.ScopeAllowed := false
					if HasMethod(record.Plugin, "ScopeLost") {
						try record.Plugin.ScopeLost()
						catch Error as err {
							this.Disable(record, "ScopeLost", err)
						}
					}
				}
				continue
			}

			record.ScopeAllowed := true

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

			if !record.Enabled
				continue
			if !HasMethod(record.Plugin, "Tick")
				continue

			try {
				if HasMethod(record.Plugin, "WantsTick") {
					if !record.Plugin.WantsTick(state)
						continue
				}

				record.Plugin.Tick(state)
			} catch Error as err {
				this.Disable(record, "Tick", err)
			}
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

		; Included plugins expose a static Enabled property. A third-party plugin
		; without that property is treated as enabled for backwards compatibility.
		try {
			return !!record.Plugin.Enabled
		} catch {
			return true
		}
	}

	static Shutdown() {
		if !this.Initialised
			return

		this.Initialised := false

		; Release plugins in reverse registration order. An already-initialised
		; plugin is shut down even if its Enabled property was changed at runtime,
		; because allocated resources still need to be released safely.
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
			record.ScopeAllowed := false
		}
	}

	static Disable(record, callbackName, err) {
		if !record.Enabled
			return

		record.Enabled := false
		record.ScopeAllowed := false

		OutputDebug(
			"SmartKeyPressOSD plugin '" record.Name
			"' disabled after " callbackName " error: " err.Message
		)

		; Release any resources already allocated by the failing plugin.
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
