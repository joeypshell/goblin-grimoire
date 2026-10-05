extends SceneTree

# Exact logical native viewports; browser DPR is verified separately by root.
const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Combat = preload("res://scripts/battle.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Replay = preload("res://scripts/battle_replay.gd")
const Traits = preload("res://scripts/dungeon_traits.gd")
const SIZES = [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(375, 667), Vector2i(844, 320)]

var ui
var game
var surface: SubViewport
var pixels: Vector2i
var profile_root: String
var checks := 0
var captured := 0
var errors: Array = []
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/traits_ui_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/traits/")
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
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		await exercise_size()
		await exercise_combo()
	print("TRAIT SMOKE: %d assertions; %d %s; %d issues" % [checks, captured, "screenshots" if can_render else "layouts", errors.size()])
	for issue in errors: print("TRAIT ISSUE: ", issue)
	surface.free()
	quit(0 if errors.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append("%dx%d: %s" % [pixels.x, pixels.y, message])
		push_error(errors.back())

func equal(left, right) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func settle() -> void:
	for frame in range(8): await process_frame
	if can_render: await RenderingServer.frame_post_draw

func reset_game(tag: String) -> void:
	ui.skip_turn_animation()
	ui.close_modal()
	game = State.new(profile_root + "%dx%d/%s/" % [pixels.x, pixels.y, tag])
	game.new_run(730204)
	ui.state = game
	ui.menu = "game"
	ui.card_index = -1
	ui.last_action = ""
	ui.flow.delay_scale = 0
	ui.refresh()

func named(node: Node, id: String):
	if node.is_queued_for_deletion(): return null
	if node.name == id and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, id)
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
	check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(control.get_global_rect()), "Intended scrolling makes the action reachable inside the viewport")

func resolve_victory() -> void:
	# Phase fixtures complement the full campaigns played through real cards.
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	check(game.finish_feeding(), "Fixture reaches an earned trait using normal feeding completion")
	ui.card_index = -1
	ui.refresh()

func select_trait(id: String) -> void:
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	var choices: Array = game.trait_choices()
	for value in choices:
		check(named(ui, "TraitChoice_" + value) != null and named(ui, "TraitCompatibility_" + value) is Label, "Offered trait renders its actual rule and deck advice")
	var button = named(ui, "TraitSelect_" + id)
	check(button is Button and not button.disabled, "Named offered trait has an enabled production action: " + id)
	if button == null: return
	await reachable(button)
	check(button.size.y >= 43.9, "Trait selection uses a forty-four-pixel tap target")
	await capture("01a_pack_trait_action" if id == "pack_instinct" else "08a_second_trait_action")
	button.pressed.emit()
	await settle()
	check(game.run["traits"].back() == id and game.run["traits"].size() == before["traits"].size() + 1, "Trait button closure selects its own exact ID")
	check(game.rng.state == random_before and game.run["monsters"] == before["monsters"], "UI trait choice consumes no RNG or extra recovery")
	var loaded = State.new(game._prefix)
	check(loaded.load_game() and equal(loaded.run, game.run), "The chosen build and milestone persist through actual Continue")

func card(ability: String, owner: String, id: String) -> Dictionary:
	return {"id": id, "ability": ability, "owner": owner}

func show_enemies() -> void:
	var side = named(ui, "Side_enemies")
	if side != null: side.pressed.emit()
	await settle()

func exercise_size() -> void:
	reset_game("progression")
	game.start_raid()
	resolve_victory()
	var goblin: Dictionary = game.run["monsters"][0]
	# Explicit known-but-unequipped skill fixture for compatibility advice.
	goblin["learned"].append("poisoned_blade")
	goblin["consumed"].append("poisoned_blade")
	goblin["feeds"] = 1
	ui.refresh()
	await capture("01_first_trait_known_poison")
	var advice = named(ui, "TraitCompatibility_venom_nest")
	check(advice is Label and advice.text.contains("Poisoned Blade") and advice.text.contains(goblin["name"]) and advice.text.to_lower().contains("preparation") and not advice.text.to_lower().contains("future meals"), "Known unequipped poison recommends equipping the existing owner's skill next preparation")
	await select_trait("pack_instinct")
	await capture("02_first_trait_result")
	check(named(ui, "TraitSummary").text.contains("Pack Instinct"), "Result identifies the actual selected lasting build")
	game.continue_after_result()
	check(game.set_selected(goblin["id"], 0, "poisoned_blade"), "Next preparation can equip the known compatibility recommendation")
	ui.refresh()
	await capture("03_trait_preparation")
	check(ui.traits_screen.compatibility("venom_nest").contains("1 poison") and ui.traits_screen.compatibility("venom_nest").contains("Poisoned Blade"), "Compatibility updates from known skill to an actually equipped poison card")
	game.run["raid"] = 2
	game.run.erase("party")
	# High-HP actor fixture keeps all UI recipients alive through two warmup turns.
	for actor in game.run["monsters"]: actor["hp"] = 100; actor["max_hp"] = 100
	ui.refresh()
	await capture("04_captain_preparation")
	check(named(ui, "BannerWarning") != null and named(ui, "BannerWarning").text.contains("ALL monsters"), "Preparation explains the incoming Captain's every-third-round area attack")
	game.start_raid()
	game.end_turn()
	game.end_turn()
	ui.refresh()
	await show_enemies()
	await capture("05_announced_volley")
	var captain: Dictionary = game.battle.enemies[0]
	check(Copy.intent(game.battle, captain)["line"].contains("COUNTERPLAY"), "Third-round champion intent names an actionable counter")
	var shown_intent: String = named(ui, "Intent_" + captain["id"]).text + "\n" + named(ui, "DeckCounter").text
	check(shown_intent.contains("COUNTERPLAY") and shown_intent.contains("ALL monsters") and shown_intent.contains("5 damage"), "Visible champion labels retain numeric area damage and counterplay guidance")
	game.battle.hand = [card("snare_dungeon", "", "counterplay")]
	ui.card_index = -1
	ui.refresh()
	await settle()
	var counter = named(ui, "Card_0")
	await reachable(counter)
	counter.pressed.emit()
	await settle()
	await capture("06_selected_volley_counter")
	var target = ui.actor_nodes.get(captain["id"])
	check(target is Button, "Selected dungeon Snare exposes the actual Captain as a legal target")
	if target != null:
		await reachable(target)
		target.pressed.emit()
	await settle()
	await show_enemies()
	check(Copy.intent(game.battle, captain)["line"].contains("Banner Volley cancelled"), "Actual target press visibly cancels the announced volley")
	await capture("07_cancelled_volley")
	game.end_turn()
	check(captain["statuses"].get("resolve", 0) == 1, "Cancelled champion action grants real Resolve immunity")
	resolve_victory()
	await capture("08_second_trait_choice")
	check(game.run["raid"] == 3 and game.trait_choices().size() == 2 and not game.trait_choices().has("pack_instinct"), "Champion milestone offers only remaining trait rules")
	await select_trait("spiteful_shields")
	await capture("09_rank_e_two_trait_result")
	check(game.run["promotion"] == "E" and named(ui, "TraitSummary").text.contains("Spiteful Shields"), "Rank E result displays promotion and both selected build rules")
	game.continue_after_result()
	game.start_raid()
	var owners: Array = game.run["monsters"].map(func(m): return m["id"])
	game.battle.hand = [card("strike", owners[0], "pack_0"), card("strike", owners[1], "pack_1"), card("strike", owners[2], "pack_2")]
	var foe: String = game.battle.enemies[0]["id"]
	game.play_card(0, foe)
	game.play_card(0, foe)
	ui.card_index = -1
	ui.refresh()
	await capture("10_pack_two_owners")
	check(named(ui, "DeckCounter").text.contains("Pack 2/3"), "Visible combat progress counts two distinct owners")
	var before: Dictionary = game.battle.to_dict()
	var reload = State.new(game._prefix)
	check(reload.load_game() and equal(before, reload.battle.to_dict()), "UI fixture's partial combo is genuinely saved with hand and RNG")
	game = reload
	ui.state = game
	ui.refresh()
	await settle()
	var third = named(ui, "Card_0")
	await reachable(third)
	third.pressed.emit()
	await settle()
	var third_target = ui.actor_nodes.get(game.battle.enemies[2]["id"])
	check(third_target != null, "Reloaded third owner card retains legal targets")
	if third_target != null: third_target.pressed.emit()
	await capture("11_pack_complete_saved_combo")
	check(named(ui, "DeckCounter").text.contains("Pack 3/3 used") and game.battle.energy == 1, "Completing saved Pack progress visibly grants one energy and consumes the once-per-turn reward")
	check(ui.last_action.contains("Pack Instinct"), "Actual player feedback names the triggered dungeon trait")

func enemy(id: String, ability: String, hp: int) -> Dictionary:
	return {"id": id, "name": "Invader " + id, "class_name": "warrior", "form": "warrior", "hp": hp, "max_hp": hp, "abilities": [ability], "armor": 0, "block": 0, "statuses": {}}

func exercise_combo() -> void:
	reset_game("combo")
	game.run["traits"] = ["venom_nest", "spiteful_shields"]
	game.run["party"] = [enemy("combo0", "strike", 3), enemy("combo1", "guard", 40)]
	game.start_raid()
	game.battle.monsters[0]["block"] = 1
	game.battle._status(game.battle.enemies[0], "poison", 1)
	game.battle.intents = [{"enemy_id": "combo0", "ability": "strike", "target_id": game.run["monsters"][0]["id"], "text": "fixture"}, {"enemy_id": "combo1", "ability": "guard", "target_id": "combo1", "text": "fixture"}]
	var expected = Replay.make(game.battle)
	ui.flow.delay_scale = 1.0
	ui.refresh()
	ui.end_player_turn()
	var saw_combo := false
	for step in range(1000):
		if not ui.resolving_turn: break
		if ui.turn_stage == "enemy" and ui.acting_actor_id == "combo0" and ui.turn_detail != "" and not saw_combo:
			saw_combo = true
			check(ui.turn_detail.contains("Venom Nest") and ui.turn_detail.contains("Spiteful Shields"), "Enemy result feedback names both actual combo activations")
			await capture("12_retaliation_venom_activations")
		await create_timer(0.01).timeout
	check(saw_combo and not ui.resolving_turn and equal(expected.to_dict(), game.battle.to_dict()), "Visible trait replay completes at the ordinary authoritative result/RNG")
	ui.skip_turn_animation()
	await create_timer(0.8).timeout

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var path := "res://tests/artifacts/traits/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(path)
	if can_render: check(surface.get_texture().get_image().save_png(path + tag + ".png") == OK, "Native trait capture saved")
	else: check(surface.size == pixels, "Headless trait layout uses exact logical dimensions")
	captured += 1
	print("TRAIT CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

func inspect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is BaseButton):
		var vertical := false
		var horizontal := false
		var button
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is BaseButton and button == null: button = ancestor
			if ancestor is ScrollContainer:
				vertical = vertical or ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				horizontal = horizontal or ancestor.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		if not vertical and not horizontal: check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(rect), "Unscrolled trait/control label fits viewport: " + node.name)
		elif not horizontal: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Purposeful vertical scrolling never hides horizontal content: " + node.name)
		if button != null: check(button.get_global_rect().grow(1).encloses(rect), "Actor/card control contains its visible child label: %s label=%s button=%s" % [node.name, rect, button.get_global_rect()])
		if node is Button and str(node.name).begins_with("TraitSelect_"): check(node.size.y >= 43.9, "Every offered trait retains a forty-four-pixel logical tap target")
	for child in node.get_children(): inspect(child)
