; SmartKeyPressOSD application-specific profiles
;
; Profiles are enabled globally in Core/ProfileManager.ahk, but each profile can
; be enabled or disabled independently with its own static Enabled setting.
;
; The examples below are disabled by default and can be copied or adapted.
; Executable names are matched case-insensitively. A profile may omit plugin
; names; omitted names fall back to the corresponding setting in Default.ahk.
;
; Keep application-specific configuration here rather than in the plugins so
; visual plugins remain reusable and profile selection stays centralised.

class ExamplePresentationProfile {
	static Enabled := false
	static Name := "Presentation example"
	static Applications := ["powerpnt.exe"]
	static Plugins := Map(
		"KeyPressOSD", true,
		"PointerHalo", true,
		"ClickRipples", true,
		"DragIndicator", true
	)
}

class ExcelProfile {
	static Enabled := false
	static Name := "Excel"
	static Applications := ["excel.exe"]
	static Plugins := Map(
		"KeyPressOSD", true,
		"PointerHalo", true,
		"ClickRipples", true,
		"DragIndicator", false
	)
}

SmartProfileManager.Register(ExamplePresentationProfile)
SmartProfileManager.Register(ExcelProfile)
