; SmartKeyPressOSD application-specific profiles
;
; Each application profile can be disabled independently with static Enabled := false.
; If the setting is omitted or commented out, the profile is enabled. Disabled profiles
; remain useful as ready-to-edit examples without affecting runtime behaviour.
;
; Applications entries can be simple executable-name strings, or Maps with
; Process and Class keys when only a specific window class should match. Process
; names and window classes are matched case-insensitively. A class-specific match
; takes precedence over a process-only match for the same executable.
;
; Plugin names must match an entry in Default.ahk. All registered plugins are available
; to every profile. The true/false values in Plugins define each profile's default runtime
; state. A profile may omit plugin names; omitted settings inherit the Default profile value.
;
; Keep application-specific configuration here rather than in the plugins so
; visual plugins remain reusable and profile selection stays centralised.
;
; One profile can list several application matchers in Applications when multiple
; applications should share the same visualisation setup. The Excel/Word example
; below demonstrates process-only matching. Window-class matching is useful when
; different windows share one process, such as the Desktop and File Explorer.
;
; The Desktop example below is enabled by leaving its Enabled setting commented out;
; uncomment the line to disable it. All Desktop plugin defaults are off. The PowerPoint
; and Excel/Word examples are disabled by default.
; Copy, rename or adapt these examples as required.

class DesktopProfile {
	; static Enabled := false
	static Name := "Desktop"
	static Applications := [
		Map("Process", "explorer.exe", "Class", "Progman"),
		Map("Process", "explorer.exe", "Class", "WorkerW")
	]
	static Plugins := Map(
		"KeyPressOSD", false,
		"PointerHalo", false,
		"ClickRipples", false,
		"DragIndicator", false
	)
}

class PowerPointProfile {
	static Enabled := false
	static Name := "PowerPoint"
	static Applications := ["powerpnt.exe"]
	static Plugins := Map(
		"KeyPressOSD", true,
		"PointerHalo", true,
		"ClickRipples", true,
		"DragIndicator", true
	)
}

class ExcelAndWordProfile {
	static Enabled := false
	static Name := "Excel and Word"
	static Applications := ["excel.exe", "winword.exe"]
	static Plugins := Map(
		"KeyPressOSD", true,
		"PointerHalo", true,
		"ClickRipples", true,
		"DragIndicator", false
	)
}

SmartProfileManager.Register(DesktopProfile)
SmartProfileManager.Register(PowerPointProfile)
SmartProfileManager.Register(ExcelAndWordProfile)
