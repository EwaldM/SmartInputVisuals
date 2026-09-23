; SmartKeyPressOSD - same-process plugin manager
;
; Optional plugin callbacks:
;     Init()
;     WantsTick(state) -> true/false
;     Tick(state)
;     MouseDown(button, state)
;     MouseUp(button, state)
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
			Initialised: false
		})
	}

	static Init() {
		if this.Initialised
			return

		this.Initialised := true

		for record in this.Plugins {
			if !record.Enabled
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

		; Transition events are computed once centrally, not by each plugin.
		if state.LeftM != this.PreviousLeftM {
			if state.LeftM
				this.DispatchMouseDown("LeftM", state)
			else
				this.DispatchMouseUp("LeftM", state)
			this.PreviousLeftM := state.LeftM
		}

		if state.MiddleM != this.PreviousMiddleM {
			if state.MiddleM
				this.DispatchMouseDown("MiddleM", state)
			else
				this.DispatchMouseUp("MiddleM", state)
			this.PreviousMiddleM := state.MiddleM
		}

		if state.RightM != this.PreviousRightM {
			if state.RightM
				this.DispatchMouseDown("RightM", state)
			else
				this.DispatchMouseUp("RightM", state)
			this.PreviousRightM := state.RightM
		}

		this.DispatchTick(state)
	}

	static DispatchTick(state) {
		for record in this.Plugins {
			if !record.Enabled || !record.Initialised
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

	static DispatchMouseDown(button, state) {
		for record in this.Plugins {
			if !record.Enabled || !record.Initialised
				continue
			if !HasMethod(record.Plugin, "MouseDown")
				continue

			try record.Plugin.MouseDown(button, state)
			catch Error as err
				this.Disable(record, "MouseDown", err)
		}
	}

	static DispatchMouseUp(button, state) {
		for record in this.Plugins {
			if !record.Enabled || !record.Initialised
				continue
			if !HasMethod(record.Plugin, "MouseUp")
				continue

			try record.Plugin.MouseUp(button, state)
			catch Error as err
				this.Disable(record, "MouseUp", err)
		}
	}

	static Shutdown() {
		if !this.Initialised
			return

		this.Initialised := false

		; Release plugins in reverse registration order.
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
		}
	}

	static Disable(record, callbackName, err) {
		if !record.Enabled
			return

		record.Enabled := false

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
