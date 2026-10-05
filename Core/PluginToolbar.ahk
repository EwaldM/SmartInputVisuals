; SmartInputVisuals - compact always-on-top plugin toolbar
; Shows the configured title and one toggle button per available plugin.

class SmartPluginToolbar {
	static VisibleByDefault := true
	static TitleHeight := 20
	static ButtonHeight := 26
	static ButtonGap := 4
	static ButtonPaddingX := -1 ; -1 preserves the legacy width calculation
	static MarginX := 6
	static MarginY := 5
	static Opacity := 255
	static ShowProfileName := true
	static Layout := "H"
	static BackgroundColor := 0x202020
	static ButtonColor := 0x404040
	static TextColor := 0xFFFFFF

	static Initialised := false
	static Gui := 0
	static TitleControl := 0
	static PluginInfo := []
	static Buttons := Map()
	static ButtonsByHwnd := Map()
	static ButtonCallbacks := Map()
	static ButtonBrush := 0
	static TargetProfile := 0
	static Paused := false
	static Visible := false
	static LastProfileKey := ""
	static LastPluginStates := Map()
	static TitleClickTime := 0
	static TitleClickX := 0
	static TitleClickY := 0
	static TitleMouseDownCallback := 0
	static ExitSizeMoveCallback := 0
	static DrawItemCallback := 0

	static Init(paused := false) {
		if this.Initialised
			return

		this.Paused := !!paused
		this.PluginInfo := PluginManager.GetRegisteredPluginInfo()
		this.DrawItemCallback := ObjBindMethod(this, "HandleDrawItem")
		OnMessage(0x002B, this.DrawItemCallback) ; WM_DRAWITEM for owner-drawn buttons
		try this.BuildGui()
		catch {
			OnMessage(0x002B, this.DrawItemCallback, 0)
			this.DrawItemCallback := 0
			throw
		}

		SmartAppScope.RegisterHostWindow(this.Gui.Hwnd)
		SmartOverlayRegistry.Register(this.Gui.Hwnd)

		this.TitleMouseDownCallback := ObjBindMethod(this, "HandleTitleMouseDown")
		this.ExitSizeMoveCallback := ObjBindMethod(this, "HandleExitSizeMove")
		OnMessage(0x0201, this.TitleMouseDownCallback) ; WM_LBUTTONDOWN
		OnMessage(0x0203, this.TitleMouseDownCallback) ; WM_LBUTTONDBLCLK
		OnMessage(0x0216, this.ExitSizeMoveCallback) ; WM_MOVING clears click candidate
		OnMessage(0x0232, this.ExitSizeMoveCallback) ; WM_EXITSIZEMOVE

		this.Initialised := true
		this.TargetProfile := SmartProfileManager.ActiveProfile
		this.Refresh(true)

		if this.VisibleByDefault
			this.Show()
	}

	static BuildGui() {
		settings := this.GetToolbarSettings()
		this.Opacity := settings.Opacity
		this.ShowProfileName := settings.ShowProfileName
		this.Layout := settings.Layout
		this.ButtonHeight := settings.ButtonHeight
		this.ButtonGap := settings.ButtonSpacing
		this.ButtonPaddingX := settings.ButtonPaddingX
		this.BackgroundColor := settings.BackgroundColor
		this.ButtonColor := settings.ButtonColor
		this.TextColor := settings.TextColor

		this.Gui := Gui(
			"+AlwaysOnTop -Caption +ToolWindow +Border +E0x08080000",
			"SmartInputVisuals Toolbar"
		)
		this.Gui.MarginX := this.MarginX
		this.Gui.MarginY := this.MarginY
		this.Gui.BackColor := this.BackgroundColor
		this.Gui.SetFont(
			"s9 c" this.FormatRgb(this.TextColor),
			"Segoe UI"
		)
		this.Gui.OnEvent("Close", ObjBindMethod(this, "PreventClose"))

		; Keep the title from determining the toolbar width. The button layout
		; determines the width, then the title is expanded to that width below.
		; SS_ENDELLIPSIS (0x4000) truncates an overlong profile/application title.
		this.TitleControl := this.Gui.Add(
			"Text",
			"xm ym w1 h" this.TitleHeight " +0x100 +0x200 +0x4000",
			"Default"
		)
		this.TitleControl.SetFont("bold c" this.FormatRgb(this.TextColor))

		this.Buttons.Clear()
		this.ButtonsByHwnd.Clear()
		this.ButtonCallbacks.Clear()
		this.LastPluginStates.Clear()

		if this.ButtonBrush
			DllCall("gdi32\DeleteObject", "Ptr", this.ButtonBrush)
		this.ButtonBrush := DllCall(
			"gdi32\CreateSolidBrush",
			"UInt", this.ToColorRef(this.ButtonColor),
			"Ptr"
		)
		if !this.ButtonBrush
			throw OSError()

		availablePlugins := []
		for info in this.PluginInfo {
			; Registered plugins which are not whitelisted, or plugins that became
			; unhealthy during initialisation, stay out of the compact toolbar.
			if PluginManager.IsPluginAvailable(info.Name)
				availablePlugins.Push(info)
		}

		verticalButtonWidth := 0
		if this.Layout = "V" {
			for info in availablePlugins
				verticalButtonWidth := Max(verticalButtonWidth, this.GetButtonWidth(info.DisplayName))
		}

		index := 0
		for info in availablePlugins {
			index += 1
			buttonWidth := this.Layout = "V"
				? verticalButtonWidth
				: this.GetButtonWidth(info.DisplayName)

			if index = 1 {
				options := "xm y+4 h" this.ButtonHeight " w" buttonWidth
			} else if this.Layout = "V" {
				options := "xm y+" this.ButtonGap " h" this.ButtonHeight " w" buttonWidth
			} else {
				options := "x+" this.ButtonGap " yp h" this.ButtonHeight " w" buttonWidth
			}

			button := this.Gui.Add("Button", options, "✓ " info.DisplayName)
			this.Buttons[info.Name] := button
			this.ButtonsByHwnd[button.Hwnd] := button
			this.EnableOwnerDraw(button.Hwnd)

			callback := ObjBindMethod(this, "TogglePlugin", info.Name)
			button.OnEvent("Click", callback)
			this.ButtonCallbacks[info.Name] := callback
		}

		; With no available plugins, retain a small title-only toolbar rather than
		; allowing AutoSize to collapse to the 1-pixel placeholder title.
		if index = 0
			this.TitleControl.Move(, , 80, this.TitleHeight)

		; Create the native window and let AutoHotkey size it around the controls.
		this.Gui.Show("Hide AutoSize")

		; Keep GUI sizing in AutoHotkey's own DPI-scaled coordinate system.
		; Mixing GetClientRect's physical pixels with GuiControl.Move caused the
		; title to be visibly shifted on DPI-scaled displays.
		clientX := 0
		clientY := 0
		clientWidth := 0
		clientHeight := 0
		this.Gui.GetClientPos(&clientX, &clientY, &clientWidth, &clientHeight)
		titleWidth := Max(1, clientWidth - this.MarginX * 2)
		this.TitleControl.Move(
			this.MarginX,
			this.MarginY,
			titleWidth,
			this.TitleHeight
		)

		this.PositionWithinVirtualDesktop(settings.X, settings.Y)
		this.ApplyOpacity()
	}

	static GetButtonWidth(displayName) {
		; Reserve space for the ON marker even while the current state is OFF so
		; toggling does not change button geometry. When ButtonPaddingX is omitted,
		; preserve the original width calculation exactly for compatibility.
		textWidth := StrLen("✓ " displayName) * 7
		if this.ButtonPaddingX < 0
			return Max(64, 20 + textWidth)

		return Max(64, this.ButtonPaddingX * 2 + textWidth)
	}

	static GetToolbarSettings() {
		if !SmartProfileManager.DefaultProfile
			throw Error("SmartInputVisuals requires the Default profile before the toolbar is initialised.")

		settings := 0
		try settings := SmartProfileManager.DefaultProfile.Toolbar
		catch
			throw Error(
				"Default profile must define Toolbar with X, Y, Opacity, ShowProfileName, Layout, "
				"BackgroundColor, ButtonColor and TextColor settings."
			)

		x := this.GetRequiredToolbarSetting(settings, "X")
		y := this.GetRequiredToolbarSetting(settings, "Y")
		opacity := this.GetRequiredToolbarSetting(settings, "Opacity")
		showProfileName := this.GetRequiredToolbarSetting(settings, "ShowProfileName")
		layout := StrUpper(Trim(this.GetRequiredToolbarSetting(settings, "Layout")))
		backgroundColor := this.GetRequiredToolbarSetting(settings, "BackgroundColor")
		buttonColor := this.GetRequiredToolbarSetting(settings, "ButtonColor")
		textColor := this.GetRequiredToolbarSetting(settings, "TextColor")

		; Optional touch/layout sizing settings. Omitting them preserves the
		; pre-configuration toolbar geometry exactly.
		buttonHeight := this.GetOptionalToolbarSetting(settings, "ButtonHeight", 26)
		buttonSpacing := this.GetOptionalToolbarSetting(settings, "ButtonSpacing", 4)
		buttonPaddingX := this.GetOptionalToolbarSetting(settings, "ButtonPaddingX", -1)

		if !this.IsNumber(x) || !this.IsNumber(y)
			throw Error("Default profile Toolbar X and Y must be numeric screen coordinates.")
		if !this.IsNumber(opacity) || opacity < 1 || opacity > 255
			throw Error("Default profile Toolbar Opacity must be between 1 and 255.")
		if Type(showProfileName) != "Integer" || (showProfileName != 0 && showProfileName != 1)
			throw Error("Default profile Toolbar ShowProfileName must be true or false.")
		if layout != "H" && layout != "V"
			throw Error("Default profile Toolbar Layout must be H or V.")
		if !this.IsNumber(buttonHeight) || buttonHeight < 20
			throw Error("Default profile Toolbar ButtonHeight must be at least 20 pixels.")
		if !this.IsNumber(buttonSpacing) || buttonSpacing < 0
			throw Error("Default profile Toolbar ButtonSpacing must not be negative.")
		if buttonPaddingX != -1 && (!this.IsNumber(buttonPaddingX) || buttonPaddingX < 0)
			throw Error("Default profile Toolbar ButtonPaddingX must not be negative.")
		this.ValidateRgbColor(backgroundColor, "BackgroundColor")
		this.ValidateRgbColor(buttonColor, "ButtonColor")
		this.ValidateRgbColor(textColor, "TextColor")

		return {
			X: Round(x),
			Y: Round(y),
			Opacity: Round(opacity),
			ShowProfileName: !!showProfileName,
			Layout: layout,
			ButtonHeight: Round(buttonHeight),
			ButtonSpacing: Round(buttonSpacing),
			ButtonPaddingX: buttonPaddingX = -1 ? -1 : Round(buttonPaddingX),
			BackgroundColor: backgroundColor,
			ButtonColor: buttonColor,
			TextColor: textColor
		}
	}

	static GetRequiredToolbarSetting(settings, name) {
		try return settings.%name%
		catch
			throw Error("Default profile Toolbar is missing " name ".")
	}

	static GetOptionalToolbarSetting(settings, name, fallback) {
		try return settings.%name%
		catch
			return fallback
	}

	static ValidateRgbColor(value, name) {
		if Type(value) != "Integer" || value < 0 || value > 0xFFFFFF {
			throw Error(
				"Default profile Toolbar " name
				" must be an RGB integer between 0x000000 and 0xFFFFFF."
			)
		}
	}

	static IsNumber(value) {
		valueType := Type(value)
		return valueType = "Integer" || valueType = "Float"
	}

	static ApplyOpacity() {
		if !this.Gui
			return

		if !DllCall(
			"user32\SetLayeredWindowAttributes",
			"Ptr", this.Gui.Hwnd,
			"UInt", 0,
			"UChar", this.Opacity,
			"UInt", 0x2, ; LWA_ALPHA
			"Int"
		)
			throw OSError()
	}


	static EnableOwnerDraw(hwnd) {
		; BS_OWNERDRAW (0x0B) is a button *type* style. Replace the existing
		; low-order BS_* type bits instead of OR-ing 0x0B into whatever
		; AutoHotkey/Windows created for the control. This reliably makes the
		; parent receive WM_DRAWITEM, while retaining all unrelated window styles.
		getStyleProc := A_PtrSize = 8 ? "user32\GetWindowLongPtrW" : "user32\GetWindowLongW"
		setStyleProc := A_PtrSize = 8 ? "user32\SetWindowLongPtrW" : "user32\SetWindowLongW"
		styleType := A_PtrSize = 8 ? "Ptr" : "Int"

		style := DllCall(
			getStyleProc,
			"Ptr", hwnd,
			"Int", -16, ; GWL_STYLE
			styleType
		)
		ownerDrawStyle := (style & ~0xF) | 0x0B ; BS_OWNERDRAW

		DllCall(
			setStyleProc,
			"Ptr", hwnd,
			"Int", -16, ; GWL_STYLE
			styleType, ownerDrawStyle,
			styleType
		)

		; Ensure Windows recognises the changed control style before first display.
		DllCall(
			"user32\SetWindowPos",
			"Ptr", hwnd,
			"Ptr", 0,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"Int", 0,
			"UInt", 0x37, ; NOMOVE|NOSIZE|NOZORDER|NOACTIVATE|FRAMECHANGED
			"Int"
		)
	}

	static FormatRgb(rgb) {
		return Format("{:06X}", rgb & 0xFFFFFF)
	}

	static ToColorRef(rgb) {
		r := (rgb >> 16) & 0xFF
		g := (rgb >> 8) & 0xFF
		b := rgb & 0xFF
		return r | (g << 8) | (b << 16)
	}

	static BlendRgb(foreground, background, foregroundWeight := 0.5) {
		backgroundWeight := 1.0 - foregroundWeight
		r := Round(((foreground >> 16) & 0xFF) * foregroundWeight
			+ ((background >> 16) & 0xFF) * backgroundWeight)
		g := Round(((foreground >> 8) & 0xFF) * foregroundWeight
			+ ((background >> 8) & 0xFF) * backgroundWeight)
		b := Round((foreground & 0xFF) * foregroundWeight
			+ (background & 0xFF) * backgroundWeight)
		return (r << 16) | (g << 8) | b
	}

	static HandleDrawItem(wParam, lParam, msg, hwnd) {
		if !lParam
			return

		; DRAWITEMSTRUCT.CtlType == ODT_BUTTON.
		if NumGet(lParam, 0, "UInt") != 4
			return

		ptrOffset := A_PtrSize = 8 ? 24 : 20
		hdcOffset := ptrOffset + A_PtrSize
		rectOffset := hdcOffset + A_PtrSize
		hwndItem := NumGet(lParam, ptrOffset, "Ptr")
		if !this.ButtonsByHwnd.Has(hwndItem)
			return

		button := this.ButtonsByHwnd[hwndItem]
		hdc := NumGet(lParam, hdcOffset, "Ptr")
		itemState := NumGet(lParam, 16, "UInt")
		rectPtr := lParam + rectOffset

		if !DllCall(
			"user32\FillRect",
			"Ptr", hdc,
			"Ptr", rectPtr,
			"Ptr", this.ButtonBrush,
			"Int"
		)
			throw OSError()

		; Preserve familiar native pressed/unpressed edges around the configured fill.
		edge := itemState & 0x1 ? 0x000A : 0x0005 ; ODS_SELECTED ? EDGE_SUNKEN : EDGE_RAISED
		DllCall(
			"user32\DrawEdge",
			"Ptr", hdc,
			"Ptr", rectPtr,
			"UInt", edge,
			"UInt", 0x000F, ; BF_RECT
			"Int"
		)

		textRgb := itemState & 0x4
			? this.BlendRgb(this.TextColor, this.ButtonColor, 0.45) ; ODS_DISABLED
			: this.TextColor
		oldBkMode := DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1, "Int") ; TRANSPARENT
		oldTextColor := DllCall(
			"gdi32\SetTextColor",
			"Ptr", hdc,
			"UInt", this.ToColorRef(textRgb),
			"UInt"
		)

		font := SendMessage(0x0031, 0, 0, button.Hwnd) ; WM_GETFONT
		oldFont := 0
		if font
			oldFont := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", font, "Ptr")

		DllCall(
			"user32\DrawTextW",
			"Ptr", hdc,
			"Str", button.Text,
			"Int", -1,
			"Ptr", rectPtr,
			"UInt", 0x0825, ; DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX
			"Int"
		)

		if itemState & 0x10 ; ODS_FOCUS
			DllCall("user32\DrawFocusRect", "Ptr", hdc, "Ptr", rectPtr, "Int")

		if oldFont
			DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
		DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", oldTextColor, "UInt")
		DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", oldBkMode, "Int")
		return 1
	}


	static Update(state) {
		if !this.Initialised
			return

		this.TargetProfile := SmartProfileManager.ActiveProfile
		this.Refresh()
	}

	static SetPaused(paused) {
		if !this.Initialised
			return

		paused := !!paused
		if paused = this.Paused
			return

		this.Paused := paused
		this.Refresh(true)
	}

	static TogglePlugin(pluginName, *) {
		if this.Paused || !this.TargetProfile || !PluginManager.IsPluginAvailable(pluginName)
			return

		enabled := false
		if !SmartProfileManager.TogglePluginForProfile(
			this.TargetProfile,
			pluginName,
			&enabled
		)
			return

		this.Refresh(true)
		SmartTrayController.Refresh(true)
	}

	static Refresh(force := false) {
		if !this.Initialised
			return

		profileKey := SmartProfileManager.GetProfileKey(this.TargetProfile)
		profileChanged := profileKey != this.LastProfileKey

		if force || (this.ShowProfileName && profileChanged)
			this.TitleControl.Text := this.GetTitleText()

		for info in this.PluginInfo {
			if !this.Buttons.Has(info.Name)
				continue

			button := this.Buttons[info.Name]
			available := PluginManager.IsPluginAvailable(info.Name)
			enabled := false

			if this.TargetProfile && available {
				enabled := SmartProfileManager.IsPluginEnabledForProfile(
					this.TargetProfile,
					info.Name
				)
			}

			interactive := !!(this.TargetProfile && available && !this.Paused)
			stateKey := (available ? "1" : "0") ":" (enabled ? "1" : "0") ":" (interactive ? "1" : "0")

			if !force
				&& !profileChanged
				&& this.LastPluginStates.Has(info.Name)
				&& this.LastPluginStates[info.Name] = stateKey
				continue

			; Runtime failures remove the plugin from the toolbar. Plugins that were
			; unavailable at startup never had a toolbar button created at all.
			button.Visible := available
			if enabled
				button.Text := "✓ " info.DisplayName
			else
				button.Text := info.DisplayName

			button.Enabled := interactive
			DllCall(
				"user32\InvalidateRect",
				"Ptr", button.Hwnd,
				"Ptr", 0,
				"Int", true
			)
			this.LastPluginStates[info.Name] := stateKey
		}

		this.LastProfileKey := profileKey
	}

	static GetTitleText() {
		if !this.ShowProfileName {
			appName := Trim(SmartTrayController.AppName)
			return appName != "" ? appName : "SmartInputVisuals"
		}

		profileName := SmartProfileManager.GetProfileName(this.TargetProfile)
		return profileName != "" ? profileName : "Default"
	}

	static ToggleVisible() {
		if !this.Initialised
			return false

		if this.Visible
			this.Hide()
		else
			this.Show()

		return this.Visible
	}

	static Show() {
		if !this.Initialised || this.Visible
			return

		this.ClampCurrentPosition()
		this.Gui.Show("NA")
		this.Visible := true
	}

	static Hide() {
		if !this.Initialised || !this.Visible
			return

		this.TitleClickTime := 0
		this.Gui.Hide()
		this.Visible := false
	}

	static IsVisible() {
		return !!(this.Initialised && this.Visible)
	}

	static HandleTitleMouseDown(wParam, lParam, msg, hwnd) {
		if !this.Initialised || !this.Visible || !this.TitleControl
			return
		if hwnd != this.TitleControl.Hwnd {
			this.TitleClickTime := 0
			return
		}

		; The native move loop can consume the first button release. Recognise
		; the second press using Windows' time and distance settings, whether
		; it arrives as WM_LBUTTONDOWN or WM_LBUTTONDBLCLK.
		position := DllCall("user32\GetMessagePos", "UInt")
		x := (position & 0xFFFF) << 48 >> 48
		y := ((position >> 16) & 0xFFFF) << 48 >> 48
		now := DllCall("kernel32\GetTickCount64", "UInt64")
		if this.TitleClickTime
			&& now - this.TitleClickTime <= DllCall("user32\GetDoubleClickTime", "UInt")
			&& Abs(x - this.TitleClickX) * 2 < DllCall("user32\GetSystemMetrics", "Int", 36, "Int")
			&& Abs(y - this.TitleClickY) * 2 < DllCall("user32\GetSystemMetrics", "Int", 37, "Int") {
			this.TitleClickTime := 0
			SmartTrayController.ToggleToolbar()
			return 0
		}
		this.TitleClickTime := now
		this.TitleClickX := x
		this.TitleClickY := y

		DllCall("user32\ReleaseCapture")
		DllCall(
			"user32\PostMessageW",
			"Ptr", this.Gui.Hwnd,
			"UInt", 0x00A1, ; WM_NCLBUTTONDOWN
			"Ptr", 2, ; HTCAPTION
			"Ptr", 0,
			"Int"
		)
		return 0
	}

	static HandleExitSizeMove(wParam, lParam, msg, hwnd) {
		if !this.Initialised || !this.Gui || hwnd != this.Gui.Hwnd
			return

		if msg = 0x0216 { ; WM_MOVING: a drag must not become a double-click.
			this.TitleClickTime := 0
			return
		}
		this.ClampCurrentPosition()
	}

	static PreventClose(*) {
		; Hide through the title double-click or tray-menu item instead of closing.
		return true
	}

	static ClampCurrentPosition() {
		if !this.Gui
			return

		rect := this.GetWindowRect()
		if !rect
			return

		this.PositionWithinVirtualDesktop(rect.X, rect.Y)
	}

	static PositionWithinVirtualDesktop(x, y) {
		if !this.Gui
			return

		rect := this.GetWindowRect()
		if !rect
			return

		left := DllCall("user32\GetSystemMetrics", "Int", 76, "Int")
		top := DllCall("user32\GetSystemMetrics", "Int", 77, "Int")
		virtualWidth := DllCall("user32\GetSystemMetrics", "Int", 78, "Int")
		virtualHeight := DllCall("user32\GetSystemMetrics", "Int", 79, "Int")
		right := left + virtualWidth
		bottom := top + virtualHeight

		x := this.Clamp(Round(x), left, right - rect.Width)
		y := this.Clamp(Round(y), top, bottom - rect.Height)

		if !DllCall(
			"user32\SetWindowPos",
			"Ptr", this.Gui.Hwnd,
			"Ptr", 0,
			"Int", x,
			"Int", y,
			"Int", 0,
			"Int", 0,
			"UInt", 0x0015, ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
			"Int"
		)
			throw OSError()
	}

	static GetWindowRect() {
		if !this.Gui
			return 0

		rect := Buffer(16, 0)
		if !DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd, "Ptr", rect.Ptr, "Int")
			return 0

		left := NumGet(rect, 0, "Int")
		top := NumGet(rect, 4, "Int")
		right := NumGet(rect, 8, "Int")
		bottom := NumGet(rect, 12, "Int")
		return {
			X: left,
			Y: top,
			Width: right - left,
			Height: bottom - top
		}
	}

	static Clamp(value, minimum, maximum) {
		if maximum < minimum
			return minimum
		return Min(maximum, Max(minimum, value))
	}

	static Shutdown() {
		if !this.Initialised
			return

		if this.TitleMouseDownCallback {
			OnMessage(0x0201, this.TitleMouseDownCallback, 0)
			OnMessage(0x0203, this.TitleMouseDownCallback, 0)
		}
		if this.ExitSizeMoveCallback {
			OnMessage(0x0216, this.ExitSizeMoveCallback, 0)
			OnMessage(0x0232, this.ExitSizeMoveCallback, 0)
		}
		if this.DrawItemCallback
			OnMessage(0x002B, this.DrawItemCallback, 0)

		if this.Gui {
			SmartAppScope.UnregisterHostWindow(this.Gui.Hwnd)
			SmartOverlayRegistry.Unregister(this.Gui.Hwnd)
			this.Gui.Destroy()
		}

		this.Gui := 0
		this.TitleControl := 0
		this.PluginInfo := []
		this.Buttons.Clear()
		this.ButtonsByHwnd.Clear()
		this.ButtonCallbacks.Clear()
		if this.ButtonBrush {
			DllCall("gdi32\DeleteObject", "Ptr", this.ButtonBrush)
			this.ButtonBrush := 0
		}
		this.LastPluginStates.Clear()
		this.TargetProfile := 0
		this.DrawItemCallback := 0
		this.TitleClickTime := 0
		this.Visible := false
		this.Initialised := false
	}
}
