; SmartKeyPressOSD
; Lightweight host for same-process visualisation plugins.

#Requires AutoHotkey v2.0
#SingleInstance Force
#DllLoad "gdiplus.dll"

#Include Core\SharedTheme.ahk
#Include Core\GDIPlusHost.ahk
#Include Core\InputActivity.ahk
#Include Core\InputState.ahk
#Include Core\AppScope.ahk
#Include Core\ProfileManager.ahk
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
AppState := SmartInputState()

SmartInputActivity.Init()
SmartAppScope.Init()
SmartProfileManager.Init()
SmartTrayController.Init()
GDIPlusHost.Init()
OnExit(ShutdownApplication)

PluginManager.Init()
SetTimer(AppTick, APP_POLL_INTERVAL)

AppTick() {
	global AppState

	AppState.Update()

	; Profiles need foreground/hover process context even when AppScope itself is
	; disabled, so AppScope resolves process names whenever profiles are enabled.
	SmartAppScope.Update(AppState, SmartProfileManager.Enabled)
	SmartProfileManager.Update(AppState)
	SmartTrayController.Update(AppState)
	PluginManager.Process(AppState)
}

ShutdownApplication(*) {
	SetTimer(AppTick, 0)

	SmartTrayController.Shutdown()
	PluginManager.Shutdown()
	SmartInputActivity.Shutdown()
	GDIPlusHost.Shutdown()
}
