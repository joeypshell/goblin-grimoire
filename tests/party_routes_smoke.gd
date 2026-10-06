extends SceneTree

# Production preparation controls, with isolated profiles and exact logical sizes.
# Native rendering adds screenshots and a real mouse-from-ScreenTouch slice.
const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/game_data.gd")
const SIZES = [Vector2i(1280, 720), Vector2i(375, 667), Vector2i(390, 844), Vector2i(844, 320)]
const RAIDS = [1, 3, 4]

var ui
var game
var surface: SubViewport
var pixels := Vector2i.ZERO
var profile_root: String
var checks := 0
var captured := 0
var failures: Array = []
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/party_routes_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/routes/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	surface = SubViewport.new()
	surface.size = SIZES[0]
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root), "Scene startup retains its isolated bootstrap profile")
	check(ui.report_uploader.state._prefix.begins_with(profile_root), "Uploader retains only the isolated bootstrap state")
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		for raid in RAIDS:
			await exercise_raid(raid)
		await exercise_known_meals()
	if can_render:
		await exercise_native_touch()
	else:
		print("PARTY ROUTES HEADLESS: ScreenTouch and PNG capture skipped")
	print("PARTY ROUTES SMOKE: %d assertions; %d %s; %d issues" % [checks, captured, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("PARTY ROUTES ISSUE: ", failure)
	if is_instance_valid(ui): ui.free()
	surface.free()
	# AudioServer retires stopped music playback references on its next mix callback.
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%dx%d: %s" % [pixels.x, pixels.y, message])
		push_error(failures.back())

func equal(left, right) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func same_party(actual: Array, preview: Array) -> bool:
	# Combat adds ephemeral status-layer bookkeeping to the cached actors.
	if actual.size() != preview.size(): return false
	for index in range(preview.size()):
		for key in preview[index]:
			if not actual[index].has(key) or not equal(actual[index][key], preview[index][key]): return false
	return true

func settle() -> void:
	for frame in range(8): await process_frame
	if can_render: await RenderingServer.frame_post_draw

func reset_game(raid: int, tag: String) -> void:
	ui.skip_turn_animation()
	ui.close_modal()
	game = State.new(profile_root + "%dx%d/%s/" % [pixels.x, pixels.y, tag])
	game.new_run(730204 + raid)
	# Milestone fixture prevents an unrelated earned-trait prompt during Continue.
	game.run["traits"] = ["pack_instinct"] if raid == 1 else ["pack_instinct", "venom_nest"]
	game.run["trait_milestones"] = [1] if raid == 1 else [1, 3]
	game.run["raid"] = raid
	game.run.erase("party")
	game.party_preview()
	ui.state = game
	ui.menu = "game"
	ui.card_index = -1
	ui.flow.delay_scale = 0
	ui.refresh()

func named(node: Node, id: String):
	if node.is_queued_for_deletion(): return null
	if str(node.name) == id and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, id)
		if found != null: return found
	return null

func action(node: Node, prefix: String):
	if node.is_queued_for_deletion(): return null
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found = action(child, prefix)
		if found != null: return found
	return null

func visible_text(node: Node) -> String:
	if node.is_queued_for_deletion(): return ""
	var result := ""
	if node is Label or node is Button:
		if node.is_visible_in_tree(): result += node.text + "\n"
	for child in node.get_children(): result += visible_text(child)
	return result

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
	check(usable.encloses(control.get_global_rect()), "Intended scrolling fully reaches action: " + control.name)
	check(control.size.x >= 43.9 and control.size.y >= 43.9, "Action retains a forty-four-pixel logical tap target: " + control.name)

func preview_matches(options: Array) -> void:
	check(options.size() == 2 and named(ui, "PartyChoiceHeading") is Label, "Preparation visibly offers exactly two named parties")
	for option in options:
		var id: String = option["id"]
		var card = named(ui, "PartyChoice_" + id)
		check(card != null, "Every offered party renders its own card: " + id)
		if card == null: continue
		for actor in option["party"]:
			var member = named(ui, "PartyMember_" + id + "_" + actor["id"])
			check(member is Label and member.text.contains("%d HP" % actor["max_hp"]) and member.text.contains("Armor %d" % Data.armor(actor)), "Party preview shows actual HP and passive armor for each member")
		var expected: Array = []
		# Calculate from unknown actual skills, independently of the UI helper.
		for actor in option["party"]:
			for ability in actor["abilities"]:
				var can_inherit := false
				for recipient in game.run["monsters"]:
					if not recipient["learned"].has(ability): can_inherit = true
				var affinity: String = Data.ABILITIES[ability]["affinity"]
				if can_inherit and affinity != "Neutral" and not expected.has(affinity): expected.append(affinity)
		var opportunities = named(ui, "PartyAffinities_" + id)
		var advertised: Array = []
		if opportunities is Label and opportunities.text.begins_with("Possible meal affinities: ") and not expected.is_empty():
			advertised.assign(opportunities.text.trim_prefix("Possible meal affinities: ").split(", "))
		advertised.sort()
		expected.sort()
		check(opportunities is Label and advertised == expected and (not expected.is_empty() or opportunities.text == "Possible meal affinities: No unknown non-Neutral skills for this team"), "Affinity advice comes from actual unknown transferable skills: " + id)
		var copy: String = visible_text(card)
		for form in Data.FORMS:
			if form != "goblin": check(not copy.contains(Data.FORMS[form]["name"]), "Party preview keeps undiscovered transformation names hidden: " + form)
		check(not advertised.has("Neutral"), "Neutral cards are omitted from affinity opportunities")

func selection_matches(option: Dictionary) -> void:
	var id: String = option["id"]
	check(game.run["party_choice"] == id and equal(game.run["party"], option["party"]), "Selected option becomes the exact incoming party: " + id)
	var cue = named(ui, "PartySelectionCue")
	var incoming = named(ui, "SelectedIncomingParty")
	check(cue is Label and cue.text == "READY TO DEFEND / " + option["name"], "Readiness cue identifies the selected party")
	check(incoming is Label and incoming.text == "INCOMING / " + option["name"], "Detailed incoming section identifies the selected party")
	for offered in game.party_choices():
		var status = named(ui, "PartyChoiceStatus_" + offered["id"])
		var choose = named(ui, "PartySelect_" + offered["id"])
		check(status is Label and status.text == ("SELECTED PARTY" if offered["id"] == id else "ALTERNATIVE PARTY"), "Every card accurately identifies its current selection state")
		check(choose is Button and choose.disabled == (offered["id"] == id), "Only the selected party's redundant action is disabled")
	var details: String = visible_text(ui.content)
	for actor in option["party"]:
		check(details.contains(actor["name"]), "Incoming preview shows selected member's actual name")
		for ability in actor["abilities"]: check(details.contains(Data.ABILITIES[ability]["name"]), "Incoming preview shows selected member's actual usable skills")

func choose(option: Dictionary) -> void:
	var id: String = option["id"]
	var control = named(ui, "PartySelect_" + id)
	check(control is Button and not control.disabled, "Alternative has an enabled production selection control: " + id)
	if control == null or control.disabled: return
	var rng_before: int = game.rng.state
	var team_before: Array = game.run["monsters"].duplicate(true)
	await reachable(control)
	control.pressed.emit()
	await settle()
	selection_matches(option)
	check(game.rng.state == rng_before and game.run["monsters"] == team_before, "Selecting a party consumes no campaign RNG or recovery")
	check(ui.toast.text.contains(option["name"]) and ui.toast.text.contains("Defend"), "Selection feedback says what was chosen and what comes next")

func exercise_raid(raid: int) -> void:
	reset_game(raid, "raid_%d" % raid)
	await settle()
	var options: Array = game.party_choices()
	preview_matches(options)
	if options.size() != 2: return
	selection_matches(options[0])
	await capture("raid_%d_01_standard" % raid)
	await choose(options[1])
	await rotate_selection(options[1])
	var loaded = State.new(game._prefix)
	check(loaded.load_game() and equal(loaded.run["party"], options[1]["party"]) and loaded.run["party_choice"] == "alternate" and equal(loaded.party_choices(), options), "Continue preserves the alternate party and both cached options")
	check(loaded.rng.state == game.rng.state, "Continue preserves the campaign RNG after selection")
	game = loaded
	ui.state = game
	ui.refresh()
	await settle()
	selection_matches(options[1])
	await reachable(named(ui, "PartySelect_standard"))
	await capture("raid_%d_02_alternate_continued" % raid)
	await choose(options[0])
	await choose(options[1])
	var defend = action(ui, "Defend")
	check(defend != null, "Selected party can be defended with the production action")
	if defend == null: return
	await reachable(defend)
	defend.pressed.emit()
	await settle()
	check(game.run["phase"] == "combat" and game.run["party_locked"] and game.party_choices().is_empty(), "Defend starts combat and locks party selection")
	check(same_party(game.battle.enemies, options[1]["party"]), "Combat starts with the exact chosen preview actors")
	check(not game.select_party("standard"), "Locked combat rejects attempts to switch to the other party")
	await capture("raid_%d_03_locked_combat" % raid)
	# The selected party's wipe uses normal state resolution on an isolated profile.
	for monster in game.battle.monsters: monster["hp"] = 0
	game.end_turn()
	check(game.run["last_result"] == "breach" and game.run["phase"] == "defeat" and game.run["monsters"].all(func(actor): return actor["hp"] == 0), "Losing the selected-party fight ends the dungeon immediately with all monsters still knocked out")
	ui.refresh()
	await settle()
	var return_to_prep = action(ui, "Return to preparation")
	check(return_to_prep == null and action(ui, "Defend") == null and named(ui, "PartyRetryNotice") == null, "A lost dungeon has no return, defend or locked-party retry control")
	check(game.party_choices().is_empty() and named(ui, "PartyChoiceHeading") == null and not game.select_party("standard"), "Defeat exposes no route selection and cannot reroll the lost encounter")
	check(not game.run.has("core") and game.run.get("rewards", []).is_empty(), "Defeat carries neither a separate Core pool nor corpse rewards")
	var lost_saved = State.new(game._prefix)
	check(lost_saved.load_game() and lost_saved.run["phase"] == "defeat" and lost_saved.run["monsters"].all(func(actor): return actor["hp"] == 0), "Continue preserves the selected-party defeat without recovery or retry")
	await capture("raid_%d_04_dungeon_lost" % raid)
	var begin = action(ui, "Begin another run")
	check(begin is Button, "Defeat offers the production new-run action")
	if begin == null: return
	await reachable(begin)
	begin.pressed.emit()
	await settle()
	check(game.run["phase"] == "prep" and game.run["raid"] == 0 and game.run["monsters"].all(func(actor): return actor["form"] == "goblin" and actor["hp"] == actor["max_hp"]), "Begin another run creates three fresh goblins at raid one instead of retrying the lost party")

func rotate_selection(option: Dictionary) -> void:
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	var original := pixels
	pixels = Vector2i(844, 320) if original.x < original.y else Vector2i(390, 844)
	surface.size = pixels
	await settle()
	selection_matches(option)
	inspect(ui)
	await reachable(named(ui, "PartySelect_standard"))
	check(equal(game.run, before) and game.rng.state == random_before, "Rotating the screen retains selected party, cached choices and campaign RNG")
	pixels = original
	surface.size = pixels
	await settle()
	selection_matches(option)
	check(equal(game.run, before) and game.rng.state == random_before, "Returning to the initial orientation retains preparation state")

func exercise_known_meals() -> void:
	reset_game(1, "known_meals")
	var options: Array = game.party_choices()
	var abilities: Array = []
	for option in options:
		for actor in option["party"]:
			for ability in actor["abilities"]:
				if not abilities.has(ability): abilities.append(ability)
	for monster in game.run["monsters"]:
		for ability in abilities:
			if not monster["learned"].has(ability): monster["learned"].append(ability)
	ui.refresh()
	await settle()
	preview_matches(options)
	for option in options:
		check(named(ui, "PartyAffinities_" + option["id"]).text == "Possible meal affinities: No unknown non-Neutral skills for this team", "Fully learned parties promise no new affinity")
	# One recipient's missing skill makes that actual affinity available again.
	game.run["monsters"][0]["learned"].erase("firebolt")
	ui.refresh()
	await settle()
	preview_matches(options)
	check(named(ui, "PartyAffinities_alternate").text == "Possible meal affinities: Flame", "A single recipient's unknown Firebolt restores only Flame advice")
	await reachable(named(ui, "PartySelect_alternate"))
	await capture("05_actual_unknown_affinities")

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var destination := "res://tests/artifacts/routes/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(destination)
	if can_render:
		var picture = (root.get_texture() if ui.get_viewport() == root else surface.get_texture()).get_image()
		check(picture.get_size() == pixels, "Route capture has exact logical dimensions")
		check(picture.save_png(destination + tag + ".png") == OK, "Native route capture saved")
	else:
		check(surface.size == pixels, "Headless route layout uses exact logical dimensions")
	captured += 1
	print("PARTY ROUTES CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

func inspect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is BaseButton):
		var vertical := false
		var horizontal := false
		var owner_button
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				vertical = vertical or ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				horizontal = horizontal or ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			if ancestor is BaseButton and owner_button == null: owner_button = ancestor
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		if not horizontal: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Vertical scrolling preserves all horizontal content: " + node.name)
		if not vertical: check(rect.position.y >= -1 and rect.end.y <= pixels.y + 1, "Unscrolled controls remain inside the viewport: " + node.name)
		if owner_button != null: check(owner_button.get_global_rect().grow(1).encloses(rect), "Control contains its visible child label: " + node.name)
		if node is Button and str(node.name).begins_with("PartySelect_"):
			check(rect.size.x >= 43.9 and rect.size.y >= 43.9, "Every offered route retains a forty-four-pixel logical tap target")
	for child in node.get_children(): inspect(child)

func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.window_id = root.get_window_id()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func tap(control: Control) -> void:
	await reachable(control)
	var center := control.get_global_rect().get_center()
	await touch(center, true)
	await touch(center, false)
	await settle()

func exercise_native_touch() -> void:
	surface.remove_child(ui)
	ui.free()
	pixels = Vector2i(390, 844)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = pixels
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "native_touch_bootstrap/")
	root.add_child(ui)
	reset_game(1, "native_touch")
	await settle()
	var options: Array = game.party_choices()
	var alternate = named(ui, "PartySelect_alternate")
	check(alternate is Button and not alternate.disabled, "Native touch alternate action exists")
	if alternate == null: return
	await tap(alternate)
	check(game.run["party_choice"] == "alternate", "Real ScreenTouch chooses the alternate party through production mouse emulation")
	selection_matches(options[1])
	var standard = named(ui, "PartySelect_standard")
	if standard != null: await tap(standard)
	check(game.run["party_choice"] == "standard", "Real ScreenTouch switches back to the standard party")
	selection_matches(options[0])
	alternate = named(ui, "PartySelect_alternate")
	if alternate != null: await tap(alternate)
	check(game.run["party_choice"] == "alternate", "Real ScreenTouch selects the intended party after scrolling between cards")
	await capture("06_native_touch_selected_party")
	var defend = action(ui, "Defend")
	if defend != null: await tap(defend)
	check(game.run["phase"] == "combat" and game.run["party_locked"] and same_party(game.battle.enemies, options[1]["party"]), "Real ScreenTouch Defend starts and locks the selected incoming actors")
	await capture("07_native_touch_locked_combat")
