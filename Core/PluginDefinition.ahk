; SmartInputVisuals - canonical plugin metadata
;
; The PluginDefinitions Map is the explicit availability whitelist. Its key is
; the sole canonical/internal plugin name. PluginDefinition intentionally contains
; only metadata that is not already represented by that key.

class PluginDefinition {
	__New(displayName) {
		this.DisplayName := Trim(displayName)
	}
}
