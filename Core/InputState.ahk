; SmartKeyPressOSD - persistent shared input state
; The object is allocated once and updated in place every poll.

class SmartInputState {
	X := 0
	Y := 0

	LeftM := false
	MiddleM := false
	RightM := false
	MouseDown := false

	Ctrl := false
	Shift := false
	Alt := false

	Update() {
		mouseX := 0
		mouseY := 0
		MouseGetPos(&mouseX, &mouseY)

		this.X := mouseX
		this.Y := mouseY

		this.LeftM := !!GetKeyState("LButton", "P")
		this.MiddleM := !!GetKeyState("MButton", "P")
		this.RightM := !!GetKeyState("RButton", "P")
		this.MouseDown := this.LeftM || this.MiddleM || this.RightM

		; Current plugins need modifier state only while a mouse button is down.
		; Avoid six additional GetKeyState calls during normal idle movement.
		if this.MouseDown {
			this.Ctrl := !!(GetKeyState("LCtrl", "P") || GetKeyState("RCtrl", "P"))
			this.Shift := !!(GetKeyState("LShift", "P") || GetKeyState("RShift", "P"))
			this.Alt := !!(GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P"))
		} else {
			this.Ctrl := false
			this.Shift := false
			this.Alt := false
		}
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
