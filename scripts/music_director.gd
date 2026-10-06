extends Node

# One director survives screen rebuilds; music is presentation-only.
const Preferences = preload("res://scripts/ui_preferences.gd")
const FADE_SECONDS := 1.5
const SILENT_DB := -80.0
const TRACK_PATHS := {
	"dungeon": "res://assets/audio/dungeon_theme",
	"battle": "res://assets/audio/raid_theme",
}

var volume := 0.45
var enabled := true
var _prefix := ""
var _tracks: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _keys: Array[String] = ["", ""]
var _requested_key := "dungeon"
var _current_key := ""
var _target_slot := -1
var _context_gain := 1.0
var _gains := Vector2.ZERO
var _fade_from := Vector2.ZERO
var _fade_to := Vector2.ZERO
var _fade_elapsed := FADE_SECONDS
var _requires_gesture := OS.has_feature("web")
var _unlocked := not OS.has_feature("web")
var _backgrounded := false
var _document
var _visibility_callback

func setup(prefix: String, streams: Dictionary = {}) -> void:
	_prefix = prefix
	volume = Preferences.read_music_volume(prefix)
	enabled = Preferences.read_music_enabled(prefix)
	_unlocked = not _requires_gesture
	for key in TRACK_PATHS:
		var source: AudioStream = streams.get(key) as AudioStream
		if source == null and streams.is_empty():
			for extension in [".ogg", ".mp3", ".wav"]:
				var path: String = TRACK_PATHS[key] + extension
				if ResourceLoader.exists(path):
					source = load(path) as AudioStream
					break
		if source != null:
			_tracks[key] = _looped_copy(source)
	if is_inside_tree():
		_ensure_desired_track()
		_apply_levels()
		_apply_pause()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_players()
	if OS.has_feature("web"):
		_document = JavaScriptBridge.get_interface("document")
		_visibility_callback = JavaScriptBridge.create_callback(_on_visibility_changed)
		_document.addEventListener("visibilitychange", _visibility_callback)
		_on_visibility_changed([])
	_ensure_desired_track()
	_apply_pause()

func _exit_tree() -> void:
	for player in _players:
		player.stop()
	if _document != null and _visibility_callback != null:
		_document.removeEventListener("visibilitychange", _visibility_callback)
	_visibility_callback = null
	_document = null

func set_context(context: String, boss: bool = false) -> void:
	_requested_key = "battle" if context == "battle" else "dungeon"
	_context_gain = 1.1 if context == "battle" and boss else 0.65 if context == "defeat" else 1.0
	_ensure_desired_track()
	_apply_levels()

func set_volume(value: float, persist: bool = false) -> void:
	volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.45
	if persist:
		Preferences.save_music_volume(_prefix, volume)
	_ensure_desired_track()
	_apply_levels()
	_apply_pause()

func set_enabled(value: bool, persist: bool = false) -> void:
	enabled = value
	if persist:
		Preferences.save_music_enabled(_prefix, enabled)
	_ensure_desired_track()
	_apply_levels()
	_apply_pause()

# Main calls this directly from a pressed keyboard, mouse or touch event.
func unlock() -> void:
	_unlocked = true
	_ensure_desired_track()
	_apply_pause()

func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicDeck%d" % index
		player.volume_db = SILENT_DB
		# Keep long music tracks streamed on the single-thread web build.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)

func _ensure_desired_track() -> void:
	if not is_inside_tree() or not _unlocked:
		return
	_ensure_players()
	var key: String = _requested_key
	if not _tracks.has(key):
		key = "dungeon" if _tracks.has("dungeon") else "battle" if _tracks.has("battle") else ""
	if key.is_empty() or key == _current_key:
		return
	var slot: int = _keys.find(key)
	if slot == -1:
		slot = 0 if _target_slot == -1 else 1 - _target_slot
		_keys[slot] = key
		_players[slot].stream = _tracks[key]
		_players[slot].volume_db = SILENT_DB
	if not _players[slot].playing:
		_players[slot].play()
	_current_key = key
	_target_slot = slot
	_fade_from = _gains
	_fade_to = Vector2(1.0, 0.0) if slot == 0 else Vector2(0.0, 1.0)
	_fade_elapsed = 0.0
	_apply_pause()

func _process(delta: float) -> void:
	if _backgrounded or not _unlocked or not enabled or volume <= 0.0:
		return
	if _fade_elapsed >= FADE_SECONDS:
		return
	_fade_elapsed = minf(FADE_SECONDS, _fade_elapsed + maxf(delta, 0.0))
	var progress: float = _fade_elapsed / FADE_SECONDS
	var start_angle: float = _fade_from.angle() if _fade_from.length_squared() > 0.0 else _fade_to.angle()
	var angle: float = lerpf(start_angle, _fade_to.angle(), progress)
	var radius: float = lerpf(_fade_from.length(), 1.0, sin(progress * PI * 0.5))
	_gains = Vector2(cos(angle), sin(angle)) * radius
	if _fade_elapsed >= FADE_SECONDS:
		_gains = _fade_to
		for index in range(2):
			if index != _target_slot:
				_players[index].stop()
	_apply_levels()

func _apply_levels() -> void:
	for index in range(_players.size()):
		var gain: float = _gains[index] * volume * _context_gain if enabled else 0.0
		_players[index].volume_db = linear_to_db(gain) if gain > 0.0001 else SILENT_DB

func _apply_pause() -> void:
	var paused: bool = _backgrounded or not _unlocked or not enabled or volume <= 0.0
	for player in _players:
		player.stream_paused = paused

func _set_backgrounded(value: bool) -> void:
	_backgrounded = value
	_apply_pause()

func _on_visibility_changed(_arguments: Array) -> void:
	if _document != null:
		_set_backgrounded(bool(_document.hidden))

func _notification(what: int) -> void:
	if OS.has_feature("web"):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_set_backgrounded(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_set_backgrounded(false)

func _looped_copy(source: AudioStream) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
		stream.loop_offset = 0.0
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var bytes_per_frame: int = (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if stream.stereo else 1)
		stream.loop_end = stream.data.size() / bytes_per_frame
	return stream
