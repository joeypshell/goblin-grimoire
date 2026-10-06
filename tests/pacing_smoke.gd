extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const CountingState = preload("res://tests/flow_state_fixture.gd")
const Preferences = preload("res://scripts/ui_preferences.gd")
const Replay = preload("res://scripts/battle_replay.gd")
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
	profile_root = "user://verification/pacing_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/pacing/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	test_preferences()
	surface = SubViewport.new()
	surface.size = pixels
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Scene and uploader start with an explicitly isolated profile")
	check(ui.fast_combat, "New scene defaults to Fast combat")
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		await test_controls()
	pixels = Vector2i(390, 844)
	surface.size = pixels
	var fast_result: Dictionary = await test_sequence(true)
	var normal_result: Dictionary = await test_sequence(false)
	check(equal(fast_result["battle"], normal_result["battle"]), "Fast and Normal end at identical battle state and RNG")
	check(fast_result["elapsed"] < normal_result["elapsed"] * 0.75, "Actual Fast playback completes substantially sooner than Normal")
	print("PACING TIMING: Fast %.3fs; Normal %.3fs" % [fast_result["elapsed"], normal_result["elapsed"]])
	await test_skip_and_reload(true)
	await test_skip_and_reload(false)
	if can_render: await test_native_toggle()
	print("PACING SMOKE: %d assertions; %d %s; %d issues" % [checks, captures, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("PACING ISSUE: ", failure)
	if is_instance_valid(ui): ui.free()
	surface.free()
	# AudioServer retires stopped music playback references on its next mix callback.
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
	check(Preferences.read_fast_combat(prefix), "Missing preference file defaults to Fast")
	Preferences.save_motion(prefix, true)
	check(Preferences.read_fast_combat(prefix) and Preferences.read_motion(prefix), "Existing Reduce motion preference still defaults to Fast")
	Preferences.save_fast_combat(prefix, false)
	check(not Preferences.read_fast_combat(prefix) and Preferences.read_motion(prefix), "Saving Normal preserves the separate Reduce motion choice")
	Preferences.save_motion(prefix, false)
	check(not Preferences.read_fast_combat(prefix) and not Preferences.read_motion(prefix), "Changing Reduce motion preserves Normal speed")
	Preferences.save_fast_combat(prefix, true)
	check(Preferences.read_fast_combat(prefix) and not Preferences.read_motion(prefix), "Saving Fast preserves normal motion")
	check(not FileAccess.file_exists(prefix + "run.json") and not FileAccess.file_exists(prefix + "grimoire.json"), "Preference changes never create gameplay or discovery saves")

func enemy(id: String, ability: String) -> Dictionary:
	return {"id": id, "name": "Invader " + id, "class_name": "warrior", "form": "warrior", "hp": 100, "max_hp": 100, "abilities": [ability], "armor": 0, "block": 0, "statuses": {}}

func set_game(tag: String) -> void:
	ui.skip_turn_animation()
	ui.close_modal()
	game = CountingState.new(profile_root + tag + "/")
	game.new_run(730207)
	for monster in game.run["monsters"]:
		monster["max_hp"] = 100
		monster["hp"] = 100
	game.run["party"] = [enemy("pace0", "strike"), enemy("pace1", "strike"), enemy("pace2", "guard")]
	game.start_raid()
	game.end_calls = 0
	game.save_calls = 0
	ui.state = game
	ui.menu = "game"
	ui.card_index = -1
	ui.last_action = ""
	ui.flow.delay_scale = 1.0
	ui.refresh()

func named(node: Node, id: String):
	if node.is_queued_for_deletion(): return null
	if str(node.name) == id and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, id)
		if found != null: return found
	return null

func button(node: Node, text: String):
	if node.is_queued_for_deletion(): return null
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.text == text: return node
	for child in node.get_children():
		var found = button(child, text)
		if found != null: return found
	return null

func reachable(control: Control) -> void:
	await settle()
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await settle()
		ancestor = ancestor.get_parent()
	var usable := Rect2(Vector2.ZERO, Vector2(pixels)).grow(1)
	ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: usable = usable.intersection(ancestor.get_global_rect().grow(1))
		ancestor = ancestor.get_parent()
	check(usable.encloses(control.get_global_rect()), "Settings action can be reached through ordinary scrolling: " + control.name)
	check(control.size.x >= 43.9 and control.size.y >= 43.9, "Settings action keeps a forty-four-pixel logical tap target: " + control.name)

func test_controls() -> void:
	set_game("controls_%dx%d" % [pixels.x, pixels.y])
	ui.set_fast_combat(true)
	ui.set_reduced_motion(false)
	await settle()
	var before: Dictionary = game.battle.to_dict()
	var run_before: Dictionary = game.run.duplicate(true)
	var open = button(ui, "Log & rules")
	check(open != null, "Production Log & rules action exists")
	if open == null: return
	await reachable(open)
	open.pressed.emit()
	await settle()
	var pacing = named(ui, "FastCombat")
	var motion = named(ui, "ReduceMotion")
	check(pacing is CheckButton and pacing.button_pressed and motion is CheckButton and not motion.button_pressed, "Log & rules exposes independent Fast combat and Reduce motion choices")
	if pacing == null or motion == null: return
	await reachable(pacing)
	pacing.button_pressed = false
	await settle()
	check(not ui.fast_combat and not Preferences.read_fast_combat(game._prefix) and not ui.reduced_motion, "Real checkbox toggle persists Normal without changing motion")
	await reachable(motion)
	motion.button_pressed = true
	await settle()
	check(ui.reduced_motion and Preferences.read_motion(game._prefix) and not ui.fast_combat, "Real motion checkbox persists independently of combat speed")
	check_scene_preferences(false, true)
	check(ui.flow.pause_lengths("enemy").is_equal_approx(Vector2(0.45, 0.55)), "Reduce motion keeps Normal announcement and result timings")
	await reachable(pacing)
	pacing.button_pressed = true
	await settle()
	check(ui.fast_combat and Preferences.read_fast_combat(game._prefix) and ui.reduced_motion, "Fast can be enabled while Reduce motion remains selected")
	check(ui.flow.pause_lengths("enemy").is_equal_approx(Vector2(0.2, 0.4)), "Fast keeps a readable announcement and result long enough for the 0.38-second projectile to reach its target")
	check(ui.flow.pause_lengths("draw").is_equal_approx(Vector2(0.1, 0.1)), "Fast shortens routine transitions between actions")
	check(equal(before, game.battle.to_dict()) and equal(run_before, game.run) and game.end_calls == 0 and game.save_calls == 0, "Settings toggles preserve battle, campaign RNG, run and gameplay save counters")
	await capture("settings_%dx%d" % [pixels.x, pixels.y])
	ui.close_modal()
	await settle()
	open = button(ui, "Log & rules")
	if open != null: open.pressed.emit()
	await settle()
	check(named(ui, "FastCombat").button_pressed and named(ui, "ReduceMotion").button_pressed, "Reopened settings reflect both saved independent choices")
	ui.close_modal()
	await settle()

func test_sequence(fast: bool) -> Dictionary:
	set_game("sequence_fast" if fast else "sequence_normal")
	ui.set_fast_combat(fast)
	ui.set_reduced_motion(true)
	await settle()
	var expected = Replay.make(game.battle)
	var configured := 0.0
	for frame in expected.frames:
		var stage: String = "enemy" if frame["kind"] in ["enemy", "stun"] else frame["kind"]
		var pauses: Vector2 = ui.flow.pause_lengths(stage)
		configured += pauses.x + pauses.y
	check(is_equal_approx(configured, 2.4 if fast else 4.8), "Three-invader turn has the intended configured duration")
	var started := Time.get_ticks_usec()
	ui.end_player_turn()
	check(game.end_calls == 1 and game.save_calls == 1 and ui.resolving_turn, "Playback commits and saves exactly once before its first animation")
	check(equal(expected.to_dict(), game.battle.to_dict()), "Authoritative result already matches ordinary combat and RNG")
	var committed: Dictionary = game.battle.to_dict()
	ui.end_player_turn()
	ui.act(game.end_turn)
	check(game.end_calls == 1 and game.save_calls == 1, "Duplicate turn actions cannot add a commit during playback")
	var announced: Dictionary = {}
	var aftermath: Dictionary = {}
	var draw_announced := false
	for poll in range(900):
		if not ui.resolving_turn: break
		check(equal(committed, game.battle.to_dict()), "Playback never mutates the already committed battle or RNG")
		if ui.turn_stage == "enemy":
			check(ui.turn_message.contains("uses") and ui.acting_actor_id != "", "Each invader action retains its named announcement")
			if ui.turn_detail == "": announced[ui.acting_actor_id] = true
			else:
				aftermath[ui.acting_actor_id] = true
				check(ui.turn_detail.contains("HP") or ui.turn_detail.contains("block"), "Each invader aftermath retains numeric combat results")
		elif ui.turn_stage == "draw": draw_announced = true
		await create_timer(0.01).timeout
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	check(not ui.resolving_turn and game.end_calls == 1 and game.save_calls == 1, "Complete playback releases input after exactly one authoritative turn")
	check(announced.size() == 3 and aftermath.size() == 3 and draw_announced, "Both speeds present every invader announcement, outcome and next hand")
	check(equal(committed, game.battle.to_dict()), "Completed playback preserves the expected final state and RNG")
	await capture("fast_next_turn" if fast else "normal_next_turn")
	return {"battle": committed, "elapsed": elapsed}

func test_skip_and_reload(fast: bool) -> void:
	set_game("skip_fast" if fast else "skip_normal")
	ui.set_fast_combat(fast, true)
	ui.set_reduced_motion(false, true)
	await settle()
	var expected = Replay.make(game.battle)
	ui.end_player_turn()
	var committed: Dictionary = game.battle.to_dict()
	var reloaded = State.new(game._prefix)
	check(reloaded.load_game() and equal(committed, reloaded.battle.to_dict()) and equal(expected.to_dict(), committed), "Reload during either speed restores the committed result and exact RNG")
	check(Preferences.read_fast_combat(game._prefix) == fast and not Preferences.read_motion(game._prefix), "Mid-turn reload retains speed independently of motion preference")
	var skip = named(ui, "SkipTurn")
	check(skip is Button and not skip.disabled, "Both speeds keep the ordinary Skip animation control")
	if skip != null: skip.pressed.emit()
	await settle()
	check(not ui.resolving_turn and equal(committed, game.battle.to_dict()) and game.end_calls == 1 and game.save_calls == 1, "Skip reveals the committed state without another turn or save")
	await create_timer(0.7).timeout
	check(not ui.resolving_turn and equal(committed, game.battle.to_dict()) and game.end_calls == 1, "Cancelled timers cannot resume a skipped sequence")
	ui.state = reloaded
	ui.refresh()
	await settle()
	check(equal(committed, ui.combat_battle().to_dict()) and named(ui, "EndTurn") != null, "Continued UI returns to the next playable turn")

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	if can_render:
		var picture = (root.get_texture() if ui.get_viewport() == root else surface.get_texture()).get_image()
		check(picture.get_size() == pixels and picture.save_png("res://tests/artifacts/pacing/" + tag + ".png") == OK, "Native pacing capture saved with exact logical dimensions")
	else: check(surface.size == pixels, "Headless pacing layout uses exact logical dimensions")
	captures += 1

func inspect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is BaseButton):
		var vertical := false
		var horizontal := false
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				vertical = vertical or ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				horizontal = horizontal or ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		if not horizontal: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Pacing controls and labels fit horizontally: " + node.name)
		if not vertical: check(rect.position.y >= -1 and rect.end.y <= pixels.y + 1, "Unscrolled pacing controls and labels fit vertically: " + node.name)
	for child in node.get_children(): inspect(child)

func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.window_id = root.get_window_id()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func check_scene_preferences(fast: bool, motion: bool) -> void:
	var restored = MainScene.instantiate()
	restored.state = game
	ui.get_parent().add_child(restored)
	check(restored.fast_combat == fast and restored.reduced_motion == motion, "A fresh scene reads both persisted preferences, including nondefault Normal")
	restored.free()

func tap(control: Control) -> void:
	await reachable(control)
	var center := control.get_global_rect().get_center()
	await touch(center, true)
	await touch(center, false)
	await settle()

func test_native_toggle() -> void:
	surface.remove_child(ui)
	ui.free()
	pixels = Vector2i(390, 844)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = pixels
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "native_bootstrap/")
	root.add_child(ui)
	set_game("native_touch")
	ui.set_fast_combat(true, true)
	ui.set_reduced_motion(false, true)
	await settle()
	var open = button(ui, "Log & rules")
	if open == null:
		check(false, "Native Log & rules action exists")
		return
	await tap(open)
	var pacing = named(ui, "FastCombat")
	if pacing == null:
		check(false, "Native Fast combat action exists")
		return
	var before: Dictionary = game.battle.to_dict()
	await tap(pacing)
	check(not ui.fast_combat and not Preferences.read_fast_combat(game._prefix) and not ui.reduced_motion, "Real ScreenTouch persists Normal while motion stays independent")
	check_scene_preferences(false, false)
	await tap(pacing)
	check(ui.fast_combat and Preferences.read_fast_combat(game._prefix) and equal(before, game.battle.to_dict()) and game.end_calls == 0, "Real ScreenTouch restores Fast without touching combat or RNG")
	await capture("native_touch_fast_settings")
	check_scene_preferences(true, false)
