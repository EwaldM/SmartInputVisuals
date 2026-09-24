; SmartKeyPressOSD default profile
; Used when profiles are enabled but no application-specific profile matches.

class SmartDefaultProfile {
	static Name := "Default"
	static Plugins := Map(
		"KeyPressOSD", true,
		"PointerHalo", false,
		"ClickRipples", false,
		"DragIndicator", false
	)
}

SmartProfileManager.Register(SmartDefaultProfile, true)
