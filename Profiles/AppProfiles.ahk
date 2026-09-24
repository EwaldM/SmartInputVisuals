; SmartKeyPressOSD application-specific profiles
;
; Profiles are disabled globally by default. Enable them in
; Core/ProfileManager.ahk by setting SmartProfileManager.Enabled := true.
;
; This disabled example can be copied and adapted. Executable names are matched
; case-insensitively. A profile may omit plugin names; omitted names fall back to
; the Default profile.

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

SmartProfileManager.Register(ExamplePresentationProfile)
