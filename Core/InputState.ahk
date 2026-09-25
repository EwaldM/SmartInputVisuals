; SmartKeyPressOSD - persistent shared input state
; The object is allocated once and updated in place every poll.

class SmartInputState {
	X := 0
	Y := 0
	MouseMoved := false
	LastMouseMoveTick := 0
	Initialised := false

	LeftM := false
	MiddleM := false
	RightM := false
	MouseDown := false

	Ctrl := false
	Shift := false
	Alt := false

	TypingActive := false

	HoverHwnd := 0
	ActiveHwnd := 0
	HoverProcess := ""
	ActiveProcess := ""
	HoverClass := ""
	ActiveClass := ""
	HoverIsTraySurface := false
	DisplayAllowed := true

	ProfileProcess := ""

	Update() {
		mouseX := 0
		mouseY := 0
		hoverHwnd := 0
		MouseGetPos(&mouseX, &mouseY, &hoverHwnd)

		if !this.Initialised {
			this.X := mouseX
			this.Y := mouseY
			this.MouseMoved := false
			this.LastMouseMoveTick := A_TickCount
			this.Initialised := true
		} else {
			this.MouseMoved := (mouseX != this.X || mouseY != this.Y)
			this.X := mouseX
			this.Y := mouseY

			if this.MouseMoved
				this.LastMouseMoveTick := A_TickCount
		}

		this.HoverHwnd := hoverHwnd

		this.LeftM := !!GetKeyState("LButton", "P")
		this.MiddleM := !!GetKeyState("MButton", "P")
		this.RightM := !!GetKeyState("RButton", "P")
		this.MouseDown := this.LeftM || this.MiddleM || this.RightM

		; Current visual plugins need modifier state only while a mouse button is
		; down. Avoid six additional GetKeyState calls during ordinary idle use.
		if this.MouseDown {
			this.Ctrl := !!(GetKeyState("LCtrl", "P") || GetKeyState("RCtrl", "P"))
			this.Shift := !!(GetKeyState("LShift", "P") || GetKeyState("RShift", "P"))
			this.Alt := !!(GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P"))
		} else {
			this.Ctrl := false
			this.Shift := false
			this.Alt := false
		}

		this.TypingActive := SmartInputActivity.IsTypingActive()
	}

	IsButtonDown(button) {
		switch button {
			case "LeftM":
				return this.LeftM
			case "MiddleM":
				return this.MiddleM
			case "RightM":
				return this.RightM
			default:
				return false
		}
	}
}
