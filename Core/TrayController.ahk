; SmartInputVisuals - tray interaction and lightweight status feedback
; Provides dynamic per-profile plugin toggles and a global host enable toggle.

class SmartTrayController {
	static AppName := ""
	static EnabledItem := "Enabled"
	static ExitItem := ""
	static FeedbackDuration := 800
	static FeedbackTooltipId := 20
	static ActiveByDefault := true ; false starts SmartInputVisuals globally paused

	static Initialised := false
	static TargetProfile := 0
	static PluginInfo := []
	static PluginItems := Map()
	static PluginCallbacks := Map()
	static PauseCallback := 0
	static EnabledMenuCallback := 0
	static ExitCallback := 0
	static HideFeedbackCallback := 0
	static LastProfileKey := ""
	static LastPluginStates := Map()
	static Paused := false

	static Init(appName, pauseCallback) {
		if this.Initialised
			return

		appName := Trim(appName)
		if appName = ""
			throw Error("SmartInputVisuals application name must not be empty.")

		this.Initialised := true
		this.AppName := appName
		this.ExitItem := "Exit " this.AppName
		this.Paused := !this.ActiveByDefault
		this.PauseCallback := pauseCallback
		this.EnabledMenuCallback := ObjBindMethod(this, "ToggleEnabled")
		this.ExitCallback := ObjBindMethod(this, "ExitApplication")
		this.HideFeedbackCallback := ObjBindMethod(this, "HideFeedback")

		; Remove AutoHotkey's standard tray commands and expose only controls
		; whose behaviour is owned by SmartInputVisuals itself.
		A_TrayMenu.Delete()
		this.BuildPluginMenu()
		if this.PluginItems.Count > 0
			A_TrayMenu.Add()
		A_TrayMenu.Add(this.EnabledItem, this.EnabledMenuCallback)
		A_TrayMenu.Add()
		A_TrayMenu.Add(this.ExitItem, this.ExitCallback)
		A_IconTip := this.AppName

		this.Refresh(true)
		this.RefreshEnabled()
	}

	static BuildPluginMenu() {
		this.PluginInfo := PluginManager.GetRegisteredPluginInfo()
		this.PluginItems.Clear()
		this.PluginCallbacks.Clear()
		this.LastPluginStates.Clear()

		for info in this.PluginInfo {
			this.ValidateMenuItemName(info.DisplayName)
			callback := ObjBindMethod(this, "TogglePlugin", info.Name)
			this.PluginItems[info.Name] := info.DisplayName
			this.PluginCallbacks[info.Name] := callback
			A_TrayMenu.Add(info.DisplayName, callback)
		}
	}

	static ValidateMenuItemName(itemName) {
		if StrLower(itemName) = StrLower(this.EnabledItem)
			throw Error("Plugin display name '" itemName "' conflicts with the tray Enabled item.")
		if StrLower(itemName) = StrLower(this.ExitItem)
			throw Error("Plugin display name '" itemName "' conflicts with the tray Exit item.")
	}

	static Update(state) {
		if !this.Initialised
			return

		; Plugin toggles target the foreground window's profile. Preserve the
		; previously captured target only while Windows temporarily activates the
		; taskbar/tray, a popup menu, or a SmartInputVisuals-owned helper window.
		; Desktop and File Explorer windows resolve normally, including optional
		; process + window-class profile mappings.
		if state.ActiveProcess != "" && !this.ShouldPreserveTarget(
			state.ActiveHwnd,
			state.ActiveClass
		) {
			this.TargetProfile := SmartProfileManager.GetProfileForWindow(
				state.ActiveProcess,
				state.ActiveClass
			)
		} else if !this.TargetProfile && SmartProfileManager.ActiveProfile {
			this.TargetProfile := SmartProfileManager.ActiveProfile
		}

		this.Refresh()
	}

	static TogglePlugin(pluginName, *) {
		if this.Paused || !PluginManager.IsPluginHealthy(pluginName)
			return

		enabled := false
		if !SmartProfileManager.TogglePluginForProfile(
			this.TargetProfile,
			pluginName,
			&enabled
		)
			return

		this.Refresh(true)
		this.ShowFeedback(pluginName, enabled)
	}

	static ToggleEnabled(*) {
		if !this.PauseCallback
			return

		paused := !this.Paused

		try this.PauseCallback.Call(paused)
		catch Error as err {
			OutputDebug(this.AppName " pause toggle error: " err.Message)
			return
		}

		this.Paused := paused
		if paused
			this.HideFeedback()

		this.RefreshEnabled()
		this.Refresh(true)
	}

	static RefreshEnabled() {
		if this.Paused {
			A_TrayMenu.Uncheck(this.EnabledItem)
			A_IconTip := this.AppName " (Paused)"
		} else {
			A_TrayMenu.Check(this.EnabledItem)
			A_IconTip := this.AppName
		}
	}

	static Refresh(force := false) {
		profileKey := SmartProfileManager.GetProfileKey(this.TargetProfile)
		profileChanged := profileKey != this.LastProfileKey

		for info in this.PluginInfo {
			itemName := this.PluginItems[info.Name]
			healthy := PluginManager.IsPluginHealthy(info.Name)
			enabled := false

			if this.TargetProfile && healthy {
				enabled := SmartProfileManager.IsPluginEnabledForProfile(
					this.TargetProfile,
					info.Name
				)
			}

			menuEnabled := !!(this.TargetProfile && healthy && !this.Paused)
			stateKey := (enabled ? "1" : "0") ":" (menuEnabled ? "1" : "0")

			if !force
				&& !profileChanged
				&& this.LastPluginStates.Has(info.Name)
				&& this.LastPluginStates[info.Name] = stateKey
				continue

			if enabled
				A_TrayMenu.Check(itemName)
			else
				A_TrayMenu.Uncheck(itemName)

			if menuEnabled
				A_TrayMenu.Enable(itemName)
			else
				A_TrayMenu.Disable(itemName)

			this.LastPluginStates[info.Name] := stateKey
		}

		this.LastProfileKey := profileKey
	}

	static ShowFeedback(pluginName, enabled) {
		itemName := pluginName
		if this.PluginItems.Has(pluginName)
			itemName := this.PluginItems[pluginName]
		x := 0
		y := 0
		MouseGetPos(&x, &y)
		ToolTip(
			itemName ": " (enabled ? "ON" : "OFF"),
			x + 16,
			y + 20,
			this.FeedbackTooltipId
		)
		SetTimer(this.HideFeedbackCallback, -this.FeedbackDuration)
	}

	static HideFeedback(*) {
		ToolTip("", 0, 0, this.FeedbackTooltipId)
	}

	static ShouldPreserveTarget(hwnd, className := "") {
		if !hwnd
			return false

		if SmartAppScope.IsTraySurface(hwnd, className)
			return true

		if className = ""
			className := SmartAppScope.GetWindowClass(hwnd)
		if className = "#32768"
			return true

		; The AutoHotkey tray menu can transiently activate a window owned by the
		; script itself. Do not let that replace the profile captured beforehand.
		try {
			if WinGetPID("ahk_id " hwnd) = ProcessExist()
				return true
		}

		return false
	}

	static ExitApplication(*) {
		ExitApp()
	}

	static Shutdown() {
		if !this.Initialised
			return

		if this.HideFeedbackCallback
			SetTimer(this.HideFeedbackCallback, 0)
		this.HideFeedback()
		this.PluginInfo := []
		this.PluginCallbacks.Clear()
		this.PauseCallback := 0
		this.Initialised := false
	}
}
