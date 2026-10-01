; SmartInputVisuals - application-specific plugin profiles
; Profiles select plugin states according to the focused and/or hovered window context.
;
; The Default profile owns canonical PluginDefinition objects and the complete
; baseline PluginStates Map. Application profiles use the same PluginStates shape
; for optional true/false overrides and cannot redefine plugin metadata.

class SmartProfileManager {
	static SelectionMode := "HoverThenFocus"

	static Profiles := []
	static ProcessProfiles := Map()
	static WindowProfiles := Map()
	static RuntimePluginStates := Map()
	static RegisteredPlugins := Map()
	static DefaultProfile := 0
	static ActiveProfile := 0

	static Register(profile, isDefault := false) {
		this.Profiles.Push(profile)

		if isDefault {
			if this.DefaultProfile
				throw Error("Only one SmartInputVisuals default profile may be registered.")
			this.DefaultProfile := profile
		}
	}

	static GetPluginDefinition(pluginName) {
		if !this.DefaultProfile
			return 0

		definitions := 0
		try definitions := this.DefaultProfile.PluginDefinitions
		catch
			return 0

		if Type(definitions) != "Map"
			return 0

		if definitions.Has(pluginName)
			return definitions[pluginName]

		; Plugin names are intended to be stable and exact, but resolve
		; case-insensitively here so registration and lookup remain robust.
		key := StrLower(Trim(pluginName))
		for definitionName, definition in definitions {
			if StrLower(Trim(definitionName)) = key
				return definition
		}

		return 0
	}

	static Init(registeredPluginNames) {
		this.ProcessProfiles.Clear()
		this.WindowProfiles.Clear()
		this.RuntimePluginStates.Clear()
		this.RegisteredPlugins.Clear()
		for pluginName in registeredPluginNames
			this.RegisteredPlugins[StrLower(Trim(pluginName))] := true

		this.ValidateSelectionMode(this.SelectionMode)
		this.ValidatePluginConfiguration(registeredPluginNames)

		profileNames := Map()

		for profile in this.Profiles {
			profileKey := this.GetProfileKey(profile)
			if profileKey = ""
				throw Error("SmartInputVisuals profile names must not be empty.")
			if profileNames.Has(profileKey)
				throw Error("Duplicate SmartInputVisuals profile name '" this.GetProfileName(profile) "'.")
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
							"Duplicate SmartInputVisuals process profile mapping for '"
							matcher.Process "'."
						)
					}

					this.ProcessProfiles[matcher.Process] := profile
					continue
				}

				windowKey := this.GetWindowProfileKey(matcher.Process, matcher.Class)
				if this.WindowProfiles.Has(windowKey) {
					throw Error(
						"Duplicate SmartInputVisuals window profile mapping for '"
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

	static IsPluginRegistered(pluginName) {
		return this.RegisteredPlugins.Has(StrLower(Trim(pluginName)))
	}

	static IsPluginEnabled(pluginName) {
		return this.IsPluginEnabledForProfile(this.ActiveProfile, pluginName)
	}

	static IsPluginEnabledForProfile(profile, pluginName) {
		if !profile || !this.IsPluginRegistered(pluginName)
			return false

		runtimeMap := this.GetRuntimePluginMap(profile, false)
		if runtimeMap && runtimeMap.Has(pluginName)
			return !!runtimeMap[pluginName]

		return this.GetConfiguredPluginStateForProfile(profile, pluginName)
	}

	static GetConfiguredPluginStateForProfile(profile, pluginName) {
		if !profile
			return false

		if profile != this.DefaultProfile {
			enabled := false
			if this.ProfileHasPluginState(profile, pluginName, &enabled)
				return enabled
		}

		defaultStates := this.GetPluginStates(this.DefaultProfile, true)
		return defaultStates.Has(pluginName) ? !!defaultStates[pluginName] : false
	}

	static HasRuntimePluginState(pluginName) {
		return this.HasRuntimePluginStateForProfile(this.ActiveProfile, pluginName)
	}

	static HasRuntimePluginStateForProfile(profile, pluginName) {
		if !profile
			return false

		runtimeMap := this.GetRuntimePluginMap(profile, false)
		return !!(runtimeMap && runtimeMap.Has(pluginName))
	}

	static TogglePluginForProfile(profile, pluginName, &enabled) {
		enabled := false

		if !profile || !this.IsPluginRegistered(pluginName)
			return false

		enabled := !this.IsPluginEnabledForProfile(profile, pluginName)
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

	static ProfileHasPluginState(profile, pluginName, &enabled) {
		states := 0
		try states := profile.PluginStates
		catch
			return false

		if !states.Has(pluginName)
			return false

		enabled := !!states[pluginName]
		return true
	}

	static GetPluginDisplayName(pluginName) {
		definition := this.GetPluginDefinition(pluginName)
		return definition && definition.DisplayName != "" ? definition.DisplayName : Trim(pluginName)
	}

	static ValidatePluginConfiguration(registeredPluginNames) {
		if !this.DefaultProfile
			throw Error("SmartInputVisuals requires one Default profile.")

		definitions := this.GetPluginDefinitions(true)
		displayNames := Map()

		for pluginName, definition in definitions {
			if Trim(pluginName) = ""
				throw Error("PluginDefinitions Map keys must not be empty.")

			if Type(definition) != "PluginDefinition" {
				throw Error(
					"Plugin '" pluginName "' in the Default profile must be a "
					"PluginDefinition."
				)
			}


			effectiveDisplayName := definition.DisplayName != "" ? definition.DisplayName : pluginName
			displayKey := StrLower(effectiveDisplayName)
			if displayNames.Has(displayKey) {
				throw Error(
					"Duplicate SmartInputVisuals plugin display name '"
					effectiveDisplayName "'."
				)
			}
			displayNames[displayKey] := pluginName
		}

		for pluginName in registeredPluginNames {
			if !definitions.Has(pluginName) {
				throw Error(
					"Default profile has no definition for registered plugin '"
					pluginName "'."
				)
			}
		}

		; Default.PluginStates is the complete baseline. Application profiles use
		; the same structure but may omit plugins to inherit that baseline.
		defaultStates := this.GetPluginStates(this.DefaultProfile, true)

		for pluginName in definitions {
			if !defaultStates.Has(pluginName) {
				throw Error(
					"Default profile PluginStates has no state for plugin '"
					pluginName "'."
				)
			}
		}

		for pluginName in defaultStates {
			if !definitions.Has(pluginName) {
				throw Error(
					"Unknown plugin '" pluginName "' in Default PluginStates."
				)
			}
		}

		for profile in this.Profiles {
			states := this.GetPluginStates(profile, profile = this.DefaultProfile)
			for pluginName, setting in states {
				if !definitions.Has(pluginName) {
					throw Error(
						"Unknown plugin '" pluginName "' in profile '"
						this.GetProfileName(profile) "'."
					)
				}

				if Type(setting) != "Integer" || (setting != 0 && setting != 1) {
					throw Error(
						"Plugin state '" pluginName "' in profile '"
						this.GetProfileName(profile) "' must be true or false."
					)
				}
			}
		}
	}

	static GetPluginDefinitions(required := false) {
		definitions := 0
		try definitions := this.DefaultProfile.PluginDefinitions
		catch {
			if required
				throw Error("Default profile must define a PluginDefinitions map.")
			return Map()
		}

		if Type(definitions) != "Map"
			throw Error("Default profile must define PluginDefinitions as a Map.")

		return definitions
	}

	static GetPluginStates(profile, required := false) {
		states := 0
		try states := profile.PluginStates
		catch {
			if required {
				throw Error(
					"Profile '" this.GetProfileName(profile)
					"' must define a PluginStates Map."
				)
			}
			return Map()
		}

		if Type(states) != "Map" {
			throw Error(
				"Profile '" this.GetProfileName(profile)
				"' must define PluginStates as a Map."
			)
		}

		return states
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
