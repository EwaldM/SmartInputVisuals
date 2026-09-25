; SmartInputVisuals - tray interaction and lightweight status feedback
; Provides a global host enable toggle and a per-profile DragIndicator toggle.

class SmartTrayController {
	static DragIndicatorItem := "DragIndicator"
	static EnabledItem := "Enabled"
	static ExitItem := "Exit SmartInputVisuals"
	static FeedbackDuration := 800
	static FeedbackTooltipId := 20
	static ActiveByDefault := true ; false starts SmartInputVisuals globally paused

	static Initialised := false
	static TargetProfile := 0
	static ToggleCallback := 0
	static PauseCallback := 0
	static EnabledMenuCallback := 0
	static ExitCallback := 0
	static HideFeedbackCallback := 0
	static LastProfileKey := ""
	static LastAvailable := -1
	static LastRuntimeEnabled := -1
	static Paused := false

	static Init(pauseCallback) {
		if this.Initialised
			return

		this.Initialised := true
		this.Paused := !this.ActiveByDefault
		this.PauseCallback := pauseCallback
		this.ToggleCallback := ObjBindMethod(this, "ToggleDragIndicator")
		this.EnabledMenuCallback := ObjBindMethod(this, "ToggleEnabled")
		this.ExitCallback := ObjBindMethod(this, "ExitApplication")
		this.HideFeedbackCallback := ObjBindMethod(this, "HideFeedback")

		; Remove AutoHotkey's standard tray commands and expose only controls
		; whose behaviour is owned by SmartInputVisuals itself.
		A_TrayMenu.Delete()
		A_TrayMenu.Add(this.DragIndicatorItem, this.ToggleCallback)
		A_TrayMenu.Add()
		A_TrayMenu.Add(this.EnabledItem, this.EnabledMenuCallback)
		A_TrayMenu.Add()
		A_TrayMenu.Add(this.ExitItem, this.ExitCallback)
		A_IconTip := "SmartInputVisuals"

		this.Refresh(true)
		this.RefreshEnabled()
	}

	static Update(state) {
		if !this.Initialised
			return

		; The tray toggle targets the foreground window's profile. Preserve the
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

	static ToggleDragIndicator(*) {
		enabled := false
		if !SmartProfileManager.TogglePluginForProfile(
			this.TargetProfile,
			"DragIndicator",
			&enabled
		)
			return

		this.Refresh(true)
		this.ShowFeedback(enabled)
	}

	static ToggleEnabled(*) {
		if !this.PauseCallback
			return

		paused := !this.Paused

		try this.PauseCallback.Call(paused)
		catch Error as err {
			OutputDebug("SmartInputVisuals pause toggle error: " err.Message)
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
			A_IconTip := "SmartInputVisuals (Paused)"
		} else {
			A_TrayMenu.Check(this.EnabledItem)
			A_IconTip := "SmartInputVisuals"
		}
	}

	static Refresh(force := false) {
		profileKey := SmartProfileManager.GetProfileKey(this.TargetProfile)
		available := false
		runtimeEnabled := false

		if this.TargetProfile {
			available := SmartProfileManager.IsPluginRegistered("DragIndicator")
			if available {
				runtimeEnabled := SmartProfileManager.IsPluginEnabledForProfile(
					this.TargetProfile,
					"DragIndicator"
				)
			}
		}

		if !force
			&& profileKey = this.LastProfileKey
			&& available = this.LastAvailable
			&& runtimeEnabled = this.LastRuntimeEnabled
			return

		if available {
			if runtimeEnabled
				A_TrayMenu.Check(this.DragIndicatorItem)
			else
				A_TrayMenu.Uncheck(this.DragIndicatorItem)

			if this.Paused
				A_TrayMenu.Disable(this.DragIndicatorItem)
			else
				A_TrayMenu.Enable(this.DragIndicatorItem)
		} else {
			A_TrayMenu.Uncheck(this.DragIndicatorItem)
			A_TrayMenu.Disable(this.DragIndicatorItem)
		}

		this.LastProfileKey := profileKey
		this.LastAvailable := available
		this.LastRuntimeEnabled := runtimeEnabled
	}

	static ShowFeedback(enabled) {
		x := 0
		y := 0
		MouseGetPos(&x, &y)
		ToolTip(
			"DragIndicator: " (enabled ? "ON" : "OFF"),
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
		this.PauseCallback := 0
		this.Initialised := false
	}
}
