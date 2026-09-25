; SmartKeyPressOSD
; Lightweight host for same-process visualisation plugins.

#Requires AutoHotkey v2.0
#SingleInstance Force
#DllLoad "gdiplus.dll"

#Include Core\SharedTheme.ahk
#Include Core\GDIPlusHost.ahk
#Include Core\DpiContext.ahk
#Include Core\InputActivity.ahk
#Include Core\InputState.ahk
#Include Core\AppScope.ahk
#Include Core\ProfileManager.ahk
#Include Core\DisplayScope.ahk
#Include Core\TrayController.ahk
#Include Core\PluginManager.ahk

; Profiles register before plugins are initialised.
#Include Profiles\Default.ahk
#Include "*i Profiles\AppProfiles.ahk"

; Optional same-process plugins. Missing files are ignored at startup.
#Include "*i Plugins\KeyPressOSD.ahk"
#Include "*i Plugins\PointerHalo.ahk"
#Include "*i Plugins\ClickRipples.ahk"
#Include "*i Plugins\DragIndicator.ahk"

InstallKeybdHook()
InstallMouseHook()
CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")

APP_POLL_INTERVAL := 20
ApplicationPaused := false
AppState := SmartInputState()

SmartAppScope.Init()
SmartProfileManager.Init(PluginManager.GetRegisteredPluginNames())
SmartTrayController.Init(SetApplicationPaused)
ApplicationPaused := SmartTrayController.Paused
if !ApplicationPaused
	SmartInputActivity.Init()
GDIPlusHost.Init()
OnExit(ShutdownApplication)

pluginDpiContext := SmartDpiContext.EnterPerMonitor()
try {
	PluginManager.Init()
} finally {
	SmartDpiContext.Restore(pluginDpiContext)
}

if !ApplicationPaused
	SetTimer(AppTick, APP_POLL_INTERVAL)

AppTick() {
	global AppState

	previousDpiContext := SmartDpiContext.EnterPerMonitor()

	try {
		AppState.Update()

		; Resolve foreground/hover application context once for profiles and scope rules.
		SmartAppScope.Update(AppState)
		SmartProfileManager.Update(AppState)
		SmartDisplayScope.Update(AppState)
		SmartTrayController.Update(AppState)
		PluginManager.Process(AppState)
	} finally {
		SmartDpiContext.Restore(previousDpiContext)
	}
}

SetApplicationPaused(paused) {
	global ApplicationPaused, AppState, APP_POLL_INTERVAL

	paused := !!paused
	if paused = ApplicationPaused
		return

	ApplicationPaused := paused

	if paused {
		SetTimer(AppTick, 0)
		PluginManager.DeactivateAll("Paused", AppState)
		SmartInputActivity.Shutdown()
		return
	}

	SmartInputActivity.Init()

	; Resynchronise physical button state before polling resumes so pausing does
	; not create artificial mouse transitions when the host becomes active again.
	previousDpiContext := SmartDpiContext.EnterPerMonitor()
	try {
		AppState.Update()
		PluginManager.SynchroniseInputState(AppState)
	} finally {
		SmartDpiContext.Restore(previousDpiContext)
	}

	SetTimer(AppTick, APP_POLL_INTERVAL)
}

ShutdownApplication(*) {
	SetTimer(AppTick, 0)

	SmartTrayController.Shutdown()
	PluginManager.Shutdown()
	SmartInputActivity.Shutdown()
	GDIPlusHost.Shutdown()
}
