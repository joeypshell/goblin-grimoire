extends "res://tests/tactical_ui_smoke.gd"

# Exercise the production choice, target and result controls on isolated profiles.
const Feedback = preload("res://scripts/combat_feedback.gd")
const OfferChecks = preload("res://tests/trait_offer_ui_checks.gd")
const LootChecks = preload("res://tests/loot_ui_checks.gd")
const Traits = preload("res://scripts/dungeon_traits.gd")

func _run() -> void:
	profile_root = "user://verification/slice_ui_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/tactical_ui/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	surface = SubViewport.new()
	surface.size = SIZES[0]
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Slice UI and uploader retain an isolated verification profile")
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		await test_trait_choices()
		await test_encounter_rules()
		await test_stored_protection()
	print("SLICE UI SMOKE: %d assertions; %d %s; %d issues" % [checks, captures, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("SLICE UI ISSUE: ", failure)
	ui.free()
	surface.free()
	# AudioServer retires stopped music playback references on its next mix callback.
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)

func test_trait_choices() -> void:
	reset_game("war_drums_choice", 1)
	var seed_value: int = OfferChecks.seed_for(["war_drums"])
	check(seed_value != 0, "War Drums advice fixture uses a seed that actually offers War Drums")
	if seed_value == 0: return
	game.new_run(seed_value)
	game.start_raid()
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()
	check(game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding" and game.run["raid"] == 0, "First raid victory opens its actual trait before feeding")
	ui.refresh()
	await settle()
	check(game.trait_choices().size() == 2, "First trait reward offers exactly two distinct saved build choices")
	for id in game.trait_choices():
		var choose = named(ui, "TraitSelect_" + id)
		check(choose is Button and not choose.disabled, "Available trait has an enabled production choice: " + id)
		await reachable(choose)
	var compatibility = named(ui, "TraitCompatibility_war_drums")
	check(compatibility is Label and compatibility.text.contains("READY NOW") and compatibility.text.contains("Guard") and compatibility.text.contains("another monster") and compatibility.text.contains("1 energy") and compatibility.text.contains("draw 1"), "War Drums explains an immediate, affordable teammate Guard payoff")
	check(not visible_text().contains("Green Ogre") and not visible_text().contains("Ancient Ogre"), "First trait reward reveals no undiscovered form names")
	check(named(ui, "TraitOfferSummary").text.contains("two offers") and named(ui, "TraitOfferSummary").text.contains("Continue"), "The first reward explains its two saved offers without exposing other options")
	await capture("slice_01_two_saved_trait_offers")
	var choose = named(ui, "TraitSelect_war_drums")
	await reachable(choose)
	choose.pressed.emit()
	await settle()
	check(game.run["traits"] == ["war_drums"] and game.run["phase"] == "feeding", "Production trait press activates the actually offered War Drums before the meal")
	check(named(ui, "TraitSummary").text.contains("War Drums") and named(ui, "TraitMilestone") == null and not visible_text().contains("choose your first dungeon trait"), "Feeding displays the chosen build and never promises its first trait again")
	check(LootChecks.skip_draft(self, game), "Trait slice explicitly skips its actual spell draft")
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	check(game.finish_feeding() and game.run["phase"] == "result", "Meal completion reaches recovery without awarding another first trait")
	game.continue_after_result()
	ui.refresh()
	await settle()
	check(named(ui, "TraitSummary").text.contains("Protect a teammate"), "Preparation reminds players what their chosen build rewards")
	game.run["raid"] = 3
	game.run.erase("party")
	game.party_preview()
	check(game._open_trait_reward("prep"), "F champion reward opens the second actual trait choice")
	ui.refresh()
	await settle()
	check(game.trait_choices().size() == Traits.DEFINITIONS.size() - 1 and named(ui, "TraitSelect_war_drums") == null and visible_text().contains("first trait stays active"), "Second reward keeps the active trait and explains every remaining alternative")
	await capture("slice_02_second_trait_choices")

func test_encounter_rules() -> void:
	reset_game("raid_two_rules", 1)
	await settle()
	var options: Array = game.party_choices()
	check(options.size() == 2, "Raid two offers the actual Ward and Ritual parties")
	var alternate_id: String = ""
	for option in options:
		for actor in option["party"]:
			var rule_id: String = actor.get("encounter_rule", "")
			if rule_id == "": continue
			var rule = named(ui, "PartyRule_" + option["id"] + "_" + actor["id"])
			check(rule is Label and rule.text == Data.encounter_rule_text(actor), "Party card exposes its actual encounter rule in normal scroll content")
			if rule_id == "ward_captain": check(rule.text.contains("4 Block") and rule.text.contains("survive") and rule.text.contains("Finish the captain"), "Ward Captain explains both the consequence and lethal counter")
			if rule_id == "ritual_priest":
				alternate_id = option["id"]
				check(rule.text.contains("9 HP") and rule.text.contains("2, 5, 8") and rule.text.contains("Stun"), "Ritual party explains its numeric healing rhythm and interrupt")
	await capture("slice_03_raid_two_choices")
	check(alternate_id != "", "Alternate party actually contains the Ritual Priest")
	game.run["monsters"][0]["form"] = "green_ogre"
	game.run["traits"] = ["war_drums"]
	game.start_raid()
	var owner: Dictionary = game.battle.monsters[0]
	var captain: Dictionary = {}
	for actor in game.battle.enemies:
		actor["hp"] = 100
		actor["max_hp"] = 100
		if actor.get("encounter_rule", "") == "ward_captain": captain = actor
	game.battle.hand = [card("guard", owner["id"], "ward_protect"), card("strike", owner["id"], "ward_attack")]
	ui.refresh()
	await settle()
	await choose_card(0)
	await play_target(game.battle.monsters[1]["id"])
	await capture("slice_04_ward_with_stored_bulwark")
	await choose_card(0)
	var before: Dictionary = game.battle.to_dict()
	var forecast: String = Copy.preview(game.battle, game.battle.hand[0], captain)
	check(forecast.contains("+4 Block after the attack") and forecast.contains("includes +10 damage"), "A charged attack previews both its stronger hit and the actual Ward reinforcement recipient")
	check(equal(before, game.battle.to_dict()), "Ward reinforcement forecasting preserves all battle and RNG fields")
	await capture("slice_05_ward_actual_attack_forecast")
	await play_target(captain["id"])
	check(game.battle.enemies.any(func(actor): return actor["id"] != captain["id"] and int(actor["block"]) == 4), "Actual nonlethal captain attack reinforces the announced other invader")
	reset_game("ritual_party_selection", 1)
	await settle()
	var choose = named(ui, "PartySelect_" + alternate_id)
	await reachable(choose)
	choose.pressed.emit()
	await settle()
	check(game.run["party_choice"] == alternate_id, "Production party press selects the Ritual encounter")
	game.start_raid()
	var priest: Dictionary = {}
	for actor in game.battle.enemies:
		actor["hp"] = 100
		actor["max_hp"] = 100
		if actor.get("encounter_rule", "") == "ritual_priest": priest = actor
	for actor in game.battle.enemies:
		if actor["id"] != priest["id"]:
			actor["hp"] = 70
			break
	game.end_turn()
	ui.refresh()
	await settle()
	var side = named(ui, "Side_enemies")
	if side != null: side.pressed.emit()
	await settle()
	var announced: Dictionary = Copy.intent(game.battle, priest)
	check(announced["line"].contains("Renewal Ritual") and announced["line"].contains("Heal 9") and announced["line"].contains("COUNTERPLAY"), "Actual locked round-two ritual visibly announces its nine-HP heal and counterplay")
	check(visible_text().contains("Renewal Ritual") and visible_text().contains("9"), "Desktop and phone combat expose the actual healing action")
	await capture("slice_06_announced_ritual")
	game.battle.hand = [card("snare_dungeon", "", "ritual_interrupt")]
	ui.refresh()
	await settle()
	await choose_card(0)
	await play_target(priest["id"])
	check(Copy.intent(game.battle, priest)["line"].contains("Renewal Ritual cancelled") and Copy.banner_guidance(game.battle).contains("cancelled"), "Interrupted ritual confirms cancellation instead of forecasting a heal")
	await capture("slice_07_ritual_interrupted")
	priest["statuses"]["stun"] = 0
	var locked_target: String = ""
	for locked in game.battle.intents:
		if locked["enemy_id"] == priest["id"]: locked_target = locked["target_id"]
	game.battle.get_actor(locked_target)["hp"] = 0
	var replacement: Dictionary = {}
	for actor in game.battle.enemies:
		if actor["id"] != priest["id"] and actor["id"] != locked_target:
			actor["hp"] = 50
			replacement = actor
	before = game.battle.to_dict()
	announced = Copy.intent(game.battle, priest)
	check(announced["targets"] == [replacement["id"]] and announced["line"].contains(replacement["name"]), "A dead locked ritual recipient forecasts the actual other wounded ally")
	check(equal(before, game.battle.to_dict()), "Inspecting the ritual redirect preserves every battle field and RNG")
	replacement["hp"] = replacement["max_hp"]
	announced = Copy.intent(game.battle, priest)
	check(announced["targets"].is_empty() and announced["line"].contains("no wounded ally") and Copy.banner_guidance(game.battle).contains("no wounded ally"), "A ritual with no eligible replacement forecasts no healing rather than healing the priest")

func test_stored_protection() -> void:
	reset_game("stored_bulwark", 0, "green_ogre")
	game.run["traits"] = ["war_drums"]
	game.start_raid()
	var owner: Dictionary = game.battle.monsters[0]
	var ally: Dictionary = game.battle.monsters[1]
	for actor in game.battle.enemies:
		actor["hp"] = 100
		actor["max_hp"] = 100
	game.battle.hand = [card("guard", owner["id"], "guard"), card("strike", owner["id"], "strike")]
	ui.refresh()
	await settle()
	await choose_card(0)
	var before: Dictionary = game.battle.to_dict()
	var hint: String = Copy.preview(game.battle, game.battle.hand[0], ally)
	check(hint.contains("War Drums") and hint.contains("1 energy") and hint.contains("draw 1") and hint.contains("+10 damage"), "Selected teammate Guard previews both the extra play and stored attack payoff")
	check(not Copy.preview(game.battle, game.battle.hand[0], owner).contains("War Drums"), "Self Guard forecasts no teammate-protection reward")
	check(equal(before, game.battle.to_dict()), "Combined trait, form and encounter forecasts preserve the entire battle and RNG")
	await play_target(ally["id"])
	check(game.battle.energy == 3 and game.battle.trait_state.get("war_drums_triggered", false), "Actual teammate Guard refunds its energy and activates War Drums")
	var result: String = Feedback.describe(before, game.battle.to_dict())
	check(result.contains("War Drums: +1 energy, draw 1") and result.contains("protected an ally") and result.contains("+10 damage"), "Phone action feedback explicitly explains both earned payoffs")
	check_combo(owner, "BULWARK STORED")
	check(Forms.status(game.battle, owner).contains("protected an ally") and Forms.status(game.battle, owner).contains("across turns"), "Actor cue explains why the charge exists and that it can be saved")
	await capture("slice_08_protection_payoff")
	game.end_turn()
	game.battle.hand = [card("strike", owner["id"], "stored_strike")]
	ui.refresh()
	await settle()
	check(Forms.damage_bonus(game.battle, owner) == 10 and not game.battle.trait_state.get("war_drums_triggered", true), "Charge survives the enemy turn while the next-turn trait becomes available again")
	await choose_card(0)
	var victim: Dictionary = game.battle.enemies[0]
	hint = Copy.preview(game.battle, game.battle.hand[0], victim)
	check(hint.contains("includes +10 damage"), "A later hand's owned attack previews the saved Bulwark bonus")
	await capture("slice_09_saved_attack_next_turn")
	before = game.battle.to_dict()
	await play_target(victim["id"])
	check(Forms.damage_bonus(game.battle, owner) == 0 and Feedback.describe(before, game.battle.to_dict()).contains("BULWARK +10 attack bonus per hit"), "Actual later attack spends the stored charge and reports its numeric attack bonus")
