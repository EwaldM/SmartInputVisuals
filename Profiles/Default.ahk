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
		X: 20,
		Y: 20,
		Opacity: 170,
		ShowProfileName: true,
		Layout: "H",
		ButtonHeight: 44,
		ButtonPaddingX: 14,
		ButtonSpacing: 6,
		BackgroundColor: 0x202020,
		ButtonColor: 0x404040,
		TextColor: 0xFFFFFF
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
		"ClickRipples", true,
		"DragIndicator", false,
		"MagnifierLens", false
	)
}

SmartProfileManager.Register(SmartDefaultProfile, true)
