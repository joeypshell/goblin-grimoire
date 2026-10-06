extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Preferences = preload("res://scripts/ui_preferences.gd")
const SIZES = [Vector2i(1280, 720), Vector2i(375, 667), Vector2i(390, 844), Vector2i(844, 320)]

var ui
var game
var surface: SubViewport
var pixels := Vector2i(1280, 720)
var profile_root: String
var checks := 0
var captures := 0
var failures: Array = []
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/audio_ui_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/audio_ui/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	test_preferences()
	surface = SubViewport.new()
	surface.size = pixels
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		await test_controls()
	if can_render: await test_native_touch()
	print("AUDIO UI SMOKE: %d assertions; %d %s; %d issues" % [checks, captures, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("AUDIO UI ISSUE: ", failure)
	if is_instance_valid(ui): ui.free()
	surface.free()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func equal(left, right) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func settle() -> void:
	for frame in range(8): await process_frame
	if can_render: await RenderingServer.frame_post_draw

func test_preferences() -> void:
	var prefix := profile_root + "preferences/"
	DirAccess.make_dir_recursive_absolute(prefix)
	check(is_equal_approx(Preferences.read_music_volume(prefix), 0.45) and Preferences.read_music_enabled(prefix), "Music defaults to enabled at forty-five percent")
	Preferences.save_motion(prefix, true)
	Preferences.save_fast_combat(prefix, false)
	check(is_equal_approx(Preferences.read_music_volume(prefix), 0.45) and Preferences.read_music_enabled(prefix), "Existing presentation-only preferences receive safe music defaults")
	Preferences.save_music_volume(prefix, 0.72)
	Preferences.save_music_enabled(prefix, false)
	check(Preferences.read_motion(prefix) and not Preferences.read_fast_combat(prefix), "Saving music preserves reduced motion and normal combat speed")
	check(is_equal_approx(Preferences.read_music_volume(prefix), 0.72) and not Preferences.read_music_enabled(prefix), "Mute and chosen volume are persisted independently")
	Preferences.save_motion(prefix, false)
	Preferences.save_fast_combat(prefix, true)
	check(is_equal_approx(Preferences.read_music_volume(prefix), 0.72) and not Preferences.read_music_enabled(prefix), "Saving presentation preferences preserves music choices")
	Preferences.save_music_volume(prefix, 2.0)
	check(is_equal_approx(Preferences.read_music_volume(prefix), 1.0), "Persisted music volume clamps to its maximum")
	Preferences.save_music_volume(prefix, -1.0)
	check(is_equal_approx(Preferences.read_music_volume(prefix), 0.0), "Persisted music volume clamps to silence")
	Preferences.save_music_volume(prefix, NAN)
	check(is_equal_approx(Preferences.read_music_volume(prefix), 0.45), "Invalid volume input restores the default rather than saving an unusable level")
	check(not FileAccess.file_exists(prefix + "run.json") and not FileAccess.file_exists(prefix + "grimoire.json") and not FileAccess.file_exists(prefix + "reports.json"), "Presentation preferences never create gameplay, discovery or report saves")

func instantiate_ui(prefix: String, native: bool = false) -> void:
	if is_instance_valid(ui): ui.free()
	game = State.new(prefix)
	ui = MainScene.instantiate()
	ui.state = game
	if native: root.add_child(ui)
	else: surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Main and report uploader start with an explicitly isolated verification profile")
	check(ui.audio != null and ui.audio_settings != null, "Production main initializes the soundtrack and its settings")
	check(ui.audio._tracks.has("dungeon") and ui.audio._tracks.has("battle"), "Production main loads both actual soundtrack assets")
	for stream in ui.audio._tracks.values():
		check(stream is AudioStreamOggVorbis and stream.loop, "Actual compressed soundtrack streams are configured for continuous looping")

func test_controls() -> void:
	var prefix := profile_root + "%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(prefix)
	Preferences.save_motion(prefix, true)
	Preferences.save_fast_combat(prefix, false)
	instantiate_ui(prefix)
	await settle()
	check(ui.reduced_motion and not ui.fast_combat, "Music initialization retains existing presentation preferences")
	await capture("01_title_sound_settings")
	var open = named(ui, "OpenSoundSettings")
	check(open is Button and not open.disabled, "Title exposes the production Sound settings action")
	await reachable(open)
	open.pressed.emit()
	await settle()
	var slider = named(ui, "MusicVolume")
	var toggle = named(ui, "ToggleMusic")
	check(slider is HSlider and slider.min_value == 0 and slider.max_value == 100 and slider.step == 1 and slider.size.y >= 43.9, "Music slider provides a zero-to-one-hundred range and a forty-four-pixel touch target")
	check(slider.value == 45 and named(ui, "MusicPercentage").text == "45%" and toggle.text == "Mute music", "Initial controls reflect the enabled default volume")
	var credits = named(ui, "MusicCredits")
	check(credits is Label and credits.text.contains("Darkest Child var A") and credits.text.contains("Kevin MacLeod") and credits.text.contains("incompetech.com") and credits.text.contains("CC BY 4.0") and credits.text.contains("edited"), "Sound settings show track names, composer, attribution, license and editing notice")
	await reachable(named(ui, "MusicSource"))
	await reachable(named(ui, "MusicLicense"))
	await capture("02_default_sound_dialog")
	slider.value = 72
	check(is_equal_approx(ui.audio.volume, 0.72) and is_equal_approx(Preferences.read_music_volume(prefix), 0.72) and named(ui, "MusicPercentage").text == "72%", "Production slider updates the director, label and saved volume immediately")
	toggle.pressed.emit()
	check(not ui.audio.enabled and not Preferences.read_music_enabled(prefix) and is_equal_approx(ui.audio.volume, 0.72) and toggle.text == "Restore music", "Mute silences music and preserves the volume for restoring")
	slider.value = 63
	check(not ui.audio.enabled and is_equal_approx(ui.audio.volume, 0.63) and named(ui, "MusicPercentage").text == "63% · muted", "Moving the slider while muted preserves mute and makes the new chosen volume clear")
	check(ui.reduced_motion and not ui.fast_combat and Preferences.read_motion(prefix) and not Preferences.read_fast_combat(prefix), "Sound controls preserve both existing presentation preferences")
	check(game.run.is_empty() and not FileAccess.file_exists(prefix + "run.json") and not FileAccess.file_exists(prefix + "grimoire.json"), "Title music controls do not start a run or create a discovery save")
	await capture("03_muted_chosen_volume")
	await reachable(named(ui, "CloseSoundSettings"))
	named(ui, "CloseSoundSettings").pressed.emit()
	await settle()
	instantiate_ui(prefix)
	await settle()
	check(is_equal_approx(ui.audio.volume, 0.63) and not ui.audio.enabled, "A fresh main scene restores saved volume and mute")
	named(ui, "OpenSoundSettings").pressed.emit()
	await settle()
	check(named(ui, "MusicVolume").value == 63 and named(ui, "ToggleMusic").text == "Restore music", "Reopened production controls reflect restored preferences")
	named(ui, "ToggleMusic").pressed.emit()
	check(ui.audio.enabled and Preferences.read_music_enabled(prefix) and is_equal_approx(ui.audio.volume, 0.63), "Restore music uses the last chosen volume")
	named(ui, "CloseSoundSettings").pressed.emit()
	await settle()
	game.new_run(730210)
	game.start_raid()
	ui.menu = "game"
	ui.refresh()
	await settle()
	var before: Dictionary = game.battle.to_dict()
	var run_before: Dictionary = game.run.duplicate(true)
	var profile_before: Dictionary = game.profile.duplicate(true)
	var rng_before: int = game.rng.state
	var saves_before: Dictionary = saved_files(prefix)
	var music_playback = ui.audio._players[ui.audio._target_slot].get_stream_playback() if ui.audio._target_slot >= 0 else null
	ui.open_grimoire()
	await settle()
	check(ui.menu == "grimoire" and ui.audio._requested_key == "battle" and ui.audio._players[ui.audio._target_slot].get_stream_playback() == music_playback, "Opening the Grimoire from a battle preserves the same active battle soundtrack")
	ui.menu = ui.grimoire_return
	ui.refresh()
	await settle()
	ui.combat_screen._show_log()
	await settle()
	await capture("04_combat_log_sound_entry")
	open = named(ui, "OpenSoundSettings")
	check(open is Button, "Combat Log & rules exposes Sound settings")
	await reachable(open)
	open.pressed.emit()
	await settle()
	check(named(ui, "SoundSettings") != null and named(ui, "CloseSoundSettings").text == "Return to log & rules", "Combat sound dialog offers a direct return to its log")
	await capture("05_combat_sound_dialog")
	slider = named(ui, "MusicVolume")
	slider.value = 0
	check(ui.audio.enabled and is_zero_approx(ui.audio.volume) and named(ui, "MusicPercentage").text == "0%", "Zero volume gives silence without losing the enabled preference")
	named(ui, "ToggleMusic").pressed.emit()
	slider.value = 35
	await reachable(named(ui, "CloseSoundSettings"))
	named(ui, "CloseSoundSettings").pressed.emit()
	await settle()
	check(named(ui, "FastCombat") != null and named(ui, "ReduceMotion") != null and named(ui, "OpenSoundSettings") != null, "Returning from Sound settings restores the original Log & rules controls")
	check(equal(before, game.battle.to_dict()) and equal(run_before, game.run) and equal(profile_before, game.profile) and game.rng.state == rng_before and equal(saves_before, saved_files(prefix)), "Opening, adjusting and closing music preserves battle, run, discoveries, gameplay RNG and all gameplay save files")
	check(music_playback != null and ui.audio._players[ui.audio._target_slot].get_stream_playback() == music_playback, "Adjusting volume and mute through the battle dialog preserves actual music playback position")
	await capture("06_return_to_combat_log")
	ui.close_modal()
	await settle()

func saved_files(prefix: String) -> Dictionary:
	var result: Dictionary = {}
	for name_ in ["run.json", "grimoire.json", "reports.json"]:
		var path: String = prefix + name_
		result[name_] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func named(node: Node, id: String):
	if node.is_queued_for_deletion(): return null
	if str(node.name) == id and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, id)
		if found != null: return found
	return null

func reachable(control: Control) -> void:
	check(is_instance_valid(control), "Requested sound control exists")
	if not is_instance_valid(control): return
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await settle()
			check(ancestor.get_global_rect().grow(1).encloses(control.get_global_rect()), "Sound control is reachable through its intentional scroll container: " + control.name)
		ancestor = ancestor.get_parent()
	check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(control.get_global_rect()), "Sound action can be fully reached inside the logical viewport: " + control.name)

func inspect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is BaseButton or node is Slider):
		var vertical := false
		var horizontal := false
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				vertical = vertical or ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				horizontal = horizontal or ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		if not horizontal: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Sound text and controls fit horizontal bounds: " + node.name)
		if not vertical: check(rect.position.y >= -1 and rect.end.y <= pixels.y + 1, "Unscrolled sound action fits vertical bounds: %s %s %s" % [node.name, node.text if node is Label or node is BaseButton else "", rect])
		if str(node.name) in ["OpenSoundSettings", "MusicVolume", "ToggleMusic", "MusicSource", "MusicLicense", "CloseSoundSettings"]:
			check(node.size.y >= 43.9 and node.size.x >= 43.9, "Sound action retains a forty-four-pixel touch target: " + node.name)
	for child in node.get_children(): inspect(child)

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var destination := "res://tests/artifacts/audio_ui/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(destination)
	if can_render:
		var picture = surface.get_texture().get_image()
		check(picture.get_size() == pixels and picture.save_png(destination + tag + ".png") == OK, "Native sound UI capture saves its exact logical size")
	else: check(surface.size == pixels, "Headless sound UI uses exact logical dimensions")
	captures += 1
	print("AUDIO UI CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.window_id = root.get_window_id()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func tap_native(control: Control) -> void:
	await reachable(control)
	var center: Vector2 = control.get_global_rect().get_center()
	await touch(center, true)
	await touch(center, false)
	await settle()

func test_native_touch() -> void:
	if is_instance_valid(ui): ui.free()
	pixels = Vector2i(390, 844)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = pixels
	instantiate_ui(profile_root + "native_touch/", true)
	await settle()
	await tap_native(named(ui, "OpenSoundSettings"))
	check(named(ui, "MusicVolume") != null, "Real ScreenTouch opens Sound settings through production mouse-from-touch emulation")
	var slider: HSlider = named(ui, "MusicVolume")
	if slider == null: return
	await reachable(slider)
	var bounds: Rect2 = slider.get_global_rect()
	var chosen: Vector2 = Vector2(bounds.position.x + bounds.size.x * 0.8, bounds.get_center().y)
	await touch(chosen, true)
	await touch(chosen, false)
	await settle()
	check(ui.audio.volume > 0.65 and is_equal_approx(ui.audio.volume, Preferences.read_music_volume(game._prefix)), "Real finger tap moves the music slider and saves its immediate volume")
	var before_volume: float = ui.audio.volume
	await touch(chosen, true)
	for index in range(1, 6):
		var drag := InputEventScreenDrag.new()
		drag.window_id = root.get_window_id()
		drag.index = 0
		drag.position = chosen - Vector2(index * bounds.size.x * 0.08, 0)
		drag.relative = Vector2(-bounds.size.x * 0.08, 0)
		Input.parse_input_event(drag)
		await process_frame
	await touch(chosen - Vector2(bounds.size.x * 0.4, 0), false)
	await settle()
	check(ui.audio.volume < before_volume - 0.2 and is_equal_approx(ui.audio.volume, Preferences.read_music_volume(game._prefix)), "Real horizontal finger drag adjusts music without being captured by vertical modal scrolling")
	await tap_native(named(ui, "ToggleMusic"))
	check(not ui.audio.enabled and not Preferences.read_music_enabled(game._prefix), "Real ScreenTouch mutes and persists music")
	await tap_native(named(ui, "ToggleMusic"))
	check(ui.audio.enabled and is_equal_approx(ui.audio.volume, Preferences.read_music_volume(game._prefix)), "Real ScreenTouch restores the selected volume")
	await tap_native(named(ui, "CloseSoundSettings"))
	check(named(ui, "SoundSettings") == null and ui.menu == "title", "Real ScreenTouch closes Sound settings without starting a run")
