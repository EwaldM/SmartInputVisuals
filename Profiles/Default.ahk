; SmartInputVisuals default profile and canonical plugin definitions
; Used whenever no enabled application-specific profile matches.
;
; The PluginDefinitions Map key is the stable internal plugin name. DisplayName
; is kept separately as user-facing metadata and is repeated here for clarity.
; PluginStates supplies the complete baseline enable/disable state for all plugins.

class SmartDefaultProfile {
	static Name := "Default"

	static PluginDefinitions := Map(
		"KeyPressOSD", PluginDefinition("KeyPressOSD"),
		"PointerHalo", PluginDefinition("PointerHalo"),
		"ClickRipples", PluginDefinition("ClickRipples"),
		"DragIndicator", PluginDefinition("DragIndicator"),
		"MagnifierLens", PluginDefinition("MagnifierLens")
	)

	static PluginStates := Map(
		"KeyPressOSD", false,
		"PointerHalo", false,
		"ClickRipples", true,
		"DragIndicator", false,
		"MagnifierLens", false
	)
}

SmartProfileManager.Register(SmartDefaultProfile, true)
