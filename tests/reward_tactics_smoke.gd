extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Combat = preload("res://scripts/battle.gd")
const Data = preload("res://scripts/game_data.gd")
const Tactics = preload("res://scripts/invader_tactics.gd")
const SIZES = [Vector2i(1280, 720), Vector2i(375, 667), Vector2i(390, 844), Vector2i(844, 320)]

var ui
var game
var surface: SubViewport
var pixels := Vector2i.ZERO
var profile_root: String
var checks := 0
var captures := 0
var failures: Array = []
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/reward_tactics_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/reward_tactics/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	surface = SubViewport.new()
	surface.size = SIZES[0]
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Reward UI and uploader retain an isolated bootstrap profile")
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		await test_equip(0)
		await test_equip(1)
		await test_latest_and_legacy()
		await test_form_information()
	print("REWARD TACTICS SMOKE: %d assertions; %d %s; %d issues" % [checks, captures, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("REWARD TACTICS ISSUE: ", failure)
	ui.free()
	surface.free()
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%dx%d: %s" % [pixels.x, pixels.y, message])
		push_error(failures.back())

func equal(left, right) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func settle() -> void:
	for frame in range(8): await process_frame
	if can_render: await RenderingServer.frame_post_draw

func reset_feeding(tag: String) -> void:
	ui.skip_turn_animation()
	ui.close_modal()
	game = State.new(profile_root + "%dx%d/%s/" % [pixels.x, pixels.y, tag])
	game.new_run(730210)
	game.start_raid()
	# Earn the ordinary feeding transition; focused UI fixtures complement campaigns.
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()
	check(game.run["phase"] == "feeding", "Won battle opens real corpse rewards")
	ui.state = game
	ui.menu = "game"
	ui.feed_body = 0
	ui.feed_monster = game.run["monsters"][0]["id"]
	ui.card_index = -1
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
	if (node is Label or node is Button) and node.is_visible_in_tree(): result += node.text + "\n"
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

func detail_matches(recipient: Dictionary, body: Dictionary) -> void:
	var id: String = body["taken"]
	var detail = named(ui, "InheritedSkillDetail")
	check(detail is Label and detail.text.contains(recipient["name"]) and detail.text.contains(Data.ABILITIES[id]["name"]) and detail.text.contains("%d energy" % Data.ABILITIES[id]["cost"]) and detail.text.contains(Data.ABILITIES[id]["description"]), "Receipt identifies actual inherited owner, skill, cost and numeric effects")
	var receipt = named(ui, "InheritedResult")
	check(receipt is Label and receipt.text.contains(body["name"]) and receipt.text.contains(recipient["name"]), "Original persistent inheritance result and body identity remain intact")

func deck_matches(recipient: Dictionary, inherited: String) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = game.rng.seed
	random.state = game.rng.state
	var simulation = Combat.new()
	simulation.setup(game.run["monsters"].duplicate(true), game.run["party"].duplicate(true), random, game.run.get("traits", []))
	var deck: Array = simulation.hand + simulation.draw_pile + simulation.discard
	check(deck.size() == 12 and recipient["selected"].size() == 2 and recipient["selected"][0] != recipient["selected"][1], "Equipment retains two distinct slots and the twelve-card next deck")
	check(deck.filter(func(card): return card["owner"] == recipient["id"] and card["ability"] == inherited).size() == 1, "Next deck contains exactly one chosen owned inherited card")

func test_equip(slot: int) -> void:
	reset_feeding("equip_%d" % slot)
	await settle()
	var recipient: Dictionary = game.run["monsters"][0]
	var selected: Array = recipient["selected"].duplicate()
	var devour = named(ui, "DevourBody")
	check(devour is Button and not devour.disabled, "Production devour action is ready")
	if devour == null: return
	await reachable(devour)
	devour.pressed.emit()
	await settle()
	var body: Dictionary = game.run["rewards"][0]
	check(body.get("claimed", false) and body.has("taken") and recipient["selected"] == selected, "Devouring rolls an actual new skill without automatically equipping it")
	if not body.has("taken"): return
	check(game.run.get("last_meal", {}) == {"body": 0, "recipient": recipient["id"], "ability": body["taken"]}, "Valid devour records its exact persistent latest meal")
	detail_matches(recipient, body)
	var status = named(ui, "InheritedEquipStatus")
	check(status is Label and status.text.contains("Not in the next deck yet") and status.text.contains("replace"), "Receipt clearly explains the new skill still needs an equipment choice")
	for other_slot in range(2):
		var replace = named(ui, "EquipInherited_%d" % other_slot)
		check(replace is Button and not replace.disabled and replace.text == "Replace " + Data.ABILITIES[selected[other_slot]]["name"], "Both replacement controls name the exact skill they replace")
		if replace != null: await reachable(replace)
	if slot == 0: await capture("01_new_skill_awaits_equipment")
	var random_before: int = game.rng.state
	var feeds_before: int = recipient["feeds"]
	var learned_before: Array = recipient["learned"].duplicate()
	var replace = named(ui, "EquipInherited_%d" % slot)
	if replace != null: replace.pressed.emit()
	await settle()
	check(recipient["selected"][slot] == body["taken"] and recipient["selected"][1 - slot] == selected[1 - slot], "Replacement control updates only its exact selected skill slot")
	check(game.rng.state == random_before and recipient["learned"] == learned_before and recipient["feeds"] == feeds_before, "Equipment selection cannot reroll inheritance, duplicate a meal or alter known skills")
	status = named(ui, "InheritedEquipStatus")
	check(status is Label and status.text.contains("EQUIPPED") and status.text.contains("slot %d" % (slot + 1)) and named(ui, "EquipInherited_0") == null and named(ui, "EquipInherited_1") == null, "Equipped receipt visibly marks the correct slot and removes redundant replacement actions")
	detail_matches(recipient, body)
	deck_matches(recipient, body["taken"])
	var loaded = State.new(game._prefix)
	check(loaded.load_game() and loaded.get_monster(recipient["id"])["selected"] == recipient["selected"] and equal(loaded.run.get("last_meal", {}), game.run.get("last_meal", {})), "Continue preserves the equipment choice and exact latest-meal receipt")
	game = loaded
	ui.state = game
	ui.refresh()
	await settle()
	check(named(ui, "InheritedEquipStatus").text.contains("EQUIPPED"), "Continued receipt still shows that the inherited card is equipped")
	if slot == 0: await capture("02_equipped_and_continued")
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	check(game.finish_feeding() and not game.run.has("last_meal"), "Feeding completion clears only the obsolete latest-meal pointer")

func test_latest_and_legacy() -> void:
	reset_feeding("latest_and_legacy")
	check(game.claim_body(2, game.run["monsters"][1]["id"]), "Later-index body supplies a legitimate first meal")
	check(game.claim_body(1, game.run["monsters"][2]["id"]), "Lower-index body supplies a legitimate later meal")
	ui.refresh()
	await settle()
	detail_matches(game.run["monsters"][2], game.run["rewards"][1])
	var result = named(ui, "InheritedResult")
	for index in [1, 2]: check(result.text.contains(game.run["rewards"][index]["name"]) and result.text.contains(Data.ABILITIES[game.run["rewards"][index]["taken"]]["name"]), "Receipt retains every original inherited result despite newest-meal focus")
	await capture("03_latest_meal_chronology")
	game.run.erase("last_meal")
	game.save_game()
	var loaded = State.new(game._prefix)
	check(loaded.load_game(), "Older receipt save without a last-meal pointer remains continuable")
	game = loaded
	ui.state = game
	ui.refresh()
	await settle()
	detail_matches(game.run["monsters"][1], game.run["rewards"][2])
	check(named(ui, "EquipInherited_0") != null and named(ui, "EquipInherited_1") != null, "Old-save fallback still offers only valid actual inherited skill replacements")
	await capture("04_legacy_receipt_fallback")

func test_form_information() -> void:
	reset_feeding("earned_form")
	var recipient: Dictionary = game.run["monsters"][0]
	# Explicit earned lineage fixture: no unearned form is advertised.
	for ability in ["heavy_blow", "firebolt"]:
		if not recipient["learned"].has(ability): recipient["learned"].append(ability)
		if not recipient["consumed"].has(ability): recipient["consumed"].append(ability)
	recipient["feeds"] = 2
	recipient["hp"] = recipient["max_hp"] - 5
	game.run["evolution_budget"] = 1
	game.save_game()
	ui.refresh()
	var eligible: Array = game.eligible(recipient["id"])
	check(eligible.size() == 1 and eligible[0]["result"] == "red_ogre", "Known consumed affinities earn only the intended form")
	var selected: Array = recipient["selected"].duplicate()
	var learned: Array = recipient["learned"].duplicate()
	var random_before: int = game.rng.state
	ui.screens.evolution_choices(recipient)
	await settle()
	var definition: Dictionary = Data.FORMS["red_ogre"]
	var signature: Dictionary = Data.ABILITIES[definition["signature"]]
	check(named(ui, "FormChoiceHealth_red_ogre").text.contains(str(definition["max_hp"])), "Earned chooser previews the new maximum HP before the decision")
	check(named(ui, "FormChoiceSignature_red_ogre").text.contains(signature["description"]) and named(ui, "FormChoiceSignature_red_ogre").text.contains("%d energy" % signature["cost"]), "Earned chooser previews the signature's actual cost and numerical effect")
	check_tactic("red_ogre", "FormTacticChoice_red_ogre")
	hidden_forms_stay_hidden(ui.overlay, ["goblin", "red_ogre"])
	var evolve = named(ui, "EvolveForm_red_ogre")
	check(evolve is Button and not evolve.disabled, "Earned form has its actual production evolution action")
	if evolve == null: return
	await reachable(evolve)
	await capture("05_earned_form_power_preview")
	evolve.pressed.emit()
	await settle()
	check(recipient["form"] == "red_ogre" and recipient["selected"] == selected and recipient["learned"] == learned and game.rng.state == random_before, "Form evolution preserves selected owned skills, learned skills and campaign RNG")
	check(named(ui, "FormRevealHealth").text == "New health: %d / %d HP" % [recipient["hp"], recipient["max_hp"]], "Reveal names the actual health after percentage-preserving transformation")
	check(named(ui, "FormRevealSignatureEffect").text == signature["description"], "Reveal explains the new signature's actual numeric effect")
	check_tactic("red_ogre", "FormTacticReveal_red_ogre")
	hidden_forms_stay_hidden(ui.overlay, ["goblin", "red_ogre"])
	var welcome = action(ui, "Welcome the transformation")
	if welcome != null: await reachable(welcome)
	await capture("06_transformation_power_reveal")
	ui.close_modal()
	await settle()
	check_tactic("red_ogre", "FormTacticFeeding_" + recipient["id"])
	ui.menu = "grimoire"
	ui.refresh()
	await settle()
	check_tactic("red_ogre", "FormTacticGrimoire_red_ogre")
	hidden_forms_stay_hidden(ui.content, ["goblin", "red_ogre"])
	await capture("07_discovered_form_tactics")
	ui.menu = "game"
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	check(game.finish_feeding(), "Form fixture finishes normal earned recovery")
	if game.run["phase"] == "trait": game.choose_trait(game.trait_choices()[0])
	game.continue_after_result()
	ui.refresh()
	await settle()
	check(game.run["phase"] == "prep", "Recovered evolved team returns to next preparation")
	check_tactic("red_ogre", "FormTacticPreparation_" + recipient["id"])
	for actor in game.party_preview():
		var description: String = Tactics.description(actor)
		var role = named(ui, "IncomingTactic_" + actor["id"])
		check((role is Label and role.text == description) if description != "" else role == null, "Preparation shows only the incoming actor's actual enabled tactical role")
	check(recipient["selected"] == selected and recipient["learned"] == learned, "Recovery and next preparation retain the player's original skill choices")
	await capture("08_next_preparation_form_and_roles")

func check_tactic(form: String, id: String) -> void:
	var expected: String = Data.FORMS[form].get("tactic", "")
	var label = named(ui, id)
	check((label is Label and label.text == "PLAYSTYLE / " + expected) if expected != "" else label == null, "Visible form advice uses that earned or discovered form's actual playstyle: " + id)

func hidden_forms_stay_hidden(node: Node, allowed: Array) -> void:
	var text: String = visible_text(node)
	for form in Data.FORMS:
		if form not in allowed: check(not text.contains(Data.FORMS[form]["name"]), "Unearned undiscovered form remains hidden: " + form)

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var destination := "res://tests/artifacts/reward_tactics/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(destination)
	if can_render:
		var picture = surface.get_texture().get_image()
		check(picture.get_size() == pixels and picture.save_png(destination + tag + ".png") == OK, "Native reward/tactic screenshot has exact logical dimensions")
	else: check(surface.size == pixels, "Headless reward/tactic layout has exact logical dimensions")
	captures += 1
	print("REWARD TACTICS CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

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
		if not horizontal: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Reward/form content fits horizontal bounds: " + node.name)
		if not vertical: check(rect.position.y >= -1 and rect.end.y <= pixels.y + 1, "Unscrolled reward/form control fits vertical bounds: " + node.name)
		if owner_button != null: check(owner_button.get_global_rect().grow(1).encloses(rect), "Reward/form control contains its visible label: " + node.name)
	for child in node.get_children(): inspect(child)
