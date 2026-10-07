extends RefCounted

const CountingState = preload("res://tests/flow_state_fixture.gd")
const CombatTraits = preload("res://tests/test_trait_combat.gd")
const DungeonTraits = preload("res://scripts/dungeon_traits.gd")

func run(t) -> void:
	t.group("earned trait choices, single recovery, saved milestones and legacy boundaries")
	test_first_offer_pairs(t)
	test_progression(t)
	test_first_win_guard(t)
	test_legacy(t)
	test_legacy_first_offer(t)
	test_legacy_feeding_order(t)
	CombatTraits.new().run(t)

func game_at(t, tag: String):
	return CountingState.new(t.profile_root + tag + "/")

func fixture_victory(game) -> bool:
	# Explicit phase fixture; the campaign test wins with production cards/HP.
	fixture_win(game)
	if game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding": game.choose_trait(game.trait_choices()[0])
	return finish_fixture_meals(game)

func fixture_win(game) -> void:
	game.start_raid()
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()

func finish_fixture_meals(game) -> bool:
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	return game.finish_feeding()

func test_first_offer_pairs(t) -> void:
	var representatives: Dictionary = {}
	for seed_value in range(1, 101):
		var offered: Array = DungeonTraits.first_offer(seed_value)
		t.check(offered.size() == 2 and offered[0] != offered[1] and offered.all(func(id): return DungeonTraits.DEFINITIONS.has(id)), "Seeded first offer contains exactly two distinct existing traits: seed %d" % seed_value)
		t.check(offered == DungeonTraits.first_offer(seed_value), "Independent first-offer generation is deterministic: seed %d" % seed_value)
		var sorted: Array = offered.duplicate()
		sorted.sort()
		var pair: String = str(sorted[0]) + "/" + str(sorted[1])
		if not representatives.has(pair): representatives[pair] = seed_value
	t.check(representatives.size() == 6, "All six possible pairs of four first-reward traits occur across bounded seeds")
	for pair in representatives:
		var game = game_at(t, "trait_pair_" + str(representatives[pair]))
		game.new_run(int(representatives[pair]))
		# Phase fixture uses real generated corpses; full campaigns play real cards.
		game.start_raid()
		for enemy in game.battle.enemies: enemy["hp"] = 0
		var random_before: int = game.rng.state
		var party: Array = game.run["party"].duplicate(true)
		game.end_turn()
		t.check(game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding" and game.run["raid"] == 0 and game.trait_choices() == DungeonTraits.first_offer(int(representatives[pair])), "Actual first-win reward boundary creates the pair for " + str(pair))
		t.check(game.rng.state == random_before and game.run["party"] == party, "Opening a two-trait offer preserves gameplay RNG and the existing encounter")
		var first_offer: Array = game.trait_choices()
		var returned: Array = game.trait_choices()
		returned.clear()
		var before: Dictionary = game.run.duplicate(true)
		game.save_calls = 0
		for repeat in range(8): game.trait_choices()
		game.start_raid()
		game.continue_after_result()
		t.check(game.run == before and game.save_calls == 0 and game.rng.state == random_before and game.trait_choices() == first_offer, "Returned arrays, repeated queries and premature actions cannot mutate or reroll the pending pair")
		for unavailable in DungeonTraits.choices([]):
			if first_offer.has(unavailable): continue
			t.check(not game.choose_trait(str(unavailable)) and game.run == before and game.rng.state == random_before and game.save_calls == 0, "An existing but unoffered trait is rejected without mutation or save: " + str(unavailable))
		game.save_game()
		var loaded = game_at(t, "trait_pair_" + str(representatives[pair]))
		t.check(loaded.load_game() and loaded.trait_choices() == first_offer and loaded.rng.state == random_before, "Each possible pending pair survives a real save and Continue")
		var chosen: String = str(first_offer[0])
		t.check(loaded.choose_trait(chosen) and loaded.run["first_trait_offer"] == first_offer and loaded.run["trait_milestones"] == [1], "Choosing one offered trait retains the original saved pair and marks its boundary")
		var chosen_loaded = game_at(t, "trait_pair_" + str(representatives[pair]))
		t.check(chosen_loaded.load_game() and chosen_loaded.run["phase"] == "feeding" and chosen_loaded.run["traits"] == [chosen] and chosen_loaded.run["first_trait_offer"] == first_offer and chosen_loaded.trait_choices().is_empty() and chosen_loaded.run["recovered_id"] == 0, "Continue after early selection cannot reopen its reward or recover the pending meal")

func test_progression(t) -> void:
	var game = game_at(t, "trait_progression")
	game.new_run(40419)
	t.check(game.run["traits"].is_empty() and game.run["trait_milestones"].is_empty(), "New runs start with no traits or already claimed milestones")
	game.save_calls = 0
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	t.check(not game.choose_trait("venom_nest") and game.run == before and game.rng.state == random_before and game.save_calls == 0, "Trait cannot be selected before an earned reward; rejection is mutation/RNG/save free")
	game.run["monsters"][0]["hp"] = 5
	fixture_win(game)
	t.check(game.run["raid"] == 0 and game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding", "First resolved raid opens its earned trait before the first meal, recovery or raid advancement")
	var pending_hp: Array = game.run["monsters"].map(func(m): return m["hp"])
	var pending_bodies: Array = game.run["rewards"].duplicate(true)
	var pending_recap: Dictionary = game.run["raid_recap"].duplicate(true)
	t.check(pending_hp[0] == 5 and game.run["recovered_id"] == 0 and game.run["resolved_id"] == 1 and pending_bodies.size() == 3 and pending_bodies.all(func(body): return not body["claimed"]), "Early reward retains the raw combat HP, actual untouched corpses and one unrecovered resolution")
	var choices: Array = game.trait_choices()
	before = game.run.duplicate(true)
	random_before = game.rng.state
	game.save_calls = 0
	for query in range(10): game.trait_choices()
	game.start_raid()
	game.continue_after_result()
	t.check(choices.size() == 2 and choices == game.run["first_trait_offer"] and game.run == before and game.rng.state == random_before and game.save_calls == 0, "Queries and premature continuation cannot leave or reroll the two-option first reward")
	t.check(game.current_report()["summary"]["current"]["first_trait_offer"] == choices, "Pending first offer is included as copied report view metadata")
	t.check(not game.choose_trait("missing_trait") and game.run == before and game.rng.state == random_before and game.save_calls == 0, "Unknown trait choice changes no state, RNG or persistence")
	t.check(not game.claim_body(0, "m1") and not game.skip_body(0) and not game.finish_feeding() and not game.set_selected("m1", 0, "guard") and not game.evolve("m1", "green_ogre") and game.inheritance_outcomes(0, "m1").is_empty(), "Meal, recovery and build actions stay blocked until the earned early trait is chosen")
	t.check(game.run == before and game.rng.state == random_before and game.save_calls == 0, "Rejected early feeding/build requests cannot alter bodies, HP, offers, reports, RNG or persistence")
	game.save_game()
	var loaded = game_at(t, "trait_progression")
	t.check(loaded.load_game() and loaded.run["phase"] == "trait" and loaded.run.get("trait_return", "") == "feeding" and loaded.trait_choices() == choices and loaded.run["raid"] == 0, "Continue restores the exact early first offer and its feeding destination")
	t.check(loaded.run["rewards"] == pending_bodies and loaded.run["raid_recap"] == pending_recap and loaded.run["monsters"].map(func(m): return m["hp"]) == pending_hp and loaded.run["recovered_id"] == 0 and loaded.rng.state == random_before, "Early Continue preserves actual corpses, recap, raw HP, deferred recovery and gameplay RNG")
	t.check(loaded.current_report()["summary"]["recoveries"] == 0 and loaded.current_report()["summary"]["traits_chosen"] == 0, "Continue cannot fabricate early recovery or a trait selection")
	loaded.save_calls = 0
	var chosen: String = str(choices[0])
	t.check(loaded.choose_trait(chosen) and loaded.run["traits"] == [chosen] and loaded.run["trait_milestones"] == [1] and loaded.run["phase"] == "feeding" and loaded.run["raid"] == 0, "One offered early choice records its milestone and returns to the first bodies without advancing the raid")
	var choice_events: Array = loaded.current_report()["events"].filter(func(event): return event["kind"] == "trait_chosen")
	t.check(choice_events.size() == 1 and choice_events[0]["data"]["offered"] == choices and choice_events[0]["data"]["trait"] == chosen, "Trait report event records the actual offer separately from the selected trait")
	t.check(loaded.rng.state == random_before and loaded.save_calls == 1 and loaded.run["monsters"].map(func(m): return m["hp"]) == pending_hp and loaded.run["rewards"] == pending_bodies and loaded.run["raid_recap"] == pending_recap and loaded.run["recovered_id"] == 0, "Valid early trait selection saves once without changing RNG, bodies, recap or raw HP")
	t.check(loaded.current_report()["summary"]["traits_chosen"] == 1 and loaded.current_report()["summary"]["recoveries"] == 0, "Early choice reports once while recovery remains unapplied")
	before = loaded.run.duplicate(true)
	t.check(not loaded.choose_trait("pack_instinct") and loaded.run == before, "Double selection cannot award a second trait from one milestone")
	var continued = game_at(t, "trait_progression")
	t.check(continued.load_game() and continued.run["traits"] == [chosen] and continued.run["phase"] == "feeding" and continued.run["rewards"] == pending_bodies and continued.rng.state == random_before, "Selected early trait and unresolved bodies persist without reopening their reward")
	t.check(finish_fixture_meals(continued) and continued.run["raid"] == 1 and continued.run["phase"] == "result" and continued.run["monsters"][0]["hp"] == 10 and continued.run["resolved_id"] == continued.run["recovered_id"], "Only completed feeding applies recovery once and advances to the first result")
	t.check(continued.current_report()["summary"]["recoveries"] == 1 and continued.current_report()["summary"]["traits_chosen"] == 1, "Finishing the first meal records one recovery without repeating the early choice")
	var recovered: Dictionary = continued.run.duplicate(true)
	continued.save_calls = 0
	t.check(not continued.finish_feeding() and continued.run == recovered and continued.save_calls == 0, "A repeated completion cannot recover or advance a second time")
	continued.continue_after_result()
	t.check(fixture_victory(continued) and continued.run["raid"] == 2 and continued.run["phase"] == "result", "The middle F raid does not award an extra trait")
	continued.continue_after_result()
	fixture_win(continued)
	t.check(continued.run["raid"] == 2 and continued.run["phase"] == "feeding" and not continued.run.has("trait_return") and continued.run["trait_milestones"] == [1], "The champion still opens feeding before its second trait reward")
	t.check(finish_fixture_meals(continued) and continued.run["raid"] == 3 and continued.run["phase"] == "trait" and continued.run["promotion"] == "E", "Champion feeding and recovery still precede the second trait and promotion")
	t.check(not continued.trait_choices().has(chosen) and continued.trait_choices() == DungeonTraits.choices([chosen]) and continued.trait_choices().size() == 3, "The second reward retains all three remaining traits rather than another random pair")
	before = continued.run.duplicate(true)
	random_before = continued.rng.state
	continued.save_calls = 0
	t.check(not continued.choose_trait(chosen) and continued.run == before and continued.rng.state == random_before and continued.save_calls == 0, "Duplicate trait rejection does not advance or save the reward")
	var second_choices: Array = continued.trait_choices()
	var second: String = str(second_choices[0])
	t.check(continued.choose_trait(second) and continued.run["trait_milestones"] == [1, 3] and continued.run["traits"] == [chosen, second] and continued.run["first_trait_offer"] == choices, "Second milestone grants another distinct run-long trait and retains first-offer history")
	choice_events = continued.current_report()["events"].filter(func(event): return event["kind"] == "trait_chosen")
	t.check(choice_events.back()["data"]["offered"] == second_choices, "Second trait event reports all actual remaining choices")
	continued.continue_after_result()
	continued.start_raid()
	t.check(continued.battle.traits == continued.run["traits"] and continued.battle.trait_state["owners"].is_empty(), "Next real raid receives selected traits with fresh per-battle progress")
	continued.new_run(1772)
	t.check(continued.run["traits"].is_empty() and continued.run["trait_milestones"].is_empty() and not continued.run.has("first_trait_offer"), "New Run clears chosen traits, milestone progress and the previous offer")

func test_first_win_guard(t) -> void:
	var game = game_at(t, "trait_first_win_guard")
	game.new_run(96107)
	var original: Dictionary = game.run.duplicate(true)
	for invalid in [
		{"phase": "feeding", "raid": 0, "last_result": "breach", "resolved_id": 1, "recovered_id": 0},
		{"phase": "feeding", "raid": 0, "last_result": "won", "resolved_id": 1, "recovered_id": 1},
		{"phase": "combat", "raid": 0, "last_result": "won", "resolved_id": 1, "recovered_id": 0},
		{"phase": "prep", "raid": 0, "last_result": "won", "resolved_id": 1, "recovered_id": 0},
		{"phase": "trait", "trait_return": "result", "raid": 0, "last_result": "won", "resolved_id": 1, "recovered_id": 0},
		{"phase": "feeding", "raid": 2, "last_result": "won", "resolved_id": 3, "recovered_id": 2, "trait_milestones": [1]}
	]:
		game.run = original.duplicate(true)
		game.run.merge(invalid, true)
		var before: Dictionary = game.run.duplicate(true)
		var random_before: int = game.rng.state
		t.check(game._pending_trait_milestone() == -1 and game.trait_choices().is_empty() and game.run == before and game.rng.state == random_before, "Only an actual unrecovered first win at its feeding destination counts early: " + str(invalid))

func test_legacy(t) -> void:
	var old = game_at(t, "trait_legacy_prep")
	old.new_run(33718)
	old.run["raid"] = 3
	old.run.erase("traits")
	old.run.erase("trait_milestones")
	old.save_game()
	var original_party: Array = old.run["party"].duplicate(true)
	var random_before: int = old.rng.state
	var loaded = game_at(t, "trait_legacy_prep")
	t.check(loaded.load_game() and loaded.run["phase"] == "trait" and loaded.run["traits"].is_empty(), "Legacy preparation opens owed rewards at its safe boundary")
	t.check(loaded.rng.state == random_before and loaded.run["party"] == original_party, "Opening legacy trait rewards preserves its existing party and RNG")
	var first: String = str(loaded.trait_choices()[0])
	t.check(loaded.trait_choices().size() == 2 and loaded.choose_trait(first) and loaded.run["phase"] == "trait" and loaded.run["trait_milestones"] == [1], "First of two owed legacy milestones offers a pair and keeps the reward screen open")
	var pending = game_at(t, "trait_legacy_prep")
	t.check(pending.load_game() and pending.trait_choices().size() == DungeonTraits.DEFINITIONS.size() - 1 and not pending.trait_choices().has(first), "Partly selected legacy rewards reload with all remaining traits")
	t.check(pending.choose_trait(str(pending.trait_choices()[0])) and pending.run["phase"] == "prep" and pending.run["trait_milestones"] == [1, 3] and pending.rng.state == random_before, "Second legacy reward returns to the original preparation without RNG consumption")
	var active = game_at(t, "trait_legacy_combat")
	active.new_run(72818)
	active.run["raid"] = 3
	active.run.erase("party")
	active.start_raid()
	active.run.erase("traits")
	active.run.erase("trait_milestones")
	active.save_game()
	var snapshot: Dictionary = active.run.duplicate(true)
	snapshot["battle"].erase("traits")
	snapshot["battle"].erase("trait_state")
	active._write_json(active._prefix + "run.json", snapshot)
	var combat_loaded = game_at(t, "trait_legacy_combat")
	t.check(combat_loaded.load_game() and combat_loaded.run["phase"] == "combat" and combat_loaded.battle.traits.is_empty(), "Legacy active combat remains playable and does not open rewards mid-turn")
	t.check(not combat_loaded.run.has("first_trait_offer"), "An old active combat does not generate a first trait offer before its safe reward boundary")
	t.check(combat_loaded.battle.hand == snapshot["battle"]["hand"] and combat_loaded.battle.intents == snapshot["battle"]["intents"] and str(combat_loaded.rng.state) == snapshot["rng_state"], "Trait-less legacy combat preserves hand, announced actions and RNG")
	for enemy in combat_loaded.battle.enemies: enemy["hp"] = 0
	combat_loaded.end_turn()
	for index in range(combat_loaded.run["rewards"].size()): combat_loaded.skip_body(index)
	t.check(combat_loaded.finish_feeding() and combat_loaded.run["phase"] == "trait", "Legacy active run offers owed traits only after its combat/feeding boundary")
	t.choose_campaign_trait(combat_loaded)
	t.check(combat_loaded.run["phase"] == "result" and combat_loaded.run["traits"].size() == 2, "Deferred legacy rewards return to the proper result after both choices")

func test_legacy_first_offer(t) -> void:
	var old = game_at(t, "trait_legacy_pending_first")
	old.new_run(84917)
	old.run["raid"] = 1
	old.run["phase"] = "trait"
	old.run["trait_return"] = "result"
	old.run.erase("first_trait_offer")
	old.save_game()
	var random_before: int = old.rng.state
	var party: Array = old.run["party"].duplicate(true)
	var monsters: Array = old.run["monsters"].duplicate(true)
	var expected: Array = DungeonTraits.first_offer(84917)
	var loaded = game_at(t, "trait_legacy_pending_first")
	t.check(loaded.load_game() and loaded.run["phase"] == "trait" and loaded.trait_choices() == expected and loaded.run["first_trait_offer"] == expected, "A legacy pending first reward without saved offers generates and persists its stable pair once")
	t.check(loaded.rng.state == random_before and loaded.run["party"] == party and loaded.run["monsters"] == monsters, "Legacy pending-offer migration does not alter encounter, gameplay RNG, roster or recovery")
	var reloaded = game_at(t, "trait_legacy_pending_first")
	t.check(reloaded.load_game() and reloaded.trait_choices() == expected and reloaded.rng.state == random_before, "A second legacy Continue restores the generated pair without rerolling")
	var before: Dictionary = reloaded.run.duplicate(true)
	reloaded.save_calls = 0
	var unavailable: String = str(DungeonTraits.choices([]).filter(func(id): return not expected.has(id))[0])
	t.check(not reloaded.choose_trait(unavailable) and reloaded.run == before and reloaded.save_calls == 0 and reloaded.rng.state == random_before, "Legacy first rewards also reject known traits outside their saved pair")
	for phase in ["victory", "defeat"]:
		var terminal = game_at(t, "trait_legacy_terminal_" + phase)
		terminal.new_run(4819)
		terminal.run["raid"] = 6 if phase == "victory" else 1
		terminal.run["phase"] = phase
		if phase == "defeat":
			for monster in terminal.run["monsters"]: monster["hp"] = 0
		terminal.save_game()
		var terminal_rng: int = terminal.rng.state
		var terminal_loaded = game_at(t, "trait_legacy_terminal_" + phase)
		t.check(terminal_loaded.load_game() and terminal_loaded.run["phase"] == phase and not terminal_loaded.run.has("first_trait_offer") and terminal_loaded.trait_choices().is_empty() and terminal_loaded.rng.state == terminal_rng, "Terminal legacy saves generate no first reward or RNG changes: " + phase)

func test_legacy_feeding_order(t) -> void:
	var old = game_at(t, "trait_old_partial_first_meal")
	old.new_run(83715)
	old.run["monsters"][0]["hp"] = 5
	old.run["monsters"][1]["hp"] = 0
	fixture_win(old)
	# Explicit v0.14 snapshot: the first meal was already underway, with its
	# trait still owed only after recovery. Preserve that in-progress destination.
	old.run["phase"] = "feeding"
	old.run.erase("trait_return")
	old.run.erase("first_trait_offer")
	t.check(old.claim_body(0, "m1"), "Legacy partial meal fixture resolves one real weighted corpse through the production API")
	old.save_game()
	var bodies: Array = old.run["rewards"].duplicate(true)
	var monsters: Array = old.run["monsters"].duplicate(true)
	var recap: Dictionary = old.run["raid_recap"].duplicate(true)
	var random_before: int = old.rng.state
	var loaded = game_at(t, "trait_old_partial_first_meal")
	t.check(loaded.load_game() and loaded.run["phase"] == "feeding" and loaded.run["raid"] == 0 and not loaded.run.has("trait_return") and not loaded.run.has("first_trait_offer") and loaded.trait_choices().is_empty(), "An old already-feeding first raid continues its meal without inserting an early trait screen")
	t.check(loaded.run["rewards"] == bodies and loaded.run["monsters"] == monsters and loaded.run["raid_recap"] == recap and loaded.rng.state == random_before and loaded.run["recovered_id"] == 0, "Old partial meals preserve exact roll/recipient, raw HP, corpse claims, recap and unrecovered RNG boundary")
	var before: Dictionary = loaded.run.duplicate(true)
	loaded.save_calls = 0
	t.check(not loaded.claim_body(0, "m1") and loaded.run == before and loaded.save_calls == 0 and loaded.rng.state == random_before, "The old resolved body cannot be rerolled while finishing its existing meal")
	t.check(finish_fixture_meals(loaded) and loaded.run["phase"] == "trait" and loaded.run.get("trait_return", "") == "result" and loaded.run["raid"] == 1 and loaded.run["recovered_id"] == loaded.run["resolved_id"], "Finishing an old first meal retains its post-recovery trait destination")
	t.check(loaded.run["monsters"][0]["hp"] == 10 and loaded.run["monsters"][1]["hp"] == 5 and loaded.rng.state == random_before and loaded.trait_choices() == DungeonTraits.first_offer(83715), "Legacy postmeal reward applies recovery once and uses the same deterministic offer without another corpse roll")
	var postmeal = game_at(t, "trait_old_partial_first_meal")
	t.check(postmeal.load_game() and postmeal.run["phase"] == "trait" and postmeal.run.get("trait_return", "") == "result" and postmeal.rng.state == random_before, "An old pending postmeal first choice remains postmeal after Continue")
	var recovered_hp: Array = postmeal.run["monsters"].map(func(monster): return monster["hp"])
	t.check(postmeal.choose_trait(str(postmeal.trait_choices()[0])) and postmeal.run["phase"] == "result" and postmeal.run["monsters"].map(func(monster): return monster["hp"]) == recovered_hp and postmeal.current_report()["summary"]["recoveries"] == 1 and postmeal.current_report()["summary"]["bodies_claimed"] == 1, "Choosing a legacy postmeal trait cannot reopen feeding or duplicate recovery/inheritance reports")
	var active = game_at(t, "trait_old_first_active")
	active.new_run(56104)
	active.start_raid()
	var battle_before: Dictionary = active.battle.to_dict()
	active.save_game()
	var continued = game_at(t, "trait_old_first_active")
	t.check(continued.load_game() and continued.run["phase"] == "combat" and not continued.run.has("first_trait_offer") and t.same_saved_value(continued.battle.to_dict(), battle_before), "An existing first-raid active save preserves combat, intents and RNG without granting an early reward mid-turn")
	for enemy in continued.battle.enemies: enemy["hp"] = 0
	continued.end_turn()
	t.check(continued.run["phase"] == "trait" and continued.run.get("trait_return", "") == "feeding" and continued.run["raid"] == 0 and continued.run["recovered_id"] == 0 and continued.run["rewards"].all(func(body): return not body["claimed"]), "A continued active first raid adopts the early handoff only after its actual future win")
