; SmartKeyPressOSD default profile
; Used whenever no enabled application-specific profile matches.

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
