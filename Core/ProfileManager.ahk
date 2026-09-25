; SmartKeyPressOSD - application-specific plugin profiles
; Profiles select plugin sets according to the focused and/or hovered window context.

class SmartProfileManager {
	static SelectionMode := "HoverThenFocus"

	static Profiles := []
	static ProcessProfiles := Map()
	static WindowProfiles := Map()
	static RuntimePluginStates := Map()
	static DefaultProfile := 0
	static ActiveProfile := 0

	static Register(profile, isDefault := false) {
		this.Profiles.Push(profile)

		if isDefault {
			if this.DefaultProfile
				throw Error("Only one SmartKeyPressOSD default profile may be registered.")
			this.DefaultProfile := profile
		}
	}

	static Init(registeredPluginNames) {
		this.ProcessProfiles.Clear()
		this.WindowProfiles.Clear()
		this.RuntimePluginStates.Clear()
		this.ValidateSelectionMode(this.SelectionMode)
		this.ValidatePluginConfiguration(registeredPluginNames)

		profileNames := Map()

		for profile in this.Profiles {
			profileKey := this.GetProfileKey(profile)
			if profileKey = ""
				throw Error("SmartKeyPressOSD profile names must not be empty.")
			if profileNames.Has(profileKey)
				throw Error("Duplicate SmartKeyPressOSD profile name '" this.GetProfileName(profile) "'.")
			profileNames[profileKey] := true

			if profile = this.DefaultProfile
				continue

			applications := this.GetApplicationMatchers(profile)
			profileEnabled := this.IsProfileEnabled(profile)

			for application in applications {
				matcher := this.NormalizeApplicationMatcher(application, profile)
				if !profileEnabled
					continue

				if matcher.Class = "" {
					if this.ProcessProfiles.Has(matcher.Process) {
						throw Error(
							"Duplicate SmartKeyPressOSD process profile mapping for '"
							matcher.Process "'."
						)
					}

					this.ProcessProfiles[matcher.Process] := profile
					continue
				}

				windowKey := this.GetWindowProfileKey(matcher.Process, matcher.Class)
				if this.WindowProfiles.Has(windowKey) {
					throw Error(
						"Duplicate SmartKeyPressOSD window profile mapping for '"
						matcher.Process "' / '" matcher.Class "'."
					)
				}

				this.WindowProfiles[windowKey] := profile
			}
		}

		this.ActiveProfile := this.DefaultProfile
	}

	static Update(state) {
		profile := 0
		processName := ""
		className := ""

		switch this.SelectionMode {
			case "HoverThenFocus":
				if state.HoverProcess != "" {
					processName := state.HoverProcess
					className := state.HoverClass
					profile := this.FindProfile(processName, className)
				} else if state.ActiveProcess != "" {
					processName := state.ActiveProcess
					className := state.ActiveClass
					profile := this.FindProfile(processName, className)
				}
			case "FocusThenHover":
				if state.ActiveProcess != "" {
					processName := state.ActiveProcess
					className := state.ActiveClass
					profile := this.FindProfile(processName, className)
				} else if state.HoverProcess != "" {
					processName := state.HoverProcess
					className := state.HoverClass
					profile := this.FindProfile(processName, className)
				}
			case "HoverOnly":
				processName := state.HoverProcess
				className := state.HoverClass
				profile := this.FindProfile(processName, className)
			case "FocusOnly":
				processName := state.ActiveProcess
				className := state.ActiveClass
				profile := this.FindProfile(processName, className)
		}

		; The selected window context always owns the profile decision. If it has
		; no application-specific mapping, use the Default profile rather than
		; falling back to a mapped application in the secondary context.
		if !profile
			profile := this.DefaultProfile

		this.ActiveProfile := profile
		state.ProfileProcess := processName
	}

	static IsPluginAvailable(pluginName) {
		return this.IsPluginAvailableForProfile(this.ActiveProfile, pluginName)
	}

	static IsPluginConfiguredAnywhere(pluginName) {
		for profile in this.Profiles {
			if profile != this.DefaultProfile && !this.IsProfileEnabled(profile)
				continue
			if this.IsPluginAvailableForProfile(profile, pluginName)
				return true
		}

		return false
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

		; Missing settings fail closed. Init() also requires every registered
		; plugin to have an explicit entry in the Default profile.
		return false
	}

	static IsPluginRuntimeEnabled(pluginName) {
		return this.IsPluginRuntimeEnabledForProfile(this.ActiveProfile, pluginName)
	}

	static IsPluginRuntimeEnabledForProfile(profile, pluginName) {
		if !profile
			return false

		runtimeMap := this.GetRuntimePluginMap(profile, false)
		if !runtimeMap || !runtimeMap.Has(pluginName)
			return true

		return !!runtimeMap[pluginName]
	}

	static TogglePluginForProfile(profile, pluginName, &enabled) {
		enabled := false

		if !profile
			return false
		if !this.IsPluginAvailableForProfile(profile, pluginName)
			return false

		enabled := !this.IsPluginRuntimeEnabledForProfile(profile, pluginName)
		runtimeMap := this.GetRuntimePluginMap(profile, true)
		runtimeMap[pluginName] := enabled
		return true
	}

	static GetProfileForWindow(processName, className := "") {
		profile := this.FindProfile(processName, className)
		return profile ? profile : this.DefaultProfile
	}

	static FindProfile(processName, className := "") {
		normalizedProcess := this.NormalizeProcessName(processName)
		if normalizedProcess = ""
			return 0

		normalizedClass := this.NormalizeClassName(className)
		if normalizedClass != "" {
			windowKey := this.GetWindowProfileKey(normalizedProcess, normalizedClass)
			if this.WindowProfiles.Has(windowKey)
				return this.WindowProfiles[windowKey]
		}

		if this.ProcessProfiles.Has(normalizedProcess)
			return this.ProcessProfiles[normalizedProcess]

		return 0
	}

	static ContextMatchesSelectedApplication(processName, className, state) {
		if processName = "" || state.ProfileProcess = ""
			return false
		if this.NormalizeProcessName(processName) != this.NormalizeProcessName(state.ProfileProcess)
			return false

		return this.GetProfileForWindow(processName, className) = this.ActiveProfile
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

	static ValidatePluginConfiguration(registeredPluginNames) {
		if !this.DefaultProfile
			throw Error("SmartKeyPressOSD requires one Default profile.")

		defaultPlugins := this.GetPluginSettings(this.DefaultProfile, true)

		for pluginName in registeredPluginNames {
			if !defaultPlugins.Has(pluginName) {
				throw Error(
					"Default profile has no setting for registered plugin '"
					pluginName "'."
				)
			}
		}

		; The Default profile is the canonical plugin-name list. Application
		; profiles may omit entries to inherit defaults, but may not introduce
		; unknown names. Default entries for an optional plugin are harmless when
		; that plugin file is absent.
		for profile in this.Profiles {
			if profile = this.DefaultProfile
				continue

			plugins := this.GetPluginSettings(profile, false)
			for pluginName, unused in plugins {
				if !defaultPlugins.Has(pluginName) {
					throw Error(
						"Unknown plugin '" pluginName "' in profile '"
						this.GetProfileName(profile) "'."
					)
				}
			}
		}
	}

	static GetPluginSettings(profile, required) {
		plugins := 0
		try plugins := profile.Plugins
		catch {
			if required
				throw Error("Default profile must define a Plugins map.")
			return Map()
		}

		if Type(plugins) != "Map" {
			throw Error(
				"Profile '" this.GetProfileName(profile) "' must define Plugins as a Map."
			)
		}

		return plugins
	}

	static GetApplicationMatchers(profile) {
		applications := []
		try applications := profile.Applications
		catch
			return []

		if Type(applications) != "Array" {
			throw Error(
				"Profile '" this.GetProfileName(profile) "' must define Applications as an Array."
			)
		}

		return applications
	}

	static NormalizeApplicationMatcher(application, profile) {
		applicationType := Type(application)

		if applicationType = "String" {
			processName := this.NormalizeProcessName(application)
			if processName = "" {
				throw Error(
					"Profile '" this.GetProfileName(profile)
					"' contains an empty application process name."
				)
			}

			return {Process: processName, Class: ""}
		}

		if applicationType != "Map" {
			throw Error(
				"Profile '" this.GetProfileName(profile)
				"' application entries must be process-name strings or Maps."
			)
		}

		if !application.Has("Process") {
			throw Error(
				"Profile '" this.GetProfileName(profile)
				"' application Map is missing the Process entry."
			)
		}

		processName := this.NormalizeProcessName(application["Process"])
		if processName = "" {
			throw Error(
				"Profile '" this.GetProfileName(profile)
				"' contains an empty application process name."
			)
		}

		className := ""
		if application.Has("Class") {
			className := this.NormalizeClassName(application["Class"])
			if className = "" {
				throw Error(
					"Profile '" this.GetProfileName(profile)
					"' contains an empty application window class."
				)
			}
		}

		return {Process: processName, Class: className}
	}

	static NormalizeProcessName(processName) {
		return StrLower(Trim(processName))
	}

	static NormalizeClassName(className) {
		return StrLower(Trim(className))
	}

	static GetWindowProfileKey(processName, className) {
		return this.NormalizeProcessName(processName) "|" this.NormalizeClassName(className)
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
