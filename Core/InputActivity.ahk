; SmartKeyPressOSD - keyboard activity tracking
; Uses one non-blocking InputHook to detect ordinary keyboard activity centrally.

class SmartInputActivity {
	static VisualsWhileTyping := false
	static VisualDelayAfterTyping := 750

	static Hook := 0
	static LastTypingTick := 0

	static Init() {
		if this.Hook
			return

		hook := InputHook("V L0")
		hook.KeyOpt("{All}", "N")
		hook.OnKeyDown := ObjBindMethod(this, "HandleKeyDown")
		hook.Start()
		this.Hook := hook
	}

	static Shutdown() {
		if !this.Hook
			return

		try this.Hook.Stop()
		this.Hook := 0
	}

	static HandleKeyDown(inputHook, vk, sc) {
		; Modifier-only presses do not count as typing. A real key in a combination
		; such as Ctrl+C does count because the C key generates its own event.
		if this.IsModifierVk(vk)
			return

		this.LastTypingTick := A_TickCount
	}

	static IsModifierVk(vk) {
		switch vk {
			case 0x10, 0x11, 0x12, 0x5B, 0x5C, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5:
				return true
			default:
				return false
		}
	}

	static IsTypingActive(now := A_TickCount) {
		if this.VisualsWhileTyping || !this.LastTypingTick
			return false

		return (now - this.LastTypingTick) < this.VisualDelayAfterTyping
	}
}
