extends RefCounted

# Presentation preferences never touch the run, discoveries or combat RNG.
static func read_motion(prefix: String) -> bool:
	var preferences = ConfigFile.new()
	if preferences.load(prefix + "ui_preferences.cfg") == OK:
		return bool(preferences.get_value("accessibility", "reduced_motion", false))
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
	return false

static func save_motion(prefix: String, value: bool) -> void:
	var preferences = ConfigFile.new()
	preferences.load(prefix + "ui_preferences.cfg")
	preferences.set_value("accessibility", "reduced_motion", value)
	preferences.save(prefix + "ui_preferences.cfg")

static func read_fast_combat(prefix: String) -> bool:
	var preferences = ConfigFile.new()
	if preferences.load(prefix + "ui_preferences.cfg") == OK:
		return bool(preferences.get_value("presentation", "fast_combat", true))
	return true

static func save_fast_combat(prefix: String, value: bool) -> void:
	var preferences = ConfigFile.new()
	preferences.load(prefix + "ui_preferences.cfg")
	preferences.set_value("presentation", "fast_combat", value)
	preferences.save(prefix + "ui_preferences.cfg")
