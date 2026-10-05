extends SceneTree

# Render production scenes and use real card actions. Catalog-only hand fixtures
# are kept separate from the ordinary seeded raid used for input/mechanics.
const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Combat = preload("res://scripts/battle.gd")
const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Preferences = preload("res://scripts/ui_preferences.gd")
const CombatChecks = preload("res://tests/ui_combat_checks.gd")
const BalanceChecks = preload("res://tests/balance_ui_checks.gd")
const SIZES = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1920, 900), Vector2i(1024, 768), Vector2i(1050, 640), Vector2i(390, 844), Vector2i(375, 667), Vector2i(844, 320)]

var ui
var game
var surface: SubViewport
var pixels: Vector2i
var checks := 0
var captured := 0
var errors: Array = []
var profile_root: String
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/art_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/art/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	surface = SubViewport.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.gui_embed_subwindows = true
	surface.size = SIZES[0]
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root), "Scene startup preserves its explicitly isolated verification profile")
	await test_stage_layout_stability()
	for size_ in SIZES:
		await test_size(size_)
	await test_motion_and_save()
	print("ART SMOKE: %d assertions; %d %s; %d issues" % [checks, captured, "screenshots" if can_render else "layouts", errors.size()])
	for issue in errors: print("ART ISSUE: ", issue)
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
	game = State.new(profile_root + tag + "/")
	game.new_run(730204)
	game.start_raid()
	ui.state = game
	ui.menu = "game"
	ui.card_index = -1
	ui.last_action = ""
	ui.refresh()

func named(node: Node, name_: String):
	if node.name == name_ and not node.is_queued_for_deletion() and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, name_)
		if found != null: return found
	return null

func clone(battle):
	var saved: Dictionary = battle.to_dict()
	var result = Combat.new()
	result.restore(saved, saved["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	return result

func test_stage_layout_stability() -> void:
	# Card faces acquire their minimum sizes during deferred layout. A stage's
	# allocated height must never feed back into its parent's minimum height.
	pixels = Vector2i(1280, 720)
	surface.size = pixels
	reset_game("deferred_layout")
	var before: Dictionary = game.battle.to_dict()
	for size_ in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		pixels = size_
		surface.size = pixels
		await settle()
		var holder = named(ui, "BattlefieldHolder")
		check(holder != null and is_instance_valid(ui.battlefield), "Resized desktop retains its battlefield allocation holder")
		if holder == null or not is_instance_valid(ui.battlefield): return
		var minimum: Vector2 = holder.get_combined_minimum_size()
		var geometry: Rect2 = ui.battlefield.get_global_rect()
		check(is_equal_approx(holder.custom_minimum_size.y, 140) and is_equal_approx(minimum.y, 140), "Battlefield parent keeps its fixed 140-pixel minimum after card layout")
		check(holder.get_global_rect().grow(1).encloses(geometry) and geometry.size.y <= 360.1, "Stage fits allocated space and respects its large-screen height cap")
		for index in range(game.battle.hand.size()):
			var face = named(ui, "Card_%d" % index)
			check(face != null and Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(face.get_global_rect()), "Deferred card faces remain fully inside the resized desktop")
		var end = named(ui, "EndTurn")
		check(end != null and Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(end.get_global_rect()), "Deferred card layout retains the visible end-turn action")
		await settle()
		check(minimum.is_equal_approx(holder.get_combined_minimum_size()) and geometry.is_equal_approx(ui.battlefield.get_global_rect()), "Another deferred layout pass cannot grow the minimum or move the stage")
		check(equal(before, game.battle.to_dict()), "Desktop resizing and deferred layout preserve combat and RNG")

func test_size(size_: Vector2i) -> void:
	pixels = size_
	surface.size = pixels
	reset_game("%dx%d" % [pixels.x, pixels.y])
	await capture("01_baseline")
	inspect_cards()
	if is_instance_valid(ui.battlefield): inspect_battlefield()
	elif pixels.x >= 900 and pixels.y >= 560 and pixels.x > pixels.y: check(false, "Desktop/tablet landscape presents the actual battlefield")
	var strike_index := -1
	for index in range(game.battle.hand.size()):
		if game.battle.hand[index]["ability"] == "strike":
			strike_index = index
			break
	check(strike_index >= 0, "Ordinary seeded hand has a real targeted attack")
	if strike_index < 0: return
	var before: Dictionary = game.battle.to_dict()
	var strike = named(ui, "Card_%d" % strike_index)
	check(strike != null and not strike.disabled, "Illustrated real attack remains an enabled card")
	if strike == null: return
	if pixels == Vector2i(1280, 720):
		var rect: Rect2 = strike.get_global_rect()
		strike.mouse_entered.emit()
		await create_timer(0.2).timeout
		check(rect == strike.get_global_rect() and equal(before, game.battle.to_dict()), "Card hover preserves its target rectangle and combat/RNG")
		strike.mouse_exited.emit()
	strike.pressed.emit()
	await settle()
	check(ui.card_index == strike_index and equal(before, game.battle.to_dict()), "Selecting an illustrated card preserves battle and RNG")
	await capture("02_selected_attack")
	inspect_cards()
	var target_id: String = game.battle.enemies[0]["id"]
	var target = ui.actor_nodes.get(target_id)
	check(target != null, "Illustrated selected attack exposes its legal target")
	if target == null: return
	var expected = clone(game.battle)
	check(expected.play_card(strike_index, target_id), "Ordinary simulation accepts the illustrated action")
	target.pressed.emit()
	check(equal(expected.to_dict(), game.battle.to_dict()), "Target click commits exactly the ordinary card result before animation")
	check(before["rng_state"] == game.battle.to_dict()["rng_state"], "Targeted card art/action does not consume random numbers")
	await create_timer(0.12).timeout
	await capture("03_player_action")
	var committed: Dictionary = game.battle.to_dict()
	await create_timer(0.7).timeout
	check(equal(committed, game.battle.to_dict()), "Cosmetic action and idle animation cannot mutate full combat or RNG")
	# Explicit long-text/category fixture, independent of real action verification.
	var owner: String = game.run["monsters"][0]["id"]
	game.battle.hand = [fixture_card("spirit_flame", owner), fixture_card("regrowth", owner), fixture_card("rally", ""), fixture_card("poisoned_blade", owner), fixture_card("mend", owner)]
	game.battle.energy = 3
	ui.card_index = -1
	ui.refresh()
	await capture("04_card_categories")
	inspect_cards()
	if pixels in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await test_selected_statuses()
	game.battle.energy = 0
	ui.refresh()
	await capture("05_disabled_cards")
	inspect_cards()
	if pixels.x > pixels.y and pixels.y < 440:
		await scroll_to_card()
		await capture("05_disabled_landscape_hand")
	await BalanceChecks.new().exercise(self, pixels)
	if pixels == Vector2i(1920, 1080): await test_lineage_visuals()

func scroll_to_card() -> void:
	var card = named(ui, "Card_0")
	if card == null: return
	var before: Dictionary = game.battle.to_dict()
	var ancestor = card.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(card)
			await settle()
		ancestor = ancestor.get_parent()
	check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(card.get_global_rect()), "Landscape illustrated hand is reachable by its intended scrolling")
	check(equal(before, game.battle.to_dict()), "Reaching illustrated hand does not alter combat/RNG")

func fixture_card(ability: String, owner: String) -> Dictionary:
	return {"id": "art_" + ability, "ability": ability, "owner": owner}

func numerical(text_: String) -> bool:
	for digit in range(10):
		if text_.contains(str(digit)): return true
	return false

func test_selected_statuses() -> void:
	for monster in game.run["monsters"]:
		monster["statuses"] = {}
		monster["status_layers"] = {}
		for status_id in ["poison", "burn", "regen"]: game.battle._status(monster, status_id, 1 if status_id == "burn" else 2)
	ui.card_index = 1
	ui.refresh()
	await capture("04_selected_regrowth_statuses")
	inspect_cards()
	inspect_battlefield()
	ui.card_index = 0
	ui.refresh()
	await capture("04_selected_area_targets")
	inspect_cards()
	inspect_battlefield()
	ui.card_index = -1

func test_lineage_visuals() -> void:
	# These are explicit art fixtures, not unlocked discoveries or game rewards.
	for forms in [["red_ogre", "basilisk", "shadow_stalker"], ["green_ogre", "oni", "ember_basilisk"], ["ancient_ogre", "nightstalker", "goblin"]]:
		for index in range(forms.size()):
			var monster: Dictionary = game.run["monsters"][index]
			monster["form"] = forms[index]
			monster["max_hp"] = Data.FORMS[forms[index]]["max_hp"]
			monster["hp"] = monster["max_hp"]
		ui.refresh()
		await capture("06_lineages_" + forms[0])
		inspect_battlefield()

func inspect_cards() -> void:
	for index in range(game.battle.hand.size()):
		var card = named(ui, "Card_%d" % index)
		check(card != null, "Every hand card has a rendered illustrated control")
		if card == null: continue
		var definition: Dictionary = Data.ABILITIES[game.battle.hand[index]["ability"]]
		for field in ["CardOwner", "CardCost", "CardTitle", "CardEffect"]:
			var label_ = named(card, field)
			check(label_ != null and not label_.text.is_empty(), "Illustrated card visibly renders " + field)
			if label_ != null: check(card.get_global_rect().grow(1).encloses(label_.get_global_rect()), "Illustrated card contains " + field + " " + definition["name"])
		var art = named(card, "CardArt")
		check(art != null and art.texture != null, "Illustrated card has a real loaded texture")
		var title = named(card, "CardTitle")
		var cost = named(card, "CardCost")
		var owner = named(card, "CardOwner")
		var effect = named(card, "CardEffect")
		if title != null: check(title.text == definition["name"], "Card title agrees with actual ability")
		if cost != null: check(cost.text.contains(str(definition["cost"])), "Card cost agrees with actual energy cost")
		if owner != null:
			var source: String = game.battle.hand[index]["owner"]
			check(owner.text.contains("Dungeon") or owner.text.contains("dungeon") if source == "" else owner.text.contains(game.battle.get_actor(source)["name"]), "Card owner agrees with actual source")
		if effect != null and game.battle.energy > 0:
			check(numerical(effect.text), "Card effect remains numerical even when selected")
		check(card.disabled == (Copy.unavailable(game.battle, game.battle.hand[index]) != ""), "Illustrated card keeps normal availability rules")

func inspect_battlefield() -> void:
	check(is_instance_valid(ui.battlefield), "Desktop has the actual battlefield control")
	if not is_instance_valid(ui.battlefield): return
	for actor in game.battle.monsters + game.battle.enemies:
		var unit = named(ui.battlefield, "Creature_" + actor["id"])
		check(unit != null, "Battlefield displays full-body creature " + actor["id"])
		if unit != null:
			check(ui.battlefield.get_global_rect().grow(1).encloses(unit.get_global_rect()), "Full creature fits inside desktop battlefield")
	for actor in game.battle.enemies:
		var intent = named(ui.battlefield, "Intent_" + actor["id"])
		check(intent != null and numerical(intent.text), "Every invader has visible numerical intent")
		if intent != null: check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(intent.get_global_rect()), "Invader intent fits desktop viewport")

func test_motion_and_save() -> void:
	pixels = Vector2i(1920, 1080)
	surface.size = pixels
	reset_game("motion")
	await settle()
	check(ui.has_method("animations_enabled"), "Presentation exposes reduced-motion behavior")
	if not ui.has_method("animations_enabled"): return
	# The public preference is used, not a test-only animation bypass.
	var before: Dictionary = game.battle.to_dict()
	ui.set_reduced_motion(true, true)
	check(not ui.animations_enabled(), "Reduced motion disables movement through the production preference")
	check(Preferences.read_motion(game._prefix), "Reduced-motion preference persists in the isolated profile")
	var saved = State.new(game._prefix)
	check(saved.load_game() and equal(before, saved.battle.to_dict()), "Saving motion preference preserves the separately saved run/RNG")
	await settle()
	var offsets := motion_offsets()
	var creature = named(ui.battlefield, "Creature_" + game.run["monsters"][0]["id"])
	if creature != null:
		creature.attack()
		creature.react("hit")
	await create_timer(0.25).timeout
	check(equal(offsets, motion_offsets()), "Reduced-motion idle, lunge and hit reactions have stable drawing transforms")
	check(equal(before, game.battle.to_dict()), "Reduced-motion preference and rendering preserve combat/RNG")
	await capture("06_reduced_motion")
	ui.set_reduced_motion(false, true)
	check(ui.animations_enabled(), "Movement can be enabled through the production preference")
	check(not Preferences.read_motion(game._prefix), "Restoring movement persists the opposite preference")
	await settle()
	creature = named(ui.battlefield, "Creature_" + game.run["monsters"][0]["id"])
	if creature != null:
		creature.attack()
		await create_timer(0.1).timeout
		check(absf(creature.motion_offset().x) > 1, "Enabled creature lunge actually changes its drawing transform")
		check(equal(before, game.battle.to_dict()), "Actual enabled movement remains cosmetic")
		await create_timer(0.35).timeout
	ui.flow.delay_scale = 1.0
	ui.end_player_turn()
	var committed: Dictionary = game.battle.to_dict()
	var reload = State.new(profile_root + "motion/")
	check(reload.load_game() and equal(committed, reload.battle.to_dict()), "Reload during illustrated enemy presentation restores committed state")
	ui.skip_turn_animation()
	await settle()
	await create_timer(0.7).timeout
	check(not ui.resolving_turn and equal(committed, game.battle.to_dict()), "Skipping illustrated turn cancels visuals without executing effects again")
	await capture("07_after_skip")

func motion_offsets() -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(ui.battlefield): return result
	for actor in game.battle.monsters + game.battle.enemies:
		var unit = named(ui.battlefield, "Creature_" + actor["id"])
		check(unit != null and unit.has_method("motion_offset"), "Creature exposes its real drawing movement transform")
		if unit != null and unit.has_method("motion_offset"): result[actor["id"]] = str(unit.motion_offset())
	return result

func capture(tag: String) -> void:
	await settle()
	CombatChecks.defenses(self, ui)
	if is_instance_valid(ui.battlefield): inspect_stage_labels(ui.battlefield)
	var path := "res://tests/artifacts/art/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(path)
	if can_render:
		check(surface.get_texture().get_image().save_png(path + tag + ".png") == OK, "Native illustrated scene capture saved")
	else:
		check(surface.size == pixels, "Headless illustrated layout uses exact logical dimensions")
	captured += 1
	print("ART CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

func inspect_stage_labels(node: Node) -> void:
	if node is Control and node.has_method("motion_offset"):
		check(node.size.y >= 59.9, "Full-body creature remains at least60logical pixels tall, including selected states")
	if node is Label and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(rect), "Battlefield label fits viewport: " + node.text.left(65))
		var ancestor = node.get_parent()
		while ancestor != null and not ancestor is BaseButton: ancestor = ancestor.get_parent()
		if ancestor != null: check(ancestor.get_global_rect().grow(1).encloses(rect), "Battlefield unit contains its name/HP/intent/status/preview: " + node.text.left(65))
	for child in node.get_children(): inspect_stage_labels(child)
