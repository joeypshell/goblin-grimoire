extends SceneTree

const Music = preload("res://scripts/music_director.gd")
const Preferences = preload("res://scripts/ui_preferences.gd")

var checks := 0
var failures: Array[String] = []
var profile_root := ""
var fixtures: Array[Node] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/music_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(profile_root)
	print("Music director verification; isolated profile: ", profile_root)
	test_continuity_and_crossfade()
	test_mute_and_background()
	test_gesture_gate()
	test_preferences()
	test_missing_and_single_tracks()
	for fixture in fixtures:
		for player in fixture._players:
			player.stop()
		fixture.free()
	fixtures.clear()
	await process_frame
	await process_frame
	# AudioServer retires stopped playback references on its next mix callback.
	await create_timer(0.15).timeout
	print("RESULT: %d music checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func wave() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 8000
	var bytes := PackedByteArray()
	bytes.resize(160000)
	stream.data = bytes
	return stream

func fixture(name: String, gesture: bool = false, tracks: Dictionary = {}):
	var prefix: String = profile_root + name + "/"
	DirAccess.make_dir_recursive_absolute(prefix)
	var director = Music.new()
	director._requires_gesture = gesture
	director.setup(prefix, {"dungeon": wave(), "battle": wave()} if tracks.is_empty() else tracks)
	root.add_child(director)
	director.set_process(false)
	director._set_backgrounded(false)
	fixtures.append(director)
	return director

func test_continuity_and_crossfade() -> void:
	var director = fixture("continuity")
	check(director._players.size() == 2 and director.get_child_count() == 2, "Exactly two persistent music players are created")
	check(director._current_key == "dungeon" and director._players[0].playing and not director._players[1].playing, "Native title starts only the dungeon music deck")
	director._process(Music.FADE_SECONDS)
	check(director._gains.is_equal_approx(Vector2(1, 0)), "Initial music fades to the chosen track")
	var dungeon_playback = director._players[0].get_stream_playback()
	for context in ["dungeon", "reward", "preparation", "victory", "title"]:
		director.set_context(context)
		check(director._players[0].get_stream_playback() == dungeon_playback and director._fade_elapsed == Music.FADE_SECONDS, "Same music continues across screen refresh: " + context)
	director.set_context("battle")
	check(director._gains.is_equal_approx(Vector2(1, 0)) and director._players[0].playing and director._players[1].playing, "Battle starts the second deck silently while the previous deck continues")
	var raid_playback = director._players[1].get_stream_playback()
	director._process(Music.FADE_SECONDS * 0.5)
	check(is_equal_approx(director._gains.length_squared(), 1.0) and is_equal_approx(director._gains.x, sqrt(0.5)) and is_equal_approx(director._gains.y, sqrt(0.5)), "Midpoint crossfade preserves equal power")
	for ignored_card_refresh in range(10):
		director.set_context("battle")
	check(director._players[1].get_stream_playback() == raid_playback and is_equal_approx(director._fade_elapsed, Music.FADE_SECONDS * 0.5), "Card plays and repeated context updates do not restart the track or fade")
	var gains_before: Vector2 = director._gains
	director.set_context("dungeon")
	check(director._gains.is_equal_approx(gains_before) and director._players[0].get_stream_playback() == dungeon_playback, "An immediate phase reversal preserves current gain and existing playback")
	director._process(Music.FADE_SECONDS * 0.5)
	check(is_equal_approx(director._gains.length_squared(), 1.0), "Reversing a partial fade preserves equal power")
	director._process(Music.FADE_SECONDS)
	check(director._gains.is_equal_approx(Vector2(1, 0)) and director._players[0].playing and not director._players[1].playing, "Completed crossfade stops only the inaudible deck")
	director.set_context("battle", true)
	director._process(Music.FADE_SECONDS)
	check(director._context_gain == 1.1 and director._players[1].pitch_scale == 1.0, "Boss context raises presence without changing music pitch")
	director.set_context("defeat")
	director._process(Music.FADE_SECONDS)
	check(director._context_gain == 0.65 and director._current_key == "dungeon", "Defeat smoothly returns to quieter dungeon music")
	for player in director._players:
		check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end == 80000, "Each test stream is configured to loop the complete sample")
		check(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Long music tracks use the director's explicit stream playback mode")

func test_mute_and_background() -> void:
	var director = fixture("pause")
	director._process(Music.FADE_SECONDS)
	var playback = director._players[0].get_stream_playback()
	director.set_enabled(false)
	check(not director.enabled and director.volume == 0.45 and director._players[0].stream_paused, "Mute pauses music and remembers its selected level")
	director.set_volume(0.7)
	check(not director.enabled and director.volume == 0.7 and director._players[0].stream_paused, "Adjusting the slider while muted preserves mute")
	director.set_enabled(true)
	check(not director._players[0].stream_paused and director._players[0].get_stream_playback() == playback, "Unmute resumes the same playback without a restart")
	director.set_volume(0)
	check(director._players[0].stream_paused and director._players[0].volume_db == Music.SILENT_DB, "Zero volume is silent and pauses decoder work")
	director.set_volume(0.45)
	check(not director._players[0].stream_paused and director._players[0].get_stream_playback() == playback, "Raising volume resumes existing playback")
	director.set_context("battle")
	director._process(0.3)
	var before: Vector2 = director._gains
	var elapsed: float = director._fade_elapsed
	director._set_backgrounded(true)
	director._process(20)
	check(director._players.all(func(player): return player.stream_paused) and director._gains.is_equal_approx(before) and director._fade_elapsed == elapsed, "Hidden tabs pause both tracks and freeze the in-progress fade")
	director.unlock()
	check(director._players.all(func(player): return player.stream_paused), "A gesture cannot override background pause")
	director._set_backgrounded(false)
	check(director._players.all(func(player): return not player.stream_paused), "Returning to the visible app resumes both sides of the same fade")
	director._process(Music.FADE_SECONDS)
	check(director._current_key == "battle" and not director._players[0].playing and director._players[1].playing, "Resumed fade reaches its original destination")
	if not OS.has_feature("web"):
		director._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(director._backgrounded and director._players[1].stream_paused, "Native app focus loss pauses the music")
		director._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		check(not director._backgrounded and not director._players[1].stream_paused, "Native focus return resumes music")
	check(not FileAccess.file_exists(director._prefix + "ui_preferences.cfg"), "Non-persisted presentation changes create no profile files")

func test_gesture_gate() -> void:
	var director = fixture("gesture", true)
	check(not director._unlocked and director._players.all(func(player): return not player.playing), "Browser policy starts with both music decks stopped")
	director.set_context("battle")
	director._process(20)
	check(director._current_key.is_empty() and director._players.all(func(player): return not player.playing), "Phase changes before a user gesture do not try to autoplay")
	director.unlock()
	check(director._unlocked and director._current_key == "battle" and director._players[0].playing, "First user gesture starts the latest desired phase")
	director._process(Music.FADE_SECONDS)
	var playback = director._players[0].get_stream_playback()
	director.unlock()
	check(director._players[0].get_stream_playback() == playback, "Later gestures preserve continuous playback")

func test_preferences() -> void:
	var director = fixture("preferences")
	var preferences := ConfigFile.new()
	preferences.set_value("accessibility", "reduced_motion", true)
	preferences.set_value("presentation", "fast_combat", false)
	preferences.save(director._prefix + "ui_preferences.cfg")
	director.set_volume(0.31, true)
	director.set_enabled(false, true)
	preferences.load(director._prefix + "ui_preferences.cfg")
	check(preferences.get_value("accessibility", "reduced_motion") and not preferences.get_value("presentation", "fast_combat"), "Audio preference saves preserve existing accessibility and pacing settings")
	var restart = fixture("preferences")
	check(is_equal_approx(restart.volume, 0.31) and not restart.enabled and restart._players[0].stream_paused, "Restart loads the selected music level and mute choice")
	restart.set_volume(2)
	check(restart.volume == 1, "Volume above the slider range is clamped")
	restart.set_volume(-1)
	check(restart.volume == 0, "Volume below the slider range is clamped")
	restart.set_volume(NAN)
	check(restart.volume == 0.45, "Invalid numeric volume uses the default instead of entering the audio mixer")
	check(is_equal_approx(Preferences.read_music_volume(director._prefix), 0.31) and not Preferences.read_music_enabled(director._prefix), "Unsaved adjustments leave persisted music choices untouched")

func test_missing_and_single_tracks() -> void:
	var empty = fixture("missing", false, {"dungeon": null, "battle": null})
	empty.set_context("battle")
	empty.unlock()
	empty._process(10)
	check(empty._current_key.is_empty() and empty._players.all(func(player): return not player.playing), "Missing assets keep the game usable and silent")
	var original := wave()
	var single = fixture("single", false, {"dungeon": original})
	single._process(Music.FADE_SECONDS)
	var playback = single._players[0].get_stream_playback()
	single.set_context("battle")
	check(single._current_key == "dungeon" and single._players[0].get_stream_playback() == playback, "A single available track continues when another phase asset is missing")
	check(original.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Loop preparation does not mutate shared source resources")
