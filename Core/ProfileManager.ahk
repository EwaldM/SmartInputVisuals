; SmartKeyPressOSD - application-specific plugin profiles
; Profiles select plugin sets according to the focused and/or hovered process.

class SmartProfileManager {
	static Enabled := true
	static SelectionMode := "HoverThenFocus"

	static Profiles := []
	static ProcessProfiles := Map()
	static RuntimePluginStates := Map()
	static DefaultProfile := 0
	static ActiveProfile := 0
	static ActiveProfileName := ""
	static ActiveProcess := ""

	static Register(profile, isDefault := false) {
		this.Profiles.Push(profile)

		if isDefault {
			if this.DefaultProfile
				throw Error("Only one SmartKeyPressOSD default profile may be registered.")
			this.DefaultProfile := profile
		}
	}

	static Init() {
		this.ProcessProfiles.Clear()
		this.RuntimePluginStates.Clear()
		this.ValidateSelectionMode(this.SelectionMode)

		profileNames := Map()

		for profile in this.Profiles {
			if !this.IsProfileEnabled(profile)
				continue

			profileKey := this.GetProfileKey(profile)
			if profileKey = ""
				throw Error("SmartKeyPressOSD profile names must not be empty.")
			if profileNames.Has(profileKey)
				throw Error("Duplicate SmartKeyPressOSD profile name '" this.GetProfileName(profile) "'.")
			profileNames[profileKey] := true

			if profile = this.DefaultProfile
				continue

			applications := []
			try applications := profile.Applications
			catch
				applications := []

			for processName in applications {
				normalized := StrLower(Trim(processName))
				if normalized = ""
					continue

				if this.ProcessProfiles.Has(normalized)
					throw Error("Duplicate SmartKeyPressOSD profile mapping for '" normalized "'.")

				this.ProcessProfiles[normalized] := profile
			}
		}

		this.ActiveProfile := this.DefaultProfile
		this.ActiveProfileName := this.GetProfileName(this.DefaultProfile)
	}

	static Update(state) {
		if !this.Enabled {
			this.ActiveProfile := this.DefaultProfile
			this.ActiveProfileName := this.GetProfileName(this.DefaultProfile)
			this.ActiveProcess := ""
			state.ProfileName := this.ActiveProfileName
			state.ProfileProcess := ""
			return
		}

		profile := 0
		processName := ""

		switch this.SelectionMode {
			case "HoverThenFocus":
				if state.HoverProcess != "" {
					processName := state.HoverProcess
					profile := this.FindProfile(processName)
				} else if state.ActiveProcess != "" {
					processName := state.ActiveProcess
					profile := this.FindProfile(processName)
				}
			case "FocusThenHover":
				if state.ActiveProcess != "" {
					processName := state.ActiveProcess
					profile := this.FindProfile(processName)
				} else if state.HoverProcess != "" {
					processName := state.HoverProcess
					profile := this.FindProfile(processName)
				}
			case "HoverOnly":
				processName := state.HoverProcess
				profile := this.FindProfile(processName)
			case "FocusOnly":
				processName := state.ActiveProcess
				profile := this.FindProfile(processName)
		}

		; The selected process always owns the profile decision. If it has no
		; application-specific mapping, use the Default profile rather than
		; falling back to a mapped application in the secondary context.
		if !profile
			profile := this.DefaultProfile

		this.ActiveProfile := profile
		this.ActiveProfileName := this.GetProfileName(profile)
		this.ActiveProcess := processName

		state.ProfileName := this.ActiveProfileName
		state.ProfileProcess := processName
	}

	static IsPluginEnabled(pluginName) {
		return this.IsPluginAvailable(pluginName) && this.IsPluginRuntimeEnabled(pluginName)
	}

	static IsPluginAvailable(pluginName) {
		if !this.Enabled
			return true

		return this.IsPluginAvailableForProfile(this.ActiveProfile, pluginName)
	}

	static IsPluginAvailableForProfile(profile, pluginName) {
		if !profile
			return false

		enabled := false
		if this.ProfileHasPluginSetting(profile, pluginName, &enabled)
			return enabled

		if this.DefaultProfile && profile != this.DefaultProfile {
			if this.ProfileHasPluginSetting(this.DefaultProfile, pluginName, &enabled)
				return enabled
		}

		return true
	}

	static IsPluginRuntimeEnabled(pluginName) {
		if !this.Enabled
			return true

		return this.IsPluginRuntimeEnabledForProfile(this.ActiveProfile, pluginName)
	}

	static IsPluginRuntimeEnabledForProfile(profile, pluginName) {
		if !profile
			return true

		runtimeMap := this.GetRuntimePluginMap(profile, false)
		if !runtimeMap || !runtimeMap.Has(pluginName)
			return true

		return !!runtimeMap[pluginName]
	}

	static TogglePluginForProfile(profile, pluginName, &enabled) {
		enabled := false

		if !this.Enabled || !profile
			return false
		if !this.IsPluginAvailableForProfile(profile, pluginName)
			return false

		enabled := !this.IsPluginRuntimeEnabledForProfile(profile, pluginName)
		runtimeMap := this.GetRuntimePluginMap(profile, true)
		runtimeMap[pluginName] := enabled
		return true
	}

	static GetProfileForProcess(processName) {
		profile := this.FindProfile(processName)
		return profile ? profile : this.DefaultProfile
	}

	static FindProfile(processName) {
		if processName = ""
			return 0

		normalized := StrLower(processName)
		if !this.ProcessProfiles.Has(normalized)
			return 0

		return this.ProcessProfiles[normalized]
	}

	static ProfileHasPluginSetting(profile, pluginName, &enabled) {
		plugins := 0
		try plugins := profile.Plugins
		catch
			return false

		if !plugins.Has(pluginName)
			return false

		enabled := !!plugins[pluginName]
		return true
	}

	static GetRuntimePluginMap(profile, create) {
		profileKey := this.GetProfileKey(profile)
		if profileKey = ""
			return 0

		if !this.RuntimePluginStates.Has(profileKey) {
			if !create
				return 0
			this.RuntimePluginStates[profileKey] := Map()
		}

		return this.RuntimePluginStates[profileKey]
	}

	static GetProfileKey(profile) {
		if !profile
			return ""

		return StrLower(Trim(this.GetProfileName(profile)))
	}

	static IsProfileEnabled(profile) {
		try return !!profile.Enabled
		catch
			return true
	}

	static GetProfileName(profile) {
		if !profile
			return ""

		try return profile.Name
		catch
			return "Unnamed"
	}

	static ValidateSelectionMode(mode) {
		switch mode {
			case "HoverThenFocus", "FocusThenHover", "HoverOnly", "FocusOnly":
				return
			default:
				throw Error(
					"Unknown SmartProfileManager selection mode '" mode "'. "
					"Use HoverThenFocus, FocusThenHover, HoverOnly, or FocusOnly."
				)
		}
	}
}
