; SmartKeyPressOSD
; Lightweight host for same-process visualisation plugins.

#Requires AutoHotkey v2.0
#SingleInstance Force
#DllLoad "gdiplus.dll"

#Include Core\SharedTheme.ahk
#Include Core\GDIPlusHost.ahk
#Include Core\InputState.ahk
#Include Core\PluginManager.ahk

; Optional same-process plugins. Missing files are ignored at startup.
#Include "*i Plugins\KeyPressOSD.ahk"
#Include "*i Plugins\PointerHalo.ahk"
#Include "*i Plugins\ClickRipples.ahk"

InstallKeybdHook()
InstallMouseHook()
CoordMode("Mouse", "Screen")

; One shared timer drives the entire application.
APP_POLL_INTERVAL := 20
AppState := SmartInputState()

GDIPlusHost.Init()
OnExit(ShutdownApplication)

PluginManager.Init()
SetTimer(AppTick, APP_POLL_INTERVAL)

AppTick() {
	global AppState

	; Input is sampled exactly once per application tick.
	AppState.Update()

	; The same persistent state object is passed to every plugin.
	PluginManager.Process(AppState)
}

ShutdownApplication(*) {
	; Stop new work before resources are released.
	SetTimer(AppTick, 0)

	; Plugins release their GDI/GDI+ resources first. The host owns the single
	; matching GDI+ shutdown call and performs it last.
	PluginManager.Shutdown()
	GDIPlusHost.Shutdown()
}
