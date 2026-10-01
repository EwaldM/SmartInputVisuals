; SmartInputVisuals - registry of top-level visual overlay windows
; Lets plugins such as MagnifierLens exclude SmartInputVisuals overlays from capture.

class SmartOverlayRegistry {
	static Windows := Map()
	static Generation := 0

	static Register(hwnd) {
		if !hwnd || this.Windows.Has(hwnd)
			return

		this.Windows[hwnd] := true
		this.Generation += 1
	}

	static Unregister(hwnd) {
		if !hwnd || !this.Windows.Has(hwnd)
			return

		this.Windows.Delete(hwnd)
		this.Generation += 1
	}

	static GetWindows(excludeHwnd := 0) {
		windows := []
		stale := []

		for hwnd, unused in this.Windows {
			if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int") {
				stale.Push(hwnd)
				continue
			}

			if hwnd != excludeHwnd
				windows.Push(hwnd)
		}

		for hwnd in stale {
			this.Windows.Delete(hwnd)
			this.Generation += 1
		}

		return windows
	}

	static PlaceBelowRegistered(hwnd) {
		if !hwnd
			return

		lowestOverlay := 0
		candidate := DllCall("user32\GetTopWindow", "Ptr", 0, "Ptr")

		Loop 4096 {
			if !candidate
				break

			if candidate != hwnd && this.Windows.Has(candidate)
				lowestOverlay := candidate

			candidate := DllCall(
				"user32\GetWindow",
				"Ptr", candidate,
				"UInt", 2, ; GW_HWNDNEXT
				"Ptr"
			)
		}

		if !lowestOverlay
			return

		DllCall(
			"user32\SetWindowPos",
			"Ptr", hwnd,
			"Ptr", lowestOverlay,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"UInt", 0x0001 | 0x0002 | 0x0010,
			"Int"
		)
	}
}
