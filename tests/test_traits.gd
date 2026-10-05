extends RefCounted

const CountingState = preload("res://tests/flow_state_fixture.gd")
const CombatTraits = preload("res://tests/test_trait_combat.gd")

func run(t) -> void:
	t.group("earned trait choices, single recovery, saved milestones and legacy boundaries")
	test_progression(t)
	test_legacy(t)
	CombatTraits.new().run(t)

func game_at(t, tag: String):
	return CountingState.new(t.profile_root + tag + "/")

func fixture_victory(game) -> bool:
	# Explicit phase fixture; the campaign test wins with production cards/HP.
	game.start_raid()
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	return game.finish_feeding()

func test_progression(t) -> void:
	var game = game_at(t, "trait_progression")
	game.new_run(40419)
	t.check(game.run["traits"].is_empty() and game.run["trait_milestones"].is_empty(), "New runs start with no traits or already claimed milestones")
	game.save_calls = 0
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	t.check(not game.choose_trait("venom_nest") and game.run == before and game.rng.state == random_before and game.save_calls == 0, "Trait cannot be selected before an earned reward; rejection is mutation/RNG/save free")
	game.run["monsters"][0]["hp"] = 5
	t.check(fixture_victory(game) and game.run["raid"] == 1 and game.run["phase"] == "trait", "First resolved raid opens the first earned trait phase")
	var recovered_hp: Array = game.run["monsters"].map(func(m): return m["hp"])
	t.check(recovered_hp[0] == 10 and game.run["recovered_id"] == game.run["resolved_id"], "Recovery commits exactly once before the trait choice")
	var choices: Array = game.trait_choices()
	before = game.run.duplicate(true)
	random_before = game.rng.state
	game.save_calls = 0
	for query in range(10): game.trait_choices()
	game.start_raid()
	game.continue_after_result()
	t.check(choices.size() == 3 and game.run == before and game.rng.state == random_before and game.save_calls == 0, "Queries and premature continuation cannot leave or reroll a pending trait choice")
	t.check(not game.choose_trait("missing_trait") and game.run == before and game.rng.state == random_before and game.save_calls == 0, "Unknown trait choice changes no state, RNG or persistence")
	game.save_game()
	var loaded = game_at(t, "trait_progression")
	t.check(loaded.load_game() and loaded.run["phase"] == "trait" and loaded.trait_choices() == choices, "Continue restores the exact pending first trait choices")
	loaded.save_calls = 0
	t.check(loaded.choose_trait("venom_nest") and loaded.run["traits"] == ["venom_nest"] and loaded.run["trait_milestones"] == [1] and loaded.run["phase"] == "result", "One actual choice records its milestone and reaches the intended result phase")
	t.check(loaded.rng.state == random_before and loaded.save_calls == 1 and loaded.run["monsters"].map(func(m): return m["hp"]) == recovered_hp, "Valid trait selection saves once without consuming RNG or repeating recovery")
	before = loaded.run.duplicate(true)
	t.check(not loaded.choose_trait("pack_instinct") and loaded.run == before, "Double selection cannot award a second trait from one milestone")
	var continued = game_at(t, "trait_progression")
	t.check(continued.load_game() and continued.run["traits"] == ["venom_nest"] and continued.run["phase"] == "result", "Selected trait and milestone persist without reopening their reward")
	continued.continue_after_result()
	t.check(fixture_victory(continued) and continued.run["raid"] == 2 and continued.run["phase"] == "result", "The middle F raid does not award an extra trait")
	continued.continue_after_result()
	t.check(fixture_victory(continued) and continued.run["raid"] == 3 and continued.run["phase"] == "trait" and continued.run["promotion"] == "E", "F champion milestone opens the second trait alongside promotion to E")
	t.check(not continued.trait_choices().has("venom_nest") and continued.trait_choices().size() == 2, "Previously selected traits cannot appear again")
	before = continued.run.duplicate(true)
	random_before = continued.rng.state
	continued.save_calls = 0
	t.check(not continued.choose_trait("venom_nest") and continued.run == before and continued.rng.state == random_before and continued.save_calls == 0, "Duplicate trait rejection does not advance or save the reward")
	t.check(continued.choose_trait("spiteful_shields") and continued.run["trait_milestones"] == [1, 3] and continued.run["traits"] == ["venom_nest", "spiteful_shields"], "Second milestone grants another distinct run-long trait")
	continued.continue_after_result()
	continued.start_raid()
	t.check(continued.battle.traits == continued.run["traits"] and continued.battle.trait_state["owners"].is_empty(), "Next real raid receives selected traits with fresh per-battle progress")
	continued.new_run(1772)
	t.check(continued.run["traits"].is_empty() and continued.run["trait_milestones"].is_empty(), "New Run clears chosen traits and milestone progress")

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
	t.check(loaded.choose_trait("pack_instinct") and loaded.run["phase"] == "trait" and loaded.run["trait_milestones"] == [1], "First of two owed legacy milestones keeps the reward screen open")
	var pending = game_at(t, "trait_legacy_prep")
	t.check(pending.load_game() and pending.trait_choices().size() == 2 and not pending.trait_choices().has("pack_instinct"), "Partly selected legacy rewards reload with only remaining traits")
	t.check(pending.choose_trait("venom_nest") and pending.run["phase"] == "prep" and pending.run["trait_milestones"] == [1, 3] and pending.rng.state == random_before, "Second legacy reward returns to the original preparation without RNG consumption")
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
	t.check(combat_loaded.battle.hand == snapshot["battle"]["hand"] and combat_loaded.battle.intents == snapshot["battle"]["intents"] and str(combat_loaded.rng.state) == snapshot["rng_state"], "Trait-less legacy combat preserves hand, announced actions and RNG")
	for enemy in combat_loaded.battle.enemies: enemy["hp"] = 0
	combat_loaded.end_turn()
	for index in range(combat_loaded.run["rewards"].size()): combat_loaded.skip_body(index)
	t.check(combat_loaded.finish_feeding() and combat_loaded.run["phase"] == "trait", "Legacy active run offers owed traits only after its combat/feeding boundary")
	t.choose_campaign_trait(combat_loaded)
	t.check(combat_loaded.run["phase"] == "result" and combat_loaded.run["traits"].size() == 2, "Deferred legacy rewards return to the proper result after both choices")
