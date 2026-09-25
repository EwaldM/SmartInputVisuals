; SmartInputVisuals default profile
; Used whenever no enabled application-specific profile matches.

class SmartDefaultProfile {
	static Name := "Default"
	static Plugins := Map(
		"KeyPressOSD", false,
		"PointerHalo", false,
		"ClickRipples", true,
		"DragIndicator", false
	)
}

SmartProfileManager.Register(SmartDefaultProfile, true)
