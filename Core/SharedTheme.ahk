; SmartInputVisuals - shared visual theme
; These values are available to the host and every plugin.

class SmartInputVisualsTheme {
	; ARGB mouse-button colours shared globally by all visualisations.
	static MouseColors := Map(
		"LeftM",   0xFF0000FF,  ; blue
		"MiddleM", 0xFF008000,  ; green
		"RightM",  0xFFFF0000   ; red
	)

	static ModifierColor := 0xFFFFA500  ; orange
	static OtherTextColor := 0xFF000000 ; black

	static BackgroundColor := 0x40FFFF00 ; yellow at approximately 25% opacity

	static FadeDuration := 450
	static IdleFadeDuration := 900
}
