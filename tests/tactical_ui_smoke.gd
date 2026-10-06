extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Forms = preload("res://scripts/battle_forms.gd")
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
	profile_root = "user://verification/tactical_ui_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
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
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Tactical UI bootstrap and uploader retain an isolated verification profile")
	for size_ in SIZES:
		pixels = size_
		surface.size = pixels
		await test_marshal()
		await test_break_and_zero_cost()
		await test_combo_cues()
		await test_volley_milestone()
		await test_raid_recap()
	print("TACTICAL UI SMOKE: %d assertions; %d %s; %d issues" % [checks, captures, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("TACTICAL UI ISSUE: ", failure)
	ui.free()
	surface.free()
	# AudioServer retires stopped music playback references on its next mix callback.
	await create_timer(0.4).timeout
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

func reset_game(tag: String, raid: int = 0, form: String = "goblin") -> void:
	ui.skip_turn_animation()
	ui.close_modal()
	game = State.new(profile_root + "%dx%d/%s/" % [pixels.x, pixels.y, tag])
	game.new_run(730215)
	game.run["raid"] = raid
	game.run.erase("party")
	game.run["traits"] = ["spiteful_shields"]
	for owner in game.run["monsters"]:
		owner["hp"] = 100
		owner["max_hp"] = 100
	game.run["monsters"][0]["form"] = form
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

func labels(node: Node) -> Array:
	if node.is_queued_for_deletion(): return []
	var result: Array = []
	if node is Label and node.is_visible_in_tree(): result.append(node)
	for child in node.get_children(): result.append_array(labels(child))
	return result

func visible_text() -> String:
	var lines: Array = []
	for label in labels(ui.content): lines.append(label.text)
	return "\n".join(lines)

func card(ability: String, owner: String, id: String) -> Dictionary:
	return {"id": id, "ability": ability, "owner": owner}

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
	check(usable.encloses(control.get_global_rect()), "Scrolling reaches tactical action: " + control.name)
	check(control.size.x >= 43.9 and control.size.y >= 43.9, "Tactical action has a forty-four-pixel logical tap target")

func choose_card(index: int) -> void:
	var control = named(ui, "Card_%d" % index)
	check(control is Button and not control.disabled, "Actual production card can be selected: %d" % index)
	if control == null or control.disabled: return
	await reachable(control)
	control.pressed.emit()
	await settle()
	check(ui.card_index == index, "Production selection exposes the intended card's legal targets")

func play_target(id: String) -> void:
	var target = ui.actor_nodes.get(id)
	check(target is Button and not target.disabled, "Selected card exposes its actual legal target")
	if target == null: return
	await reachable(target)
	target.pressed.emit()
	await settle()

func test_marshal() -> void:
	reset_game("marshal", 5)
	await settle()
	var warning = named(ui, "MarshalWarning")
	check(warning is Label and warning.text.contains("6 damage") and warning.text.contains("ALL monster Block") and warning.text.contains("Stun"), "Preparation explains the actual Marshal's numeric Block-removing attack and counter")
	game.start_raid()
	game.end_turn()
	check(game.battle.turn == 2, "Actual first combat turn reaches the Marshal's second-round announcement")
	var marshal: Dictionary = game.battle.enemies[0]
	check(marshal.get("champion", "") == "iron_marshal" and game.battle.intents.any(func(intent): return intent["enemy_id"] == marshal["id"] and intent["ability"] == "breach_order"), "Real generated Marshal locks Breach Order on round two")
	for monster in game.battle.monsters:
		monster["block"] = 9
		monster["armor"] = 1
	ui.refresh()
	await settle()
	var enemies = named(ui, "Side_enemies")
	if enemies != null: enemies.pressed.emit()
	await settle()
	var announced: Dictionary = Copy.intent(game.battle, marshal)
	check(announced["damage"] == 6 and announced["targets"].size() == 3 and announced["line"].contains("COUNTERPLAY") and announced["line"].contains("Block is removed"), "Marshal announcement names actual area damage, all recipients and Block-removal counterplay")
	check(not announced["line"].contains("retaliation"), "Block removed before the hit never forecasts Spiteful Shields retaliation")
	var forecast: String = Copy.preview(game.battle, card("breach_order", marshal["id"], "forecast"), game.battle.monsters[0])
	check(forecast.to_lower().contains("remove 9 block") and forecast.contains("5 HP lost") and not forecast.contains("9 blocked"), "Breach forecast removes all Block before applying remaining Armor: " + forecast)
	var rendered: String = visible_text()
	check(rendered.contains("Breach Order") and rendered.contains("COUNTERPLAY") and rendered.contains("Block") and rendered.contains("ALL monsters"), "Phone and desktop visibly preserve the full Marshal warning and actionable counter")
	await capture("01_marshal_round_two_counterplay")
	marshal["statuses"]["resolve"] = 1
	ui.refresh()
	await settle()
	enemies = named(ui, "Side_enemies")
	if enemies != null: enemies.pressed.emit()
	await settle()
	check(Copy.banner_guidance(game.battle).contains("Resolve blocks Stun") and Copy.banner_guidance(game.battle).contains("Evade"), "Protected Marshal guidance accurately offers defeat or Evade when Stun is blocked")
	await capture("02_marshal_resolve_counterplay")

func test_break_and_zero_cost() -> void:
	reset_game("new_cards")
	game.start_raid()
	var owner: Dictionary = game.battle.monsters[0]
	var victim: Dictionary = game.battle.enemies[0]
	victim["block"] = 9
	victim["armor"] = 1
	game.battle.hand = [card("shatter_guard", owner["id"], "shatter"), card("quick_jab", owner["id"], "jab")]
	game.battle.energy = 0
	ui.refresh()
	await settle()
	check(named(ui, "Card_0").disabled and not named(ui, "Card_1").disabled, "At zero energy, Shatter Guard is unavailable while Quick Jab remains payable")
	check(Copy.guidance(game.battle, -1, false).contains("costing 0 can still be played"), "Zero-energy guidance identifies the still-payable free card")
	for index in range(2):
		var control = named(ui, "Card_%d" % index)
		for field in ["CardOwner", "CardCost", "CardTitle", "CardEffect"]:
			var label = named(control, field)
			check(label is Label and control.get_global_rect().grow(1).encloses(label.get_global_rect()), "New card face contains the owner, cost, title and complete short effect")
	var effect = named(named(ui, "Card_0"), "CardEffect")
	check(effect.text.contains("Block") and effect.text.contains("7") and effect.max_lines_visible >= 2, "Shatter Guard face retains both Block removal and damage, including short landscape")
	await capture("03_zero_energy_payable_card")
	game.battle.energy = 1
	ui.refresh()
	await settle()
	await choose_card(0)
	var before: Dictionary = game.battle.to_dict()
	var forecast: String = Copy.preview(game.battle, game.battle.hand[0], victim)
	check(forecast.to_lower().contains("remove 9 block") and forecast.contains("6 HP lost") and not forecast.contains("9 blocked"), "Selected Shatter Guard forecasts its actual Block removal and armor-reduced HP damage: " + forecast)
	check(equal(before, game.battle.to_dict()), "Inspecting the selected forecast preserves every battle field and RNG")
	await capture("04_shatter_guard_actual_target_forecast")
	var hp_before: int = victim["hp"]
	await play_target(victim["id"])
	check(victim["block"] == 0 and victim["hp"] == hp_before - 6 and game.battle.energy == 0, "Target press resolves the exact forecast and leaves zero energy")
	check(not named(ui, "Card_0").disabled and game.battle.hand[0]["ability"] == "quick_jab", "The remaining actual Quick Jab remains enabled after spending the last energy")
	await choose_card(0)
	check(named(ui, "CardExplanation").text.contains("Quick Jab") and named(ui, "CardExplanation").text.contains("0 energy"), "Selected free card guidance names its owner, action and zero cost")
	hp_before = victim["hp"]
	await capture("05_selected_quick_jab_zero_energy")
	await play_target(victim["id"])
	check(victim["hp"] == hp_before - 2 and game.battle.energy == 0 and game.battle.hand.is_empty(), "Real zero-energy target press resolves Quick Jab through Armor without negative energy")
	check(Copy.guidance(game.battle, -1, false).contains("End your turn"), "After the free card is used, zero-energy guidance correctly advances to End turn")

func test_combo_cues() -> void:
	reset_game("bulwark_cues", 0, "green_ogre")
	game.start_raid()
	var owner: Dictionary = game.battle.monsters[0]
	game.battle.hand = [card("guard", owner["id"], "protect"), card("strike", owner["id"], "attack")]
	ui.refresh()
	await settle()
	check_combo(owner, "BULWARK ·")
	await capture("06_form_combo_available")
	await choose_card(0)
	await play_target(game.battle.monsters[1]["id"])
	check_combo(owner, "BULWARK STORED")
	check(Forms.damage_bonus(game.battle, owner) == 10, "Visible stored cue corresponds to the real bonus granted by protecting another ally")
	await capture("07_form_combo_readied")
	await choose_card(0)
	var victim: Dictionary = game.battle.enemies[0]
	var forecast: String = Copy.preview(game.battle, game.battle.hand[0], victim)
	check(forecast.contains("15 HP lost") and forecast.contains("includes +10 damage"), "Selected stored attack forecasts its actual bonus before Armor")
	await play_target(victim["id"])
	check_combo(owner, "BULWARK SPENT")
	check(ui.last_action.contains("BULWARK +10 attack bonus per hit"), "Phone and desktop receipt lead with the numeric Bulwark attack bonus actually spent")
	check(Forms.damage_bonus(game.battle, owner) == 0, "Used cue corresponds to the bonus being consumed exactly once")
	await capture("08_form_combo_used")

func check_combo(owner: Dictionary, expected: String) -> void:
	var label = named(ui, "FormCombo_" + owner["id"]) if ui.battlefield != null else named(ui, "ActorDetail_" + owner["id"])
	if label == null and named(ui, "Side_monsters") != null:
		named(ui, "Side_monsters").pressed.emit()
		await settle()
		label = named(ui, "ActorDetail_" + owner["id"])
	check(label is Label and label.text.contains(expected) and label.text.contains(Forms.status(game.battle, owner)), "Actual evolved actor visibly shows its available, readied or used combo state")
	if ui.battlefield != null:
		var creature = named(ui, "Creature_" + owner["id"])
		check(creature is Control and creature.size.y >= 59.9, "Desktop evolved combo hint preserves the mandatory sixty-pixel creature space")

func test_volley_milestone() -> void:
	reset_game("volley_countdown", 2)
	game.start_raid()
	var captain: Dictionary = game.battle.enemies[0]
	check(captain.get("champion", "") == "cinder_banner", "Countdown uses the actual generated F-rank champion")
	for round_number in [1, 2, 3]:
		if round_number > 1: game.end_turn()
		var before: Dictionary = game.battle.to_dict()
		var rng_before = game.rng.state
		ui.refresh()
		await settle()
		var milestone = named(ui, "ChampionMilestone")
		check(milestone is Label, "Captain countdown has its own visible banner label on every layout")
		if milestone == null: return
		if round_number == 1:
			check(milestone.text.contains("round 3") and milestone.text.contains("2 rounds away"), "First round previews the absolute Volley milestone without calling the current action a Volley")
		elif round_number == 2:
			check(milestone.text.contains("round 3") and milestone.text.contains("next round"), "Second round makes the upcoming Volley one round away")
		else:
			check(milestone.text.contains("THIS ENEMY TURN") and milestone.text.contains("5 damage +1 Burn") and milestone.text.contains("Stun or defeat"), "Locked Volley clearly names imminent harm and its actual counter")
		check(equal(before, game.battle.to_dict()) and game.rng.state == rng_before, "Rendering and inspecting the champion milestone preserves battle state and RNG")
		check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(milestone.get_global_rect()), "Champion milestone starts inside the visible combat banner even on a short phone")
		await reachable(named(ui, "EndTurn"))
		await capture("09_volley_round_%d" % round_number)
	# Exercise the actual target selection with a long receipt on the smallest phone.
	game.battle.hand = [card("snare_dungeon", "", "cancel_volley")]
	ui.refresh()
	await settle()
	await choose_card(0)
	await play_target(captain["id"])
	check(named(ui, "ChampionMilestone").text.contains("cancelled") and ui.last_action != "", "A real Snare receipt accompanies the cancelled Volley milestone")
	await capture("10_volley_cancelled_with_receipt")
	captain["statuses"].erase("stun")
	captain["statuses"]["resolve"] = 1
	ui.refresh()
	await settle()
	check(named(ui, "ChampionMilestone").text.contains("Resolve blocks Stun") and not named(ui, "ChampionMilestone").text.contains("Stun or defeat"), "Protected Volley stops recommending unavailable Stun counterplay")
	await capture("11_volley_resolve_with_receipt")
	var snapshot: Dictionary = game.battle.to_dict()
	ui.flow.active = true
	ui.flow.view = game.battle
	ui.flow.stage = "enemy"
	ui.flow.actor_id = captain["id"]
	ui.flow.acted_ids = [captain["id"]]
	ui.refresh()
	await settle()
	check(named(ui, "ChampionMilestone") == null, "Resolving playback never presents an already acted Volley as pending")
	check(equal(snapshot, game.battle.to_dict()), "Hiding countdown during presentation cannot resolve or alter an action")
	ui.flow.skip()
	captain["hp"] = 0
	ui.refresh()
	await settle()
	check(Copy.champion_milestone(game.battle) == "" and named(ui, "ChampionMilestone") == null, "Defeating the captain removes future Volley promises immediately")
	await capture("12_volley_captain_defeated")

func text_button(node: Node, text: String):
	if node.is_queued_for_deletion(): return null
	if node is Button and node.is_visible_in_tree() and node.text == text: return node
	for child in node.get_children():
		var found = text_button(child, text)
		if found != null: return found
	return null

func test_raid_recap() -> void:
	reset_game("earned_recap", 1, "green_ogre")
	game.run["traits"] = ["war_drums"]
	game.run["trait_milestones"] = [1]
	game.run["monsters"][0]["hp"] = 13
	game.run["monsters"][1]["hp"] = 11
	game.run["monsters"][2]["hp"] = 0
	game.start_raid()
	var owner: Dictionary = game.battle.monsters[0]
	var victim: Dictionary = game.battle.enemies[0]
	for enemy in game.battle.enemies:
		if enemy != victim: enemy["hp"] = 0
	victim["hp"] = 2
	victim["armor"] = 0
	victim["block"] = 100
	game.battle.hand = [card("guard", owner["id"], "recap_guard"), card("strike", owner["id"], "recap_charge")]
	ui.refresh()
	await settle()
	await choose_card(0)
	await play_target(game.battle.monsters[1]["id"])
	await choose_card(0)
	await play_target(victim["id"])
	check(victim["hp"] == 2 and ui.last_action.contains("BULWARK +10 attack bonus per hit"), "A fully blocked charged attack earns an attack-bonus receipt without pretending HP was lost")
	victim["block"] = 0
	game.battle.hand = [card("quick_jab", owner["id"], "recap_finish")]
	ui.refresh()
	await settle()
	await choose_card(0)
	await play_target(victim["id"])
	check(game.run["phase"] == "feeding" and game.battle.outcome == "won", "Actual winning target press reaches feeding through the production run transition")
	var recap: Dictionary = game.run.get("raid_recap", {}).duplicate(true)
	check(not recap.is_empty(), "Production victory captures a raid recap before feeding or recovery")
	if recap.is_empty(): return
	check(recap.get("complete", false) and int(recap.get("cards_played", -1)) == 3, "Fresh raid recap includes all accepted cards, including its winning card")
	check(int(recap.get("survivors", 0)) == 2 and int(recap.get("hp_remaining", 0)) == 24 and int(recap.get("max_hp", 0)) == 300, "Victory recap captures knocked-out allies and raw 24/300 HP before recovery")
	var before: Dictionary = game.run.duplicate(true)
	var battle_before: Dictionary = game.battle.to_dict()
	ui.refresh()
	await settle()
	check_recap(true)
	check(equal(before, game.run) and equal(battle_before, game.battle.to_dict()), "Reading earned recap labels changes neither saved run, battle nor RNG")
	await capture("13_earned_feeding_recap")
	for index in range(game.run["rewards"].size()):
		var skip = text_button(ui, "Skip body")
		check(skip is Button and not skip.disabled, "Feeding still exposes a real body-skip choice after the recap")
		if skip == null: return
		await reachable(skip)
		skip.pressed.emit()
		await settle()
	var recover = text_button(ui, "Recover & continue")
	check(recover is Button and not recover.disabled, "Resolving all bodies enables the production recovery action")
	if recover == null: return
	await reachable(recover)
	recover.pressed.emit()
	await settle()
	check(game.run["phase"] == "result" and equal(recap, game.run.get("raid_recap", {})), "Recovery keeps the completed raid's recap unchanged through its result")
	check(game.run["monsters"][2]["hp"] > 0, "Winning recovery still revives the ally; recap preserves the earlier knockout")
	check_recap(true)
	await capture("14_recovered_result_recap")
	var restored = State.new(game._prefix)
	check(restored.load_game() and equal(recap, restored.run.get("raid_recap", {})), "Reloading the result retains the exact earned recap and pre-recovery health")
	game = restored
	ui.state = game
	ui.refresh()
	await settle()
	check_recap(true)
	# Partial legacy tracking must never be advertised as a full card total.
	game.run["raid_recap"]["complete"] = false
	game.run["raid_recap"]["cards_played"] = 9999
	game.run["raid_recap"]["bulwark"].append({"name": "Unearned Monster", "activations": 0, "bonus_total": 0})
	game.run["raid_recap"]["traits"].append({"id": "venom_nest", "count": 0})
	game.run["raid_recap"]["traits"].append({"id": "unknown_hidden_trait", "count": 9})
	ui.refresh()
	await settle()
	check_recap(false)
	var partial = named(ui, "RaidRecapPayoffs")
	if partial == null: return
	var text: String = partial.text
	check(not text.contains("Unearned") and not text.contains("Venom Nest") and not text.contains("unknown_hidden"), "Recap reveals only positive earned known payoffs, with no zero-count build suggestions")
	await capture("15_partial_saved_recap")
	game.run["raid_recap"]["bulwark"] = []
	game.run["raid_recap"]["traits"] = []
	ui.refresh()
	await settle()
	check(named(ui, "RaidRecapPayoffs") == null and named(ui, "RaidRecapHealth") != null, "A zero-payoff raid retains its honest health snapshot without unearned accomplishment copy")
	await capture("16_health_only_saved_recap")
	reset_game("defeat_has_no_recap")
	game.start_raid()
	for monster in game.battle.monsters: monster["hp"] = 0
	game.end_turn()
	game.run["raid_recap"] = recap
	ui.refresh()
	await settle()
	check(game.run["phase"] == "defeat" and named(ui, "RaidRecap") == null, "A terminal loss never shows a stale victory recap")
	await capture("17_defeat_hides_victory_recap")

func check_recap(complete: bool) -> void:
	var pace = named(ui, "RaidRecapPace")
	var health = named(ui, "RaidRecapHealth")
	var earned = named(ui, "RaidRecapPayoffs")
	check(pace is Label and pace.text.contains("RAID 2 CLEARED") and pace.text.contains("1 round"), "Feeding and result identify the raid that actually ended, with its round count")
	check(health is Label and health.text.contains("2/3 survived") and health.text.contains("24/300 HP at victory"), "Recap health stays explicitly at victory after recovery and reload")
	check(earned is Label and earned.text.contains("1 Bulwark attack") and earned.text.contains("+10 attack bonus/hit") and earned.text.contains("War Drums triggered 1×"), "Only actual earned charge and trait payoffs appear, accurately labeled as attack bonus per hit")
	if pace == null or earned == null: return
	check(pace.text.contains("3 cards played") if complete else not pace.text.contains("cards played"), "Complete tracking shows the card count; incomplete tracking omits any partial total")
	check(earned.text.begins_with("BUILD PAYOFFS" if complete else "RECORDED PAYOFFS"), "Incomplete save data explicitly labels its available payoffs as recorded")
	check(not earned.text.contains("damage dealt") and not earned.text.contains("HP damage") and not earned.text.contains("Basilisk"), "Recap never claims charge size as damage dealt or reveals unearned forms")

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var destination := "res://tests/artifacts/tactical_ui/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(destination)
	if can_render:
		var picture = surface.get_texture().get_image()
		check(picture.get_size() == pixels and picture.save_png(destination + tag + ".png") == OK, "Native tactical UI capture saved with exact logical dimensions")
	else: check(surface.size == pixels, "Headless tactical UI uses exact logical dimensions")
	captures += 1
	print("TACTICAL UI CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

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
		if not horizontal: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Tactical text and controls fit horizontal bounds: " + node.name)
		if not vertical: check(rect.position.y >= -1 and rect.end.y <= pixels.y + 1, "Unscrolled tactical control fits vertical bounds: " + node.name)
		if owner_button != null: check(owner_button.get_global_rect().grow(1).encloses(rect), "Actor and card contain their complete tactical labels: " + node.name)
	for child in node.get_children(): inspect(child)
