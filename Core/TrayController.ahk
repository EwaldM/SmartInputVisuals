; SmartKeyPressOSD - tray interaction and lightweight status feedback
; DragIndicator can be toggled per application profile for the current session.

class SmartTrayController {
	static DragIndicatorItem := "DragIndicator"
	static ExitItem := "Exit SmartKeyPressOSD"
	static FeedbackDuration := 800
	static FeedbackTooltipId := 20

	static Initialised := false
	static TargetProfile := 0
	static ToggleCallback := 0
	static ExitCallback := 0
	static HideFeedbackCallback := 0
	static LastProfileKey := ""
	static LastAvailable := -1
	static LastRuntimeEnabled := -1

	static Init() {
		if this.Initialised
			return

		this.Initialised := true
		this.ToggleCallback := ObjBindMethod(this, "ToggleDragIndicator")
		this.ExitCallback := ObjBindMethod(this, "ExitApplication")
		this.HideFeedbackCallback := ObjBindMethod(this, "HideFeedback")

		; Remove AutoHotkey's standard tray commands such as "Suspend Hotkeys".
		; SmartKeyPressOSD has no tray hotkey toggle, so leaving those entries in
		; place is misleading next to the profile-aware DragIndicator control.
		A_TrayMenu.Delete()
		A_TrayMenu.Add(this.DragIndicatorItem, this.ToggleCallback)
		A_TrayMenu.Add()
		A_TrayMenu.Add(this.ExitItem, this.ExitCallback)
		A_IconTip := "SmartKeyPressOSD"

		this.Refresh(true)
	}

	static Update(state) {
		if !this.Initialised
			return

		; The tray toggle targets the foreground application's profile. Pointer
		; hover is deliberately not used here: moving to the notification area is
		; itself a hover-context change and must not switch the toggle to Default.
		; Keep the last non-shell foreground profile while the tray/menu has focus.
		if SmartProfileManager.Enabled {
			if state.ActiveProcess != "" && !this.IsShellSurface(state.ActiveHwnd)
				this.TargetProfile := SmartProfileManager.GetProfileForProcess(state.ActiveProcess)
			else if !this.TargetProfile && SmartProfileManager.ActiveProfile
				this.TargetProfile := SmartProfileManager.ActiveProfile
		} else {
			this.TargetProfile := 0
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

	static Refresh(force := false) {
		profileKey := SmartProfileManager.GetProfileKey(this.TargetProfile)
		available := false
		runtimeEnabled := false

		if SmartProfileManager.Enabled && this.TargetProfile {
			available := SmartProfileManager.IsPluginAvailableForProfile(
				this.TargetProfile,
				"DragIndicator"
			)
			if available {
				runtimeEnabled := SmartProfileManager.IsPluginRuntimeEnabledForProfile(
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
			A_TrayMenu.Enable(this.DragIndicatorItem)
			if runtimeEnabled
				A_TrayMenu.Check(this.DragIndicatorItem)
			else
				A_TrayMenu.Uncheck(this.DragIndicatorItem)
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

	static IsShellSurface(hwnd) {
		if !hwnd
			return false

		processName := ""
		className := ""
		try processName := WinGetProcessName("ahk_id " hwnd)
		catch
			return false
		try className := WinGetClass("ahk_id " hwnd)
		catch
			className := ""

		if StrLower(processName) = "explorer.exe"
			return true

		switch className {
			case "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "NotifyIconOverflowWindow", "#32768":
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
		this.Initialised := false
	}
}
