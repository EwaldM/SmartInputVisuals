; SmartInputVisuals - temporary per-monitor DPI context
; Keeps pointer, window and layered-window coordinates in physical screen pixels.

class SmartDpiContext {
	static Supported := true
	static PerMonitorAware := -3 ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE

	static EnterPerMonitor() {
		if !this.Supported
			return 0

		try {
			previousContext := DllCall(
				"user32\SetThreadDpiAwarenessContext",
				"Ptr", this.PerMonitorAware,
				"Ptr"
			)

			if !previousContext
				this.Supported := false

			return previousContext
		} catch {
			; Older Windows versions may not provide this API. In that case,
			; keep the script functional using AutoHotkey's normal DPI context.
			this.Supported := false
			return 0
		}
	}

	static Restore(previousContext) {
		if !previousContext || !this.Supported
			return

		try {
			DllCall(
				"user32\SetThreadDpiAwarenessContext",
				"Ptr", previousContext,
				"Ptr"
			)
		} catch {
			this.Supported := false
		}
	}
}
