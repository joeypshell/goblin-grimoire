extends "res://tests/tactical_ui_smoke.gd"

const Traits = preload("res://scripts/dungeon_traits.gd")
var live_window := false

func _run() -> void:
	profile_root = "user://verification/loot_ui_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/loot/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	surface = SubViewport.new()
	surface.size = SIZES[0]
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	ui = MainScene.instantiate()
	ui.state = State.new(profile_root + "bootstrap/")
	surface.add_child(ui)
	check(ui.state._prefix.begins_with(profile_root) and ui.report_uploader.state._prefix.begins_with(profile_root), "Loot UI and uploader start in an isolated profile")
	if not OS.get_cmdline_user_args().has("--touch-only"):
		for size_ in SIZES:
			pixels = size_
			surface.size = pixels
			await test_loot_flow()
			await test_skip_and_legacy()
			await test_expanded_traits()
			await test_second_trader()
			await test_spell_cues()
	if can_render and OS.get_cmdline_user_args().has("--touch-only"):
		surface.remove_child(ui)
		ui.free()
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		live_window = true
		for size_ in [Vector2i(375,667),Vector2i(390,844),Vector2i(844,320)]:
			pixels = size_
			root.size = pixels
			ui = MainScene.instantiate()
			ui.state = State.new(profile_root + "native_bootstrap_%dx%d/" % [pixels.x,pixels.y])
			root.add_child(ui)
			await test_loot_flow()
			await test_spell_cues()
			ui.free()
	else:
		ui.free()
	surface.free()
	await create_timer(0.4).timeout
	print("LOOT UI SMOKE: %d assertions; %d %s; %d issues" % [checks,captures,"native captures" if can_render else "layouts",failures.size()])
	for failure in failures: print("LOOT UI ISSUE: ",failure)
	quit(0 if failures.is_empty() else 1)

func fresh(tag: String) -> void:
	ui.skip_turn_animation()
	ui.close_modal()
	game = State.new(profile_root + "%dx%d/%s_%d/" % [pixels.x,pixels.y,tag,Time.get_ticks_usec()])
	game.new_run(730216)
	ui.state = game
	ui.menu = "game"
	ui.card_index = -1
	ui.feed_body = 0
	ui.feed_monster = ""
	ui.flow.delay_scale = 0
	ui.refresh()

func press(control) -> void:
	check(control is Button and not control.disabled,"Intended loot action exists and is enabled")
	if not control is Button or control.disabled: return
	await reachable(control)
	if live_window:
		for down in [true,false]:
			var event = InputEventScreenTouch.new()
			event.window_id = root.get_window_id()
			event.index = 0
			event.position = control.get_global_rect().get_center()
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	else: control.pressed.emit()
	await settle()

func continue_saved() -> void:
	var before: Dictionary = game.run.duplicate(true)
	var rng_before: int = game.rng.state
	await press(text_button(ui,"Save & title"))
	check(ui.menu == "title","Visible save action opens title without changing loot")
	await press(text_button(ui,"Continue"))
	check(ui.menu == "game" and equal(before,game.run) and game.rng.state == rng_before,"Actual Continue preserves exact offers, stock, gold, corpses, health and combat RNG")

func win_raid() -> void:
	check(game.run["phase"] == "prep","Focused winning-card fixture begins in ordinary preparation")
	await press(text_button(ui,"Defend the dungeon"))
	# HP-only enemy fixture makes a bounded win through real owned card/target
	# controls. It grants no skills, spells, gold, forms, rewards or recovery.
	for foe in game.battle.enemies:
		foe["hp"] = 1
		foe["armor"] = 0
		foe["block"] = 0
	game.battle.hand = []
	for index in range(game.battle.enemies.size()):
		game.battle.hand.append(card("strike",game.battle.monsters[0]["id"],"loot_win_%d" % index))
	ui.refresh()
	for foe in game.battle.enemies:
		if int(foe["hp"]) <= 0: continue
		await press(named(ui,"Card_0"))
		await press(ui.actor_nodes.get(foe["id"]))
	check(game.battle.outcome == "won" and game.run["last_result"] == "won","Real accepted winning cards create rewards and gold through production resolution")
	if game.run["phase"] == "trait":
		var offered: Array = game.trait_choices()
		await press(named(ui,"TraitSelect_" + offered[0]))
	check(game.run["phase"] == "feeding","First pre-meal trait choice reaches the actual feeding draft")

func resolve_bodies_and_recover() -> void:
	var raw_hp: Array = game.run["monsters"].map(func(actor): return actor["hp"])
	var before_id: int = game.run["recovered_id"]
	for index in range(game.run["rewards"].size()):
		ui.feed_body = index
		ui.refresh()
		var recipient := ""
		for actor in game.run["monsters"]:
			if not game.inheritance_outcomes(index,actor["id"]).is_empty():
				recipient = actor["id"]
				break
		if recipient != "":
			await press(named(ui,"Recipient_" + recipient))
			await press(named(ui,"DevourBody"))
			check(game.run["rewards"][index].has("taken"),"Actual recipient and Devour controls roll the corpse skill without choosing inheritance")
		else:
			await press(text_button(ui,"Skip body"))
		check(game.run["recovered_id"] == before_id and game.run["monsters"].map(func(actor): return actor["hp"]) == raw_hp,"Devouring preserves raw victory HP until recovery")
	await press(named(ui,"FinishFeeding"))
	check(game.run["recovered_id"] == game.run["resolved_id"] and not game.finish_feeding(),"All resolved rewards permit exactly one ordinary recovery")
	if game.run["phase"] == "trait":
		await press(named(ui,"TraitSelect_" + game.trait_choices()[0]))

func test_loot_flow() -> void:
	fresh("flow")
	await settle()
	check(game.run["loot_version"] == 1 and game.run["gold"] == 0 and game.dungeon_spell_loadout().size() == 3,"New run starts with three original shared spells and zero gold")
	check(named(ui,"TraderMilestone") is Label and named(ui,"TraderMilestone").text.contains("raid 2"),"Preparation promises the first trader before the F champion")
	game.run["monsters"][0]["hp"] = 9
	game.run["monsters"][1]["hp"] = 4
	game.run["monsters"][2]["hp"] = 0
	await win_raid()
	check(game.run["gold"] == 35 and game.run["recovered_id"] == 0,"First real win earns35 gold without early recovery")
	var choices: Array = game.spell_reward_choices()
	check(choices.size() == 3 and choices == game.run["spell_offer"]["options"],"Draft shows exactly the three actual saved spell IDs")
	await continue_saved()
	var before: Dictionary = game.run.duplicate(true)
	var rng_before: int = game.rng.state
	var chosen: String = choices[0]
	for id in choices:
		var effect: String = ui.loot_screen.OFFER_EFFECTS[id] if ui.is_compact() else Data.ABILITIES[id]["description"]
		check(named(ui,"SpellOffer_" + id) is Button and named(ui,"SpellOffer_" + id + "Art") is Control and named(ui,"SpellOffer_" + id + "Effect").text == effect,"Each actual offer has illustrated action, cost, rarity and readable effect copy")
	await capture("01_saved_draft")
	await press(named(ui,"SpellOffer_" + chosen))
	check(equal(before,game.run) and game.rng.state == rng_before,"Selecting a spell only previews replacement; it neither learns, equips nor rolls anything")
	if ui.is_compact(): check(named(ui,"SpellReplace_FullEffect").text == Data.ABILITIES[chosen]["description"],"Selected phone offer exposes its full authoritative rule before an explicit replacement")
	for slot in range(3):
		check(named(ui,"SpellReplace_%d" % slot) is Button,"Selected spell offers each exact equipped shared slot as a replacement")
	await press(named(ui,"SpellReplace_1"))
	check(game.run["spell_offer"]["resolved"] and game.run["spell_library"].has(chosen) and game.dungeon_spell_loadout()[1] == chosen,"Explicit replacement learns and immediately equips the chosen shared spell")
	check(equal(before["monsters"],game.run["monsters"]) and equal(before["rewards"],game.run["rewards"]) and game.rng.state == rng_before,"Spell acquisition cannot alter owned skills, corpse rolls, health or combat RNG")
	check(named(ui,"SpellDraftReceipt").text.contains(ui.ability_name(chosen)) and named(ui,"DungeonSpellEffect_1").text == Data.ABILITIES[chosen]["description"],"Receipt and library show the exact equipped spell effect")
	var picker = named(ui,"DungeonSpellSlot_0")
	check(picker is OptionButton and picker.is_item_disabled(game.run["spell_library"].find(chosen)),"Library disables a spell already equipped in a different slot")
	await capture("02_equipped_draft")
	await resolve_bodies_and_recover()
	check(game.run["phase"] == "result" and game.run["raid"] == 1 and game.run["monsters"].map(func(actor): return actor["hp"]) == [14,9,5],"First meal applies one normal25-percent recovery after its trait and spell decisions")
	await press(text_button(ui,"Return to preparation"))
	await win_raid()
	check(game.run["gold"] == 70,"Second real win retains first-win gold and earns another35")
	await press(named(ui,"SkipSpellReward"))
	await resolve_bodies_and_recover()
	check(game.run["raid"] == 2 and game.run["phase"] == "result" and text_button(ui,"Visit the trader") is Button,"Second recovery clearly directs the player to the saved trader")
	await press(text_button(ui,"Visit the trader"))
	check(game.run["phase"] == "trader" and game.run["trader_raid"] == 2,"Visible result action opens the F champion's trader")
	var stock: Array = game.trader_stock()
	check(stock.size() >= 3 and stock.all(func(item): return item.has("ability") and item.has("price") and item.has("sold")),"Trader renders actual saved role stock with prices and sale status")
	await continue_saved()
	await capture("03_saved_trader")
	var affordable: Dictionary = {}
	for item in stock:
		if not item["sold"] and int(item["price"]) <= int(game.run["gold"]): affordable = item; break
	check(not affordable.is_empty(),"Two actual regular wins fund a meaningful offered purchase")
	if affordable.is_empty(): return
	before = game.run.duplicate(true)
	rng_before = game.rng.state
	await press(named(ui,"TraderSelect_" + affordable["id"]))
	check(equal(before,game.run) and game.rng.state == rng_before,"Trader selection neither spends gold nor equips a spell")
	await press(named(ui,"TraderBuy_0"))
	check(game.run["gold"] == int(before["gold"]) - int(affordable["price"]) and game.dungeon_spell_loadout()[0] == affordable["ability"],"Explicit buy equips its exact shared slot and deducts its quoted price once")
	check(game.trader_stock().any(func(item): return item["id"] == affordable["id"] and item["sold"]),"Bought stock stays visibly sold")
	check(named(ui,"TraderSelect_" + affordable["id"]).disabled and named(ui,"TraderGold").text.contains(str(game.run["gold"])),"Sold action is disabled and remaining gold is readable")
	await continue_saved()
	check(game.dungeon_spell_loadout()[0] == affordable["ability"] and game.trader_stock().any(func(item): return item["id"] == affordable["id"] and item["sold"]),"Continue preserves exact paid equipment and sold stock")
	for item in game.trader_stock():
		if item["sold"] or int(item["price"]) <= int(game.run["gold"]): continue
		await press(named(ui,"TraderSelect_" + item["id"]))
		check(named(ui,"TraderBuy_0").disabled and named(ui,"TraderBuy_1").disabled and named(ui,"TraderBuy_2").disabled,"Unaffordable stock disables every spending action without hiding its spell effect")
		break
	await capture("04_sold_and_unaffordable")
	await press(named(ui,"LeaveTrader"))
	check(game.run["phase"] == "prep" and game.run["trader_visited_raids"].has(2) and named(ui,"TraderMilestone").text.contains("raid 5"),"Leaving prepares the F champion and advertises the later E champion trader")
	await press(text_button(ui,"Defend the dungeon"))
	var cards: Array = game.battle.hand + game.battle.draw_pile + game.battle.discard
	check(cards.size() == 12 and cards.filter(func(item): return item["ability"] == affordable["ability"] and item["owner"] == "").size() == 1,"Next battle remains12 cards and contains the purchased ownerless spell exactly once")
	# Locate the genuinely equipped card from this actual deck and play it through
	# card/target controls; no additional spell or learned ability is granted.
	var purchased: Dictionary = cards.filter(func(item): return item["ability"] == affordable["ability"] and item["owner"] == "")[0]
	game.battle.hand = [purchased]
	game.battle.monsters[0]["hp"] = mini(5,int(game.battle.monsters[0]["hp"]))
	ui.refresh()
	await press(named(ui,"Card_0"))
	var legal: Array = game.battle.legal_targets(purchased)
	check(not legal.is_empty(),"Purchased equipped spell has a legal battle target")
	if not legal.is_empty():
		var energy_before: int = game.battle.energy
		await press(ui.actor_nodes.get(legal[0]))
		check(game.battle.discard.any(func(item): return item["id"] == purchased["id"]) and game.battle.energy <= energy_before,"Purchased real spell resolves from its ownerless card through a legal UI target")
	await capture("05_purchased_spell_in_battle")

func test_skip_and_legacy() -> void:
	fresh("skip")
	await settle()
	await win_raid()
	var before: Dictionary = game.run.duplicate(true)
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	ui.refresh()
	check(named(ui,"FinishFeeding").disabled and not game.finish_feeding(),"Even resolved bodies cannot recover while the spell draft is pending")
	await press(named(ui,"SkipSpellReward"))
	check(game.run["spell_offer"]["skipped"] and game.run["dungeon_spells"] == before["dungeon_spells"] and game.run["spell_library"] == before["spell_library"],"Explicit spell skip keeps every equipped and learned spell")
	await press(named(ui,"FinishFeeding"))
	check(game.run["phase"] == "result","Skipping the spell lets an otherwise resolved meal recover normally")
	await capture("06_skipped_reward_result")
	fresh("legacy")
	await settle()
	game.run.erase("loot_version")
	game.save_game()
	var legacy = State.new(game._prefix)
	check(legacy.load_game() and not legacy.run.has("loot_version"),"Loading an older run never retroactively opts it into loot")
	game = legacy
	ui.state = game
	ui.refresh()
	check(named(ui,"GoldHUD") == null and named(ui,"DungeonSpellLibrary") == null and named(ui,"TraderMilestone") == null,"Legacy preparation has no promised gold, draft or trader features")
	await capture("07_legacy_preparation")

func test_expanded_traits() -> void:
	fresh("expanded_traits")
	game.run["raid"] = 3
	game.run["traits"] = ["pack_instinct"]
	game.run["trait_milestones"] = [1]
	check(game._open_trait_reward("prep"),"Earned second-trait fixture opens all remaining rules")
	ui.refresh()
	await settle()
	check(game.trait_choices().size() == Traits.DEFINITIONS.size() - 1,"Second reward retains all remaining expanded trait choices")
	for id in game.trait_choices():
		var action = named(ui,"TraitSelect_" + id)
		check(action is Button and named(ui,"TraitCompatibility_" + id).text != "","Every remaining trait has its authoritative rule and relevant deck compatibility")
		await reachable(action)
	await capture("08_expanded_second_trait_actions")
	check(ui.traits_screen.compatibility("wildfire").begins_with("NEXT DECK") and ui.traits_screen.compatibility("spellweaver").contains("Core Pulse"),"Original shared spells correctly identify no area attack and the qualifying printed-two-cost heal")
	# Known-spell fixture isolates compatibility copy from acquisition tests above.
	game.run["dungeon_spells"] = ["renewal_wave","arcane_sweep","sanctuary"]
	game.run["spell_library"].append_array(game.run["dungeon_spells"])
	ui.refresh()
	await settle()
	check(ui.traits_screen.compatibility("blood_cauldron").contains("Renewal Wave") and ui.traits_screen.compatibility("blood_cauldron").contains("Regen ticks do not trigger"),"Blood advice reads actual equipped healing cards and excludes delayed regeneration")
	check(ui.traits_screen.compatibility("wildfire").contains("Arcane Sweep") and ui.traits_screen.compatibility("wildfire").contains("costs surviving foes HP"),"Wildfire advice identifies an equipped shared area hit and its actual HP requirement")
	check(ui.traits_screen.compatibility("spellweaver").contains("Sanctuary") and ui.traits_screen.compatibility("spellweaver").contains("printed at 2+"),"Spellweaver advice uses current shared printed costs")
	check(ui.traits_screen.compatibility("lingering_wards").contains("Sanctuary") and ui.traits_screen.compatibility("lingering_wards").contains("up to 3 Block"),"Ward advice identifies actual equipped Block and its retained cap")

func test_second_trader() -> void:
	fresh("second_trader")
	# Late-act phase fixture: a real fifth winning card still creates the stock,
	# draft, gold and recovery. Earlier rewards are covered by test_loot_flow.
	game.run["raid"] = 4
	game.run["traits"] = ["pack_instinct","war_drums"]
	game.run["trait_milestones"] = [1,3]
	game.run["trader_visited_raids"] = [2]
	game.run.erase("party")
	game.party_preview()
	ui.refresh()
	await settle()
	await win_raid()
	await press(named(ui,"SkipSpellReward"))
	await resolve_bodies_and_recover()
	await press(text_button(ui,"Visit the trader"))
	check(game.run["trader_raid"] == 5 and named(ui,"LeaveTrader").text.contains("E champion") and named(ui,"TraderGuidance").text.contains("E champion"),"Second saved visit clearly prepares the E champion")
	check(game.trader_stock().all(func(item): return str(item["id"]).begins_with("trader_5_")),"Second visit renders its exact visit-qualified saved stock IDs")
	await continue_saved()
	await capture("09_second_saved_trader")
	await press(named(ui,"LeaveTrader"))
	check(game.run["phase"] == "prep" and game.run["trader_visited_raids"] == [2,5] and named(ui,"TraderMilestone") == null,"Leaving both traders removes the future-shop promise")

func test_spell_cues() -> void:
	fresh("spell_cues")
	# Equipped card/trait fixture isolates feedback; acquisition and paid equip
	# use earned production rewards in test_loot_flow.
	game.run["dungeon_spells"] = ["echo_rune","hunters_mark","arcane_sweep"]
	game.run["spell_library"].append_array(game.run["dungeon_spells"])
	game.run["traits"] = ["spellweaver","wildfire"]
	ui.refresh()
	await settle()
	await press(text_button(ui,"Defend the dungeon"))
	var foe: Dictionary = game.battle.enemies[0]
	foe["hp"] = 100
	foe["max_hp"] = 100
	foe["armor"] = 0
	foe["block"] = 0
	var owner: Dictionary = game.battle.monsters[0]
	game.battle.hand = [card("echo_rune","","echo_cue"),card("hunters_mark","","mark_cue"),card("strike",owner["id"],"owned_echo_cue")]
	ui.refresh()
	await press(named(ui,"Card_0"))
	await press(ui.actor_nodes.get(owner["id"]))
	check(named(ui,"DungeonCombatStatus") is Label and named(ui,"DungeonCombatStatus").text.contains("ECHO ARMED") and named(ui,"DungeonCombatStatus").text.contains("next monster-owned"),"Armed Echo stays visibly attached to the dungeon after its shared card resolves")
	check(named(ui,"DeckCounter").text.contains("Spellweaver used") and named(ui,"DeckCounter").text.contains("Wildfire ready"),"Once-per-turn shared traits show actual used and ready states")
	await capture("10_echo_armed")
	await press(named(ui,"Card_0"))
	await press(ui.actor_nodes.get(foe["id"]))
	var target_copy: String = "\n".join(labels(ui.actor_nodes[foe["id"]]).map(func(label): return label.text))
	check(game.battle.dungeon_state["echo_ready"] and target_copy.contains("Hunter's Mark") and target_copy.contains("+4"),"Shared Mark leaves Echo armed and shows the target's exact next-owned-hit bonus")
	await capture("11_echo_and_mark_ready")
	var hp_before: int = foe["hp"]
	await press(named(ui,"Card_0"))
	await reachable(ui.actor_nodes.get(foe["id"]))
	await capture("11a_exact_echo_hit_forecast")
	await press(ui.actor_nodes.get(foe["id"]))
	check(not game.battle.dungeon_state["echo_ready"] and named(ui,"DungeonCombatStatus") == null and not named(ui,"Intent_" + foe["id"]).text.contains("Hunter's Mark"),"Accepted owned hit consumes Echo and Mark and removes both pending cues")
	check(hp_before - int(foe["hp"]) == 16,"Actual owned Strike repeats6 damage with the mark's4 bonus only on its first hit")
	await capture("12_echo_and_mark_spent")

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var destination := "res://tests/artifacts/loot/%dx%d/" % [pixels.x,pixels.y]
	DirAccess.make_dir_recursive_absolute(destination)
	if can_render:
		var picture = root.get_texture().get_image() if live_window else surface.get_texture().get_image()
		check(picture.get_size() == pixels and picture.save_png(destination + tag + ".png") == OK,"Loot capture preserves exact viewport dimensions")
	else: check(surface.size == pixels,"Headless loot layout uses exact logical dimensions")
	captures += 1
	print("LOOT UI CAPTURE: %dx%d %s" % [pixels.x,pixels.y,tag])
