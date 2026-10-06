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

static func read_music_volume(prefix: String) -> float:
	var preferences = ConfigFile.new()
	if preferences.load(prefix + "ui_preferences.cfg") == OK:
		var value: float = float(preferences.get_value("audio", "music_volume", 0.45))
		return clampf(value, 0.0, 1.0) if is_finite(value) else 0.45
	return 0.45

static func save_music_volume(prefix: String, value: float) -> void:
	var preferences = ConfigFile.new()
	preferences.load(prefix + "ui_preferences.cfg")
	preferences.set_value("audio", "music_volume", clampf(value, 0.0, 1.0) if is_finite(value) else 0.45)
	preferences.save(prefix + "ui_preferences.cfg")

static func read_music_enabled(prefix: String) -> bool:
	var preferences = ConfigFile.new()
	if preferences.load(prefix + "ui_preferences.cfg") == OK:
		return bool(preferences.get_value("audio", "music_enabled", true))
	return true

static func save_music_enabled(prefix: String, value: bool) -> void:
	var preferences = ConfigFile.new()
	preferences.load(prefix + "ui_preferences.cfg")
	preferences.set_value("audio", "music_enabled", value)
	preferences.save(prefix + "ui_preferences.cfg")
