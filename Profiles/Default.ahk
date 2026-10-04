; SmartInputVisuals default profile and canonical plugin definitions
; Used whenever no enabled application-specific profile matches.
;
; PluginDefinitions is the explicit availability whitelist. A registered plugin
; without an entry there remains unavailable. DisplayName is concise user-facing
; metadata used by the tray and toolbar. Missing PluginStates entries default to OFF.

class SmartDefaultProfile {
	static Name := "Default"

	; Initial toolbar position, title/layout mode, optional button sizing, shared opacity
	; and RGB colours. Dragging changes the position only for the current session;
	; this file is never rewritten.
	static Toolbar := {
		X: 400,
		Y: 50,
		Opacity: 170,
		ShowProfileName: true,
		Layout: "V",
		ButtonHeight: 44,
		ButtonPaddingX: 14,
		ButtonSpacing: 6,
		BackgroundColor: 0xFFFF9B,
		ButtonColor: 0x00FAFA,
		TextColor: 0x0000FF
	}

	static PluginDefinitions := Map(
		"KeyPressOSD", PluginDefinition("Keys"),
		"PointerHalo", PluginDefinition("Halo"),
		"ClickRipples", PluginDefinition("Clicks"),
		"DragIndicator", PluginDefinition("Drag"),
		"MagnifierLens", PluginDefinition("Lens")
	)

	static PluginStates := Map(
		"KeyPressOSD", false,
		"PointerHalo", false,
		"ClickRipples", false,
		"DragIndicator", false,
		"MagnifierLens", false
	)
}

SmartProfileManager.Register(SmartDefaultProfile, true)
