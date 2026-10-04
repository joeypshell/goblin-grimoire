extends RefCounted

const Data = preload("res://scripts/game_data.gd")

func run(t) -> void:
	t.group("explicit timing, innate passives, KO feeding and deferred recovery fixtures")
	test_timing(t)
	test_passives(t)
	test_knocked_out_feeding(t)

func test_timing(t) -> void:
	var battle = t.fixture(t.roster(), [t.enemy("e0", "strike")])
	battle.hand = [t.card("guard")]
	t.check(battle.play_card(0, "m0") and battle.monsters[0]["block"] == 7, "Guard grants its defined block immediately")
	battle.end_turn()
	t.check(battle.monsters[0]["hp"] == 20 and battle.monsters[0]["block"] == 0, "Monster block absorbs announced damage then expires at next monster turn")
	var effects = t.fixture()
	effects.monsters[0]["hp"] = 10
	effects.monsters[0]["block"] = 99
	effects.monsters[0]["statuses"] = {"poison": 3, "burn": 2, "regen": 4}
	effects.end_turn()
	t.check(effects.monsters[0]["hp"] == 9, "Poison and burn bypass block before end-turn regeneration")
	t.check(effects.monsters[0]["statuses"] == {"poison": 2, "burn": 1, "regen": 3}, "Each damage/healing-over-time strength decays exactly one at afflicted turn end")
	effects.hand = [t.card("regrowth", "m0", "regen_a"), t.card("regrowth", "m0", "regen_b")]
	effects.play_card(0, "m0")
	effects.play_card(0, "m0")
	t.check(effects.monsters[0]["statuses"]["regen"] == 9, "Repeated Regrowth adds strength using the documented stacking rule")
	var dead_actor = t.fixture(t.roster(), [t.enemy("e0", "heavy_blow", 1), t.enemy("e1", "heavy_blow")])
	dead_actor.intents = [{"enemy_id": "e0", "ability": "heavy_blow", "target_id": "m0", "text": "locked"}, {"enemy_id": "e1", "ability": "heavy_blow", "target_id": "m0", "text": "locked"}]
	dead_actor.hand = [t.card("strike")]
	dead_actor.play_card(0, "e0")
	dead_actor.end_turn()
	t.check(dead_actor.monsters[0]["hp"] == 12, "Defeated enemy cannot complete its pending announced action")
	var people: Array = t.roster()
	people[0]["hp"] = 1
	var rotating = t.fixture(people, [t.enemy("e0", "heavy_blow"), t.enemy("e1", "strike")])
	rotating.intents = [{"enemy_id": "e0", "ability": "heavy_blow", "target_id": "m0", "text": "locked"}, {"enemy_id": "e1", "ability": "strike", "target_id": "m0", "text": "locked"}]
	rotating.end_turn()
	t.check(people[0]["hp"] == 0 and people[1]["hp"] == 14, "Locked frontline rotates only after its announced target is knocked out")
	var stunned = t.fixture(t.roster(), [t.enemy("e0", "snare")])
	stunned.end_turn()
	stunned.hand = [t.card("strike"), t.card("core_pulse", "", "shared_pulse")]
	t.check(stunned.monsters[0]["statuses"].get("stun", 0) == 1 and stunned.legal_targets(stunned.hand[0]).is_empty(), "Enemy Snare disables that monster's cards for the following player turn")
	t.check(not stunned.play_card(0, "e0") and stunned.energy == 3, "Stunned owner cannot spend a card or energy")
	t.check(not stunned.legal_targets(stunned.hand[1]).is_empty(), "Shared dungeon cards remain usable while a monster is stunned")
	stunned.intents = [{"enemy_id": "e0", "ability": "guard", "target_id": "e0", "text": "fixture"}]
	stunned.end_turn()
	t.check(stunned.monsters[0]["statuses"].get("stun", 0) == 0 and not stunned.legal_targets(t.card("strike")).is_empty(), "Friendly stun decays after its skipped player turn and cards become usable again")

func test_passives(t) -> void:
	var cases := [
		{"form": "green_ogre", "ability": "guard", "target": "m0", "check": "block", "amount": 9},
		{"form": "red_ogre", "ability": "strike", "target": "e0", "check": "burn", "amount": 1},
		{"form": "basilisk", "ability": "poisoned_blade", "target": "e0", "check": "poison", "amount": 4},
		{"form": "shadow_stalker", "ability": "strike", "target": "e0", "check": "damage", "amount": 8},
		{"form": "oni", "ability": "arcane_bolt", "target": "e0", "check": "damage", "amount": 9},
		{"form": "ember_basilisk", "ability": "poisoned_blade", "target": "e0", "check": "burn", "amount": 2}
	]
	for sample in cases:
		var people: Array = t.roster()
		people[0]["form"] = sample["form"]
		var battle = t.fixture(people)
		if sample["form"] == "shadow_stalker":
			battle.enemies[0]["statuses"]["poison"] = 1
		battle.hand = [t.card(sample["ability"])]
		t.check(battle.play_card(0, sample["target"]), "Evolved form can play its chosen ability: " + sample["form"])
		var target: Dictionary = battle.get_actor(sample["target"])
		var actual: int
		if sample["check"] == "block":
			actual = target["block"]
		elif sample["check"] == "damage":
			actual = 500 - target["hp"]
		else:
			actual = target["statuses"].get(sample["check"], 0)
		t.check(actual == sample["amount"], "Form passive changes battle mechanics: " + sample["form"])

func test_knocked_out_feeding(t) -> void:
	var game = t.state_at("knocked_out_feeding")
	game.new_run(321)
	game.start_raid()
	game.run["monsters"][0]["hp"] = 0
	game.run["monsters"][1]["hp"] = 6
	for actor in game.battle.enemies:
		actor["hp"] = 0
	game.end_turn()
	t.check(game.run["phase"] == "feeding" and game.run["monsters"][0]["hp"] == 0 and game.run["monsters"][1]["hp"] == 6, "Victory defers recovery until its feeding phase finishes")
	var monster: Dictionary = game.run["monsters"][0]
	t.check(game.claim_body(0, monster["id"], "heavy_blow"), "A knocked-out monster can consume a defeated body independent of killing blow")
	t.check(game.claim_body(1, monster["id"], "firebolt"), "Knocked-out recipient can absorb another actual body")
	# Explicit rare-state fixture: both lineages earned, so budget—not unmet requirements—blocks a chain.
	monster["learned"].append("arcane_bolt")
	monster["consumed"].append("arcane_bolt")
	monster["feeds"] = 4
	t.check(game.evolve(monster["id"], "red_ogre") and monster["hp"] == 0, "Evolution preserves knockout until normal recovery")
	t.check(not game.eligible(monster["id"]).is_empty(), "Later branch is actually earned in the chained-evolution fixture")
	t.check(not game.evolve(monster["id"], "oni"), "One feeding decision cannot produce an automatic transformation chain")
	for index in range(game.run["rewards"].size()):
		game.skip_body(index)
	t.check(game.finish_feeding(), "KO feeding completion resolves once")
	t.check(monster["hp"] == 8 and game.run["monsters"][1]["hp"] == 11, "Recovery uses evolved maximum HP and heals six-HP goblin to eleven")
	var recovered: Array = game.run["monsters"].map(func(m): return m["hp"])
	game.save_game()
	var reload = t.state_at("knocked_out_feeding")
	reload.load_game()
	reload.continue_after_result()
	t.check(t.same_saved_value(reload.run["monsters"].map(func(m): return m["hp"]), recovered), "Saved successful result cannot duplicate post-feeding recovery")
	t.check(not reload.eligible(monster["id"]).is_empty(), "Declined later branch persists into next preparation")
	reload.start_raid()
	var restored_cards := 0
	for value in t.all_cards(reload.battle):
		if value["owner"] == monster["id"]:
			restored_cards += 1
	t.check(restored_cards == 3 and reload.run["monsters"][0]["hp"] == 8, "Recovered KO owner's three configured cards return next raid without an automatic full heal")
