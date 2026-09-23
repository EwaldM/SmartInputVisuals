; SmartKeyPressOSD - central GDI+ lifetime management
; gdiplus.dll itself is kept resident by #DllLoad in SmartKeyPressOSD.ahk.

class GDIPlusHost {
	static Token := 0

	static Init() {
		if this.Token
			return

		startupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
		NumPut("UInt", 1, startupInput, 0)

		token := 0
		status := DllCall(
			"gdiplus\GdiplusStartup",
			"UPtr*", &token,
			"Ptr", startupInput.Ptr,
			"Ptr", 0,
			"Int"
		)
		this.Check(status, "GdiplusStartup")
		this.Token := token
	}

	static Shutdown() {
		if !this.Token
			return

		; Clear the global token before calling into GDI+ so shutdown remains
		; idempotent even if another exit path is triggered while exiting.
		token := this.Token
		this.Token := 0
		DllCall("gdiplus\GdiplusShutdown", "UPtr", token)
	}

	static Check(status, operation) {
		if status != 0
			throw Error(operation " failed (GDI+ status " status ").")
	}
}
