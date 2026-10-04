; SmartInputVisuals - physical monitor geometry helpers

class SmartMonitorGeometry {
	static GetBoundsAtPoint(x, y) {
		packedPoint := (x & 0xFFFFFFFF) | ((y & 0xFFFFFFFF) << 32)
		; MONITOR_DEFAULTTONEAREST = 2.
		hMonitor := DllCall(
			"user32\MonitorFromPoint",
			"Int64", packedPoint,
			"UInt", 2,
			"Ptr"
		)
		if !hMonitor
			throw OSError()

		monitorInfo := Buffer(40, 0)
		NumPut("UInt", 40, monitorInfo, 0)
		if !DllCall(
			"user32\GetMonitorInfoW",
			"Ptr", hMonitor,
			"Ptr", monitorInfo.Ptr,
			"Int"
		)
			throw OSError()

		return {
			Left: NumGet(monitorInfo, 4, "Int"),
			Top: NumGet(monitorInfo, 8, "Int"),
			Right: NumGet(monitorInfo, 12, "Int"),
			Bottom: NumGet(monitorInfo, 16, "Int")
		}
	}
}
