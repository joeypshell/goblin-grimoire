extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/game_data.gd")
const CombatChecks = preload("res://tests/ui_combat_checks.gd")
const FeedingChecks = preload("res://tests/feeding_ui_checks.gd")
const TurnChecks = preload("res://tests/turn_ui_checks.gd")
const SIZES = [Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932), Vector2i(844, 390), Vector2i(844, 320), Vector2i(756, 330), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1920, 900)]

var ui
var game
var surface: SubViewport
var current_size: Vector2i
var captured := 0
var checks := 0
var issues: Array = []
var profile_root: String
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/mobile_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/")
	var ignore_file = FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE)
	if ignore_file != null:
		ignore_file.store_string("# Native QA captures are not game resources.\n")
		ignore_file.close()
	# A native SubViewport gives exact logical dimensions regardless of the host monitor.
	surface = SubViewport.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.gui_embed_subwindows = true
	surface.size = SIZES[0]
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root), "Scene startup preserves its explicitly isolated verification profile")
	if not OS.get_cmdline_user_args().has("--touch-only"):
		for pixels in SIZES:
			await exercise_size(pixels)
	if can_render:
		await exercise_native_touch()
	else:
		print("HEADLESS: layout/state checks only; native touch and PNG capture skipped")
	print("MOBILE SMOKE: %d %s; %d assertions; %d layout/interaction issues" % [captured, "native screenshots" if can_render else "headless layouts", checks, issues.size()])
	for issue in issues:
		print("MOBILE ISSUE: ", issue)
	surface.free()
	# AudioServer retires stopped music playback references on its next mix callback.
	await create_timer(0.15).timeout
	quit(0 if issues.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		issues.append("%dx%d: %s" % [current_size.x, current_size.y, message])

func settle() -> void:
	for frame in range(8):
		await process_frame
	if can_render: await RenderingServer.frame_post_draw

func exercise_size(pixels: Vector2i) -> void:
	ui.close_modal()
	await settle()
	current_size = pixels
	surface.size = pixels
	game = State.new(profile_root + "%dx%d/" % [pixels.x, pixels.y])
	ui.state = game
	ui.menu = "title"
	ui.card_index = -1
	ui.feed_body = 0
	ui.feed_monster = ""
	ui.refresh()
	await capture("01_title")
	ui.menu = "grimoire"
	ui.refresh()
	await capture("02_empty_grimoire")
	game.new_run(730204)
	ui.menu = "game"
	ui.refresh()
	await capture("03_preparation")
	await test_skill_popup()
	await reachable_button("Defend", true)
	var defend = find_button(ui, "Defend")
	if defend != null:
		defend.pressed.emit()
	else:
		game.start_raid()
		ui.refresh()
	check(game.run["phase"] == "combat", "Preparation action starts actual combat")
	await capture("04_combat")
	var strike_index := -1
	for index in range(game.battle.hand.size()):
		if game.battle.hand[index]["ability"] == "strike":
			strike_index = index
			break
	check(strike_index >= 0, "Seeded first hand provides a targeted real attack")
	if strike_index >= 0:
		var strike_button = find_button(ui, "", "Strike")
		if strike_button != null:
			await ensure_reachable(strike_button, "Card selection")
			strike_button.pressed.emit()
		else:
			ui.card_index = strike_index
			ui.refresh()
	await capture("05_card_target")
	var instructions = ui.content.find_child("CardExplanation", true, false)
	if instructions != null and current_size.x < current_size.y:
		check(instructions.get_parent().get_global_rect().grow(1).encloses(instructions.get_global_rect()), "Selected owner, target and numeric action instructions fit without internal scrolling")
	await test_orientation_preservation()
	var enemy_id: String = game.battle.enemies[0]["id"]
	var before_hp: int = game.battle.enemies[0]["hp"]
	var before_energy: int = game.battle.energy
	var target_button = ui.actor_nodes.get(enemy_id)
	check(target_button != null, "Selected card exposes a real enemy target")
	if target_button != null:
		await ensure_reachable(target_button, "Legal enemy target")
		target_button.pressed.emit()
		await settle()
		check(game.battle.enemies[0]["hp"] < before_hp and game.battle.energy < before_energy, "Tapping legal target resolves actual damage and cost")
	await reachable_button("End turn", true)
	await capture("06_after_card")
	await test_warning_and_core_layout()
	fixture_feeding()
	var reveal_info: Dictionary = await FeedingChecks.new().exercise(self)
	ui.rewards_screen.reveal(reveal_info)
	await capture("08_reveal")
	await test_modal_orientation()
	await reachable_button("Welcome", true)
	ui.close_modal()
	await settle()
	ui.menu = "grimoire"
	ui.refresh()
	await capture("09_discovered_grimoire")
	ui.menu = "game"
	for index in range(game.run["rewards"].size()):
		game.skip_body(index)
	ui.refresh()
	await reachable_button("Recover", true)
	var recover = find_button(ui, "Recover")
	if recover != null:
		recover.pressed.emit()
	else:
		game.finish_feeding()
		ui.refresh()
	await FeedingChecks.new().choose_trait(self)
	check(game.run["phase"] == "result", "Reachable trait selection completes the first milestone and reaches result")
	await capture("10_result")
	game.run["phase"] = "victory"
	game.run["raid"] = 6
	game.run["promotion"] = "D"
	ui.refresh()
	await capture("11_victory")
	await reachable_button("Begin", true)
	game.run["phase"] = "defeat"
	game.run["core"] = 0
	ui.refresh()
	await capture("12_defeat")
	fixture_evolved_combat()
	ui.card_index = 0
	ui.refresh()
	await capture("13_evolved_area_targets")
	await reachable_button("End turn", true)
	ui.card_index = 1
	ui.refresh()
	await capture("14_regrowth_targets")
	ui.card_index = 2
	ui.refresh()
	await capture("15_shared_rally_targets")

func fixture_feeding() -> void:
	# Rare-phase UI fixtures are separate from the mechanically played campaign test.
	game.run["phase"] = "feeding"
	game.run["rewards"] = []
	for actor in game.battle.enemies:
		game.run["rewards"].append({"id": actor["id"], "name": actor["name"], "class_name": actor["class_name"], "form": actor["form"], "abilities": actor["abilities"].duplicate(), "armor": Data.armor(actor), "claimed": false})
	game.run["resolved_id"] = 1
	ui.card_index = -1
	ui.feed_body = 0
	ui.feed_monster = game.run["monsters"][0]["id"]

func test_warning_and_core_layout() -> void:
	ui.card_index = 0
	ui.refresh()
	await settle()
	var before: String = JSON.stringify(game.battle.to_dict())
	var run_before: String = JSON.stringify(game.run)
	var rng_before: int = game.rng.state
	var end = TurnChecks.named(ui, "EndTurn")
	check(end is Button and game.battle.energy > 0, "Mobile fixture can deliberately end a turn with unspent energy")
	if end == null: return
	await ensure_reachable(end, "End turn with unspent energy")
	end.pressed.emit()
	await settle()
	var warning = TurnChecks.named(ui, "EndTurnWarning")
	var keep = TurnChecks.named(ui, "KeepPlaying")
	var confirm = TurnChecks.named(ui, "EndTurnAnyway")
	check(warning != null and keep is Button and confirm is Button, "Unspent energy warning offers separate playable and confirmed-end actions")
	if keep == null or confirm == null: return
	await ensure_reachable(keep, "Keep playing")
	await ensure_reachable(confirm, "End turn anyway")
	await capture("06b_unspent_energy_warning")
	check(JSON.stringify(game.battle.to_dict()) == before and JSON.stringify(game.run) == run_before and game.rng.state == rng_before and ui.card_index == 0 and not ui.resolving_turn, "Phone warning preserves selected card, hand, energy, campaign and all gameplay RNG")
	keep.pressed.emit()
	await settle()
	check(not is_instance_valid(ui.overlay) and JSON.stringify(game.battle.to_dict()) == before and ui.card_index == 0, "Keep playing returns to the same selected card on every logical size")
	var core = TurnChecks.named(ui, "CoreInfo")
	check(core is Button and core.text.contains("HP"), "Dungeon core health has a readable help action")
	if core == null: return
	await ensure_reachable(core, "Dungeon core health")
	core.pressed.emit()
	await settle()
	check(TurnChecks.named(ui, "DungeonCoreInfo") != null and TurnChecks.visible_text(ui.overlay).contains("25 HP") and TurnChecks.visible_text(ui.overlay).contains("At 0 Core HP, the run ends"), "Core help explains breach damage and the run-ending condition on phones and desktop")
	var back = TurnChecks.named(ui, "CloseCoreInfo")
	check(back is Button, "Core help exposes a return action")
	if back == null: return
	await ensure_reachable(back, "Return from dungeon core help")
	await capture("06c_core_help")
	back.pressed.emit()
	await settle()
	check(JSON.stringify(game.battle.to_dict()) == before and JSON.stringify(game.run) == run_before and ui.card_index == 0 and not is_instance_valid(ui.overlay), "Core explanation preserves gameplay and selected card through its full open/close flow")

func fixture_evolved_combat() -> void:
	game.new_run(730205)
	var evolved: Dictionary = game.run["monsters"][0]
	evolved["form"] = "oni"
	evolved["max_hp"] = Data.FORMS["oni"]["max_hp"]
	evolved["hp"] = 30
	evolved["learned"].append("regrowth")
	evolved["selected"] = ["regrowth", "patch_up"]
	game.run["raid"] = 5
	game.run.erase("party")
	game.start_raid()
	game.battle.hand = [{"id": "aoe_1", "ability": "spirit_flame", "owner": evolved["id"]}, {"id": "aoe_2", "ability": "regrowth", "owner": evolved["id"]}, {"id": "aoe_3", "ability": "rally", "owner": ""}, {"id": "aoe_4", "ability": "core_pulse", "owner": ""}, {"id": "aoe_5", "ability": "mend", "owner": evolved["id"]}]

func test_orientation_preservation() -> void:
	var before := JSON.stringify(game.battle.to_dict())
	var rng_before: int = game.rng.state
	var selection: int = ui.card_index
	var alternate := Vector2i(844, 390) if current_size.x < current_size.y else Vector2i(390, 844)
	surface.size = alternate
	await settle()
	check(ui.card_index == selection and JSON.stringify(game.battle.to_dict()) == before and game.rng.state == rng_before, "Orientation change preserves selected card, battle state and locked RNG")
	surface.size = current_size
	await settle()
	check(ui.card_index == selection and JSON.stringify(game.battle.to_dict()) == before, "Returning to original dimensions preserves combat selection/state")

func test_modal_orientation() -> void:
	var original := current_size
	var before := JSON.stringify(game.run)
	var discoveries_before := JSON.stringify(game.discoveries())
	current_size = Vector2i(375, 667) if original.x >= 1000 else Vector2i(1280, 720)
	surface.size = current_size
	await settle()
	check(is_instance_valid(ui.overlay), "Evolution modal survives orientation without losing its content")
	inspect_controls(ui, "08_rotated_reveal")
	await reachable_button("Welcome", true)
	current_size = original
	surface.size = original
	await settle()
	check(JSON.stringify(game.run) == before and JSON.stringify(game.discoveries()) == discoveries_before, "Resizing evolution reveal preserves run and performed discovery")

func find_button(node: Node, prefix: String, contains: String = ""):
	# Stable action names survive clearer player-facing copy.
	if prefix == "End turn" and node is Button and node.name == "EndTurn" and node.is_visible_in_tree() and not node.disabled:
		return node
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.text.begins_with(prefix) and (contains.is_empty() or node.text.contains(contains)):
		return node
	for child in node.get_children():
		var found = find_button(child, prefix, contains)
		if found != null:
			return found
	return null

func reachable_button(prefix: String, required: bool) -> void:
	var found = find_button(ui, prefix)
	check(found != null or not required, "Action exists and is enabled: " + prefix)
	if found != null:
		await ensure_reachable(found, prefix)

func ensure_reachable(control: Control, label: String) -> void:
	# Scroll ranges are recalculated after a UI rebuild; wait before requesting visibility.
	await settle()
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await settle()
		ancestor = ancestor.get_parent()
	await settle()
	var rect := control.get_global_rect()
	var usable := Rect2(Vector2.ZERO, Vector2(current_size)).grow(1)
	ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			usable = usable.intersection(ancestor.get_global_rect().grow(1))
		ancestor = ancestor.get_parent()
	check(usable.encloses(rect), "Action can be fully reached by intended scrolling: " + label + " " + str(rect))
	if current_size.x < 1050 or current_size.y < 560:
		check(rect.size.x >= 43.9 and rect.size.y >= 43.9, "Tap target is at least44logical pixels: " + label + " " + str(rect.size))

func capture(name: String) -> void:
	await settle()
	if ui.state.run.get("phase", "") == "combat": CombatChecks.defenses(self, ui)
	check(not is_instance_valid(ui.overlay) or name in ["08_reveal", "06b_unspent_energy_warning", "06c_core_help"], "Screen is not obscured by an unintended modal: " + name)
	var destination := "res://tests/artifacts/mobile/%dx%d/" % [current_size.x, current_size.y]
	DirAccess.make_dir_recursive_absolute(destination)
	if can_render:
		var picture := surface.get_texture().get_image()
		check(picture.get_size() == current_size, "Native capture has exact logical viewport dimensions")
		check(picture.save_png(destination + name + ".png") == OK, "Native screenshot saved: " + name)
	else:
		check(surface.size == current_size, "Headless layout has exact logical viewport dimensions")
	captured += 1
	print("MOBILE CAPTURE: %dx%d %s" % [current_size.x, current_size.y, name])
	inspect_controls(ui, name)

func inspect_controls(node: Node, screen: String) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Label or node is ScrollContainer):
		var vertical_scroll := false
		var horizontal_scroll := false
		var owner_button
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				vertical_scroll = vertical_scroll or ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				horizontal_scroll = horizontal_scroll or ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			if ancestor is BaseButton and owner_button == null:
				owner_button = ancestor
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		var label: String = (node.text if node is Button or node is Label else str(node.name)).replace("\n", " ").left(80)
		if not horizontal_scroll:
			check(rect.position.x >= -1 and rect.end.x <= current_size.x + 1, screen + ": unintended horizontal clipping: " + label + " " + str(rect))
		if not vertical_scroll:
			check(rect.position.y >= -1 and rect.end.y <= current_size.y + 1, screen + ": unintended vertical clipping: " + label + " " + str(rect))
		if owner_button != null:
			check(owner_button.get_global_rect().grow(1).encloses(rect), screen + ": actor/button contains its text: " + label)
		if node is BaseButton and not node.disabled and current_size.x < 1000:
			check(rect.size.x >= 43.9 and rect.size.y >= 43.9, screen + ": actionable tap target44px: " + label + " " + str(rect.size))
	for child in node.get_children():
		inspect_controls(child, screen)

func find_picker(node: Node):
	if node is OptionButton: return node
	for child in node.get_children():
		var found = find_picker(child)
		if found != null: return found
	return null

func test_skill_popup() -> void:
	var picker = find_picker(ui)
	check(picker != null, "Preparation exposes a learned-skill picker")
	if picker == null: return
	await ensure_reachable(picker, "Skill picker")
	picker.show_popup()
	await settle()
	var popup: PopupMenu = picker.get_popup()
	check(popup.size.x <= current_size.x and popup.size.y <= current_size.y, "Skill popup fits viewport dimensions")
	if current_size.x < 1000:
		var font: Font = popup.get_theme_font("font")
		var row_height := font.get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
		check(row_height >= 43.9, "Skill popup rows provide44px touch targets")
	popup.hide()
	await settle()

func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.window_id = root.get_window_id()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func tap_native(control: Control) -> void:
	await ensure_reachable(control, "Native touch action")
	var center := control.get_global_rect().get_center()
	await touch(center, true)
	await touch(center, false)
	await settle()

func first_scroll(node: Node):
	if node is ScrollContainer and node.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return node
	for child in node.get_children():
		var found = first_scroll(child)
		if found != null: return found
	return null

func exercise_native_touch() -> void:
	# Real Input events use the native Window, since SubViewport.push_input bypasses Input's mouse-from-touch conversion.
	surface.remove_child(ui)
	ui.free()
	current_size = Vector2i(390, 844)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = current_size
	ui = MainScene.instantiate()
	game = State.new(profile_root + "native_touch/")
	ui.state = game
	root.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Native touch startup keeps state and uploader isolated from the player profile")
	ui.refresh()
	await settle()
	var new_run_button = find_button(ui, "New run")
	check(new_run_button != null, "Native touch New Run button exists")
	if new_run_button == null: return
	await tap_native(new_run_button)
	check(ui.menu == "game" and game.run.get("phase", "") == "prep", "ScreenTouch press/release activates New Run through production mouse-from-touch emulation")
	if game.run.is_empty():
		ui.free()
		return
	var scroll = first_scroll(ui.content)
	check(scroll != null, "Preparation has a touch-scroll surface")
	if scroll != null:
		scroll.scroll_vertical = 0
		await settle()
		var start: Vector2 = scroll.get_global_rect().position + Vector2(20, minf(250, scroll.size.y - 25))
		await touch(start, true)
		for index in range(1, 7):
			var drag := InputEventScreenDrag.new()
			drag.window_id = root.get_window_id()
			drag.index = 0
			drag.position = start - Vector2(0, index * 25)
			drag.relative = Vector2(0, -25)
			drag.velocity = Vector2(0, -400)
			Input.parse_input_event(drag)
			await process_frame
		await touch(start - Vector2(0, 150), false)
		await settle()
		check(scroll.scroll_vertical > 0, "ScreenTouch/ScreenDrag moves the preparation scroll surface")
	game.new_run(730204)
	ui.refresh()
	await settle()
	var defend = find_button(ui, "Defend")
	if defend != null:
		await tap_native(defend)
	check(game.run["phase"] == "combat", "Native touch activates Defend")
	if game.run["phase"] != "combat":
		ui.free()
		return
	var strike_button = find_button(ui, "", "Strike")
	if strike_button != null:
		await tap_native(strike_button)
	check(ui.card_index >= 0, "Native touch selects a real card")
	var enemy_id: String = game.battle.enemies[0]["id"]
	var hp_before: int = game.battle.enemies[0]["hp"]
	var target = ui.actor_nodes.get(enemy_id)
	if target != null:
		await tap_native(target)
	check(game.battle.enemies[0]["hp"] < hp_before and game.battle.energy == 2, "Native touch on highlighted enemy resolves card damage/energy")
	var hand_scroll = ui.content.find_child("HandScroll", true, false)
	check(hand_scroll != null, "Native touch hand provides a horizontal carousel")
	if hand_scroll != null:
		await swipe_hand(hand_scroll)
	var turn_before: int = game.battle.turn
	var unspent: int = game.battle.energy
	var end = find_button(ui, "End turn")
	if end != null:
		await tap_native(end)
	if unspent > 0:
		var confirm = TurnChecks.named(ui, "EndTurnAnyway")
		check(confirm is Button and game.battle.turn == turn_before and not ui.resolving_turn, "Native End turn with energy pauses for an explicit warning confirmation")
		if confirm != null: await tap_native(confirm)
	check(game.battle.turn == turn_before + 1, "Native touch ends turn through the visible control")
	ui.skip_turn_animation()
	await settle()
	await native_warning_and_core(Vector2i(375, 667))
	await native_warning_and_core(Vector2i(844, 320))
	ui.free()

func native_warning_and_core(pixels: Vector2i) -> void:
	current_size = pixels
	root.size = pixels
	game.new_run(730210)
	game.start_raid()
	ui.menu = "game"
	ui.card_index = 0
	ui.refresh()
	await settle()
	var before: String = JSON.stringify(game.battle.to_dict())
	var run_before: String = JSON.stringify(game.run)
	var turn_before: int = game.battle.turn
	await tap_native(TurnChecks.named(ui, "EndTurn"))
	check(TurnChecks.named(ui, "EndTurnWarning") != null and not ui.resolving_turn, "Real touch opens the unspent-energy warning at both portrait and short-landscape sizes")
	inspect_controls(ui, "native_unspent_energy_warning")
	var picture = root.get_texture().get_image()
	var destination: String = "res://tests/artifacts/mobile/%dx%d/native_unspent_energy_warning.png" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	check(picture.get_size() == pixels and picture.save_png(destination) == OK, "Native touch warning capture saves its exact logical viewport")
	captured += 1
	await tap_native(TurnChecks.named(ui, "KeepPlaying"))
	check(not is_instance_valid(ui.overlay) and ui.card_index == 0 and JSON.stringify(game.battle.to_dict()) == before and JSON.stringify(game.run) == run_before, "Real touch Keep playing preserves selection and every gameplay field")
	await tap_native(TurnChecks.named(ui, "CoreInfo"))
	check(TurnChecks.named(ui, "DungeonCoreInfo") != null, "Real touch opens Dungeon core explanation")
	inspect_controls(ui, "native_core_help")
	picture = root.get_texture().get_image()
	check(picture.get_size() == pixels and picture.save_png(destination.replace("native_unspent_energy_warning", "native_core_help")) == OK, "Native touch Core help capture saves its exact logical viewport")
	captured += 1
	await tap_native(TurnChecks.named(ui, "CloseCoreInfo"))
	check(JSON.stringify(game.battle.to_dict()) == before and ui.card_index == 0, "Real touch core help closes without changing battle or card selection")
	await tap_native(TurnChecks.named(ui, "EndTurn"))
	var confirm = TurnChecks.named(ui, "EndTurnAnyway")
	check(confirm is Button and game.battle.turn == turn_before, "A second deliberate end-turn request still requires an explicit choice")
	if confirm != null: await tap_native(confirm)
	check(game.battle.turn == turn_before + 1 and ui.resolving_turn and not is_instance_valid(ui.overlay), "Real touch End turn anyway commits one turn at both phone orientations")
	ui.skip_turn_animation()
	await settle()

func swipe_hand(sc: ScrollContainer) -> void:
	var selection_before: int = ui.card_index
	var last = sc.find_child("Card_%d" % (game.battle.hand.size() - 1), true, false)
	# Wider descriptive cards can require more than one ordinary finger swipe.
	for gesture in range(5):
		var start := sc.get_global_rect().position + Vector2(sc.size.x - 30, 35)
		await touch(start, true)
		for step in range(1, 10):
			var drag := InputEventScreenDrag.new()
			drag.window_id = root.get_window_id()
			drag.index = 0
			drag.position = start - Vector2(step * 30, 0)
			drag.relative = Vector2(-30, 0)
			Input.parse_input_event(drag)
			await process_frame
		await touch(start - Vector2(270, 0), false)
		await settle()
		if last != null and sc.get_global_rect().encloses(last.get_global_rect()): break
	check(ui.card_index == selection_before, "Dragging the hand does not accidentally select a card on release")
	check(sc.scroll_horizontal > 0, "ScreenDrag horizontally scrolls the real hand")
	check(last != null and sc.get_global_rect().encloses(last.get_global_rect()), "Finger drag reaches the last card in the hand")
	if last != null:
		await tap_native(last)
		check(ui.card_index == game.battle.hand.size() - 1, "Native touch selects the card reached by horizontal drag")
		if ui.card_index >= 0:
			var legal: Array = game.battle.legal_targets(game.battle.hand[ui.card_index])
			var energy_before: int = game.battle.energy
			var discard_before: int = game.battle.discard.size()
			if not legal.is_empty() and ui.actor_nodes.has(legal[0]):
				await tap_native(ui.actor_nodes[legal[0]])
			check(game.battle.energy < energy_before and game.battle.discard.size() == discard_before + 1, "Last card reached by finger drag resolves through a legal touch target")
