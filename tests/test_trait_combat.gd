extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const Replay = preload("res://scripts/battle_replay.gd")
const Copy = preload("res://scripts/combat_copy.gd")

func run(t) -> void:
	t.group("Venom Nest, Spiteful Shields, Pack Instinct and announced champion counterplay")
	test_venom(t)
	test_shields(t)
	test_pack(t)
	test_pack_save(t)
	test_champion(t)
	test_replay(t)

func fixture(t, traits: Array, party: Array = [], people: Array = []):
	var battle = Combat.new()
	var random := RandomNumberGenerator.new()
	random.seed = 98124
	battle.setup(t.roster() if people.is_empty() else people, [t.enemy()] if party.is_empty() else party, random, traits)
	return battle

func count(battle, id: String) -> int:
	return int(battle.trait_state["trigger_counts"][id])

func test_venom(t) -> void:
	var battle = fixture(t, ["venom_nest"], [t.enemy("e0"), t.enemy("e1"), t.enemy("e2")])
	battle.enemies[0]["hp"] = 4
	battle._status(battle.enemies[0], "poison", 3)
	battle.hand = [t.card("strike")]
	t.check(battle.play_card(0, "e0") and battle.enemies[0]["hp"] == 0, "Normal direct card can defeat an already poisoned foe")
	t.check(battle.enemies[1]["status_layers"]["poison"] == [2] and battle.enemies[2]["status_layers"]["poison"] == [2], "Poisoned direct KO immediately spreads one independent application to each survivor")
	t.check(count(battle, "venom_nest") == 1 and battle.trait_state["venom_kos"] == ["e0"], "Venom records and reports that poisoned corpse exactly once")
	var saved: Dictionary = battle.to_dict()
	battle._damage(battle.enemies[0], 99)
	t.check(t.same_saved_value(saved, battle.to_dict()), "Repeated damage to the same corpse cannot spread poison or count another activation")
	var no_poison = fixture(t, ["venom_nest"], [t.enemy("e0", "guard", 4), t.enemy("e1")])
	no_poison.hand = [t.card("poisoned_blade")]
	no_poison.play_card(0, "e0")
	t.check(count(no_poison, "venom_nest") == 0 and no_poison.enemies[1]["statuses"].is_empty(), "A killing hit cannot retroactively poison its victim with a later card effect")
	for order in [["e0", "e1", "e2"], ["e2", "e1", "e0"]]:
		var party: Array = []
		for id in order: party.append(t.enemy(id))
		var dots = fixture(t, ["venom_nest"], party)
		dots.get_actor("e0")["hp"] = 1
		dots._status(dots.get_actor("e0"), "poison", 1)
		dots._status(dots.get_actor("e1"), "poison", 3)
		dots._tick_statuses(dots.enemies)
		t.check(dots.get_actor("e1")["hp"] == 497 and dots.get_actor("e1")["status_layers"]["poison"] == [2, 2], "Old poison ticks/decays once while fresh spread waits, independent of faction order")
		t.check(dots.get_actor("e2")["hp"] == 500 and dots.get_actor("e2")["statuses"]["poison"] == 2, "Newly spread poison cannot tick during the faction phase that created it")
		dots._tick_statuses(dots.enemies)
		t.check(dots.get_actor("e1")["hp"] == 493 and dots.get_actor("e2")["hp"] == 498 and count(dots, "venom_nest") == 1, "Queued applications begin on the following faction tick without replaying the source KO")
	var no_chain = fixture(t, ["venom_nest"], [t.enemy("e0", "guard", 1), t.enemy("e1", "guard", 1), t.enemy("e2")])
	no_chain._status(no_chain.enemies[0], "poison", 1)
	no_chain._tick_statuses(no_chain.enemies)
	t.check(no_chain.enemies[1]["hp"] == 1 and count(no_chain, "venom_nest") == 1, "Fresh spread cannot cause an immediate same-tick death chain")
	no_chain._tick_statuses(no_chain.enemies)
	t.check(no_chain.enemies[1]["hp"] == 0 and count(no_chain, "venom_nest") == 2 and no_chain.enemies[2]["hp"] == 498 and no_chain.enemies[2]["status_layers"]["poison"] == [1, 2], "A later poisoned KO adds a fresh layer after the survivor's old tick")
	var disabled = fixture(t, [], [t.enemy("e0", "guard", 1), t.enemy("e1")])
	disabled._status(disabled.enemies[0], "poison", 1)
	disabled._tick_statuses(disabled.enemies)
	t.check(disabled.enemies[1]["statuses"].is_empty(), "Poisoned KO has no spread without Venom Nest")
	battle.monsters[0]["hp"] = 1
	battle._status(battle.monsters[0], "poison", 1)
	battle._tick_statuses(battle.monsters)
	t.check(count(battle, "venom_nest") == 1, "Poisoned monster KO cannot activate the invader-only trait")
	var last = fixture(t, ["venom_nest"], [t.enemy("e0", "guard", 1)])
	last._status(last.enemies[0], "poison", 1)
	last.hand = [t.card("strike")]
	var random_before: int = last.rng.state
	last.play_card(0, "e0")
	t.check(last.outcome == "won" and last.trait_state["venom_kos"] == ["e0"] and count(last, "venom_nest") == 0 and last.rng.state == random_before, "Last poisoned foe is marked once without falsely reporting a spread or consuming RNG")
	var final_dots = fixture(t, ["venom_nest"], [t.enemy("e0", "guard", 1), t.enemy("e1", "guard", 1)])
	for actor in final_dots.enemies: final_dots._status(actor, "poison", 1)
	random_before = final_dots.rng.state
	final_dots._tick_statuses(final_dots.enemies)
	t.check(final_dots.enemies.all(func(actor): return actor["hp"] == 0) and final_dots.trait_state["venom_kos"] == ["e0", "e1"] and count(final_dots, "venom_nest") == 0 and final_dots.rng.state == random_before, "Queued final poison KOs mark each source without claiming spreads after all recipients die")

func test_shields(t) -> void:
	var battle = fixture(t, ["spiteful_shields"])
	var owner: Dictionary = battle.monsters[0]
	var foe: Dictionary = battle.enemies[0]
	owner["block"] = 3
	owner["armor"] = 2
	foe["armor"] = 1
	battle._resolve(Data.ABILITIES["strike"], foe, "m0")
	t.check(owner["hp"] == 19 and owner["block"] == 0 and foe["hp"] == 498 and count(battle, "spiteful_shields") == 1, "Absorbed direct damage causes exactly one three-damage retaliation respecting enemy armor")
	for exclusion in ["armor", "evasion", "dot", "lethal"]:
		var negative = fixture(t, ["spiteful_shields"])
		var target: Dictionary = negative.monsters[0]
		target["block"] = 5
		if exclusion == "armor": target["armor"] = 99
		if exclusion == "evasion": target["statuses"]["evasion"] = 1
		if exclusion == "lethal": target["hp"] = 1; target["block"] = 1
		if exclusion == "dot":
			negative._status(target, "poison", 3)
			negative._tick_statuses(negative.monsters)
		else: negative._resolve(Data.ABILITIES["strike"], negative.enemies[0], "m0")
		t.check(negative.enemies[0]["hp"] == 500 and count(negative, "spiteful_shields") == 0, "Armor/evasion/DOT or a dead defender cannot trigger backlash: " + exclusion)
	for defense in ["armor", "block", "evasion"]:
		var defended = fixture(t, ["spiteful_shields"])
		defended.monsters[0]["block"] = 7
		var attacker: Dictionary = defended.enemies[0]
		if defense == "armor": attacker["armor"] = 4
		if defense == "block": attacker["block"] = 7; attacker["armor"] = 2
		if defense == "evasion": attacker["statuses"]["evasion"] = 1
		defended._resolve(Data.ABILITIES["strike"], attacker, "m0")
		t.check(attacker["hp"] == 500 and count(defended, "spiteful_shields") == 1, "Actual retaliation can be prevented by normal defensive mechanics: " + defense)
		if defense == "block": t.check(attacker["block"] == 6, "Retaliation applies armor first and spends only the remaining one block")
		if defense == "evasion": t.check(not attacker["statuses"].has("evasion"), "Retaliation consumes the attacker's evasion without recursively triggering")
	var multi = fixture(t, ["spiteful_shields"])
	multi.monsters[0]["block"] = 8
	multi._resolve({"name": "Multi-hit fixture", "target": "enemy", "affinity": "Neutral", "effects": [{"kind": "damage", "amount": 2}, {"kind": "damage", "amount": 2}]}, multi.enemies[0], "m0")
	t.check(multi.enemies[0]["hp"] == 497 and count(multi, "spiteful_shields") == 1, "One announced multi-hit action retaliates once per blocked recipient, without recursion")
	var volley = fixture(t, ["spiteful_shields"], [t.enemy("e0", "banner_volley", 7)])
	for actor in volley.monsters: actor["block"] = 1
	volley._resolve(Data.ABILITIES["banner_volley"], volley.enemies[0], "m0")
	t.check(volley.monsters.all(func(m): return m["hp"] == 16 and m["statuses"].get("burn", 0) == 1), "Every volley damage/burn effect completes before queued retaliation can kill its caster")
	t.check(volley.enemies[0]["hp"] == 0 and count(volley, "spiteful_shields") == 3, "Three living blocked recipients retaliate until the attacker is defeated")

func test_pack(t) -> void:
	var battle = fixture(t, ["pack_instinct"])
	battle.hand = [t.card("strike", "m0", "first"), t.card("guard", "m0", "repeat"), t.card("rally", "", "shared"), t.card("strike", "m1", "second"), t.card("strike", "m2", "third")]
	battle.energy = 8
	battle.play_card(0, "e0")
	battle.play_card(0, "m0")
	battle.play_card(0, "m0")
	t.check(battle.trait_state["owners"] == ["m0"] and not battle.trait_state["pack_triggered"], "Repeated owner and shared dungeon plays cannot fake three different monsters")
	battle.play_card(0, "e0")
	var energy_before: int = battle.energy
	var hand_before: int = battle.hand.size()
	t.check(battle.play_card(0, "e0") and battle.energy == energy_before and battle.hand.size() == hand_before and battle.trait_state["pack_triggered"], "Third distinct owned play spends its cost then grants one energy and draws one card")
	t.check(battle.trait_state["owners"] == ["m0", "m1", "m2"] and count(battle, "pack_instinct") == 1, "Pack owner set and activation counter record one complete combo")
	battle.hand = [t.card("strike")]
	energy_before = battle.energy
	battle.play_card(0, "e0")
	t.check(battle.energy == energy_before - 1 and battle.hand.is_empty() and count(battle, "pack_instinct") == 1, "Further plays cannot repeat Pack's reward in the same player turn")
	battle.end_turn()
	t.check(battle.trait_state["owners"].is_empty() and not battle.trait_state["pack_triggered"] and count(battle, "pack_instinct") == 1, "New player turn resets combo progress while retaining activation totals")
	battle.hand = [t.card("strike", "m0"), t.card("strike", "m1"), t.card("strike", "m2")]
	for action in range(3): battle.play_card(0, "e0")
	t.check(count(battle, "pack_instinct") == 2 and battle.energy == 1, "The next turn can independently complete one new Pack combo")
	var rejected = fixture(t, ["pack_instinct"])
	rejected.hand = [t.card("strike")]
	rejected.energy = 0
	var before: Dictionary = rejected.to_dict()
	t.check(not rejected.play_card(0, "e0") and t.same_saved_value(before, rejected.to_dict()), "Rejected plays cannot progress or trigger Pack")
	var people: Array = t.roster()
	people[2]["hp"] = 0
	var compressed = fixture(t, ["pack_instinct"], [], people)
	compressed.energy = 8
	compressed.hand = [t.card("strike", "m0"), t.card("strike", "m1"), t.card("strike", "m0")]
	for action in range(3): compressed.play_card(0, "e0")
	t.check(count(compressed, "pack_instinct") == 0 and compressed.trait_state["owners"].size() == 2, "A two-survivor deck cannot earn the three-owner Pack bonus")

func test_pack_save(t) -> void:
	# Isolated two-owner edge fixture; actual earned traits use the campaign path.
	var game = t.state_at("trait_pack_save")
	game.new_run(9287)
	game.run["traits"] = ["pack_instinct"]
	game.start_raid()
	var owners: Array = game.run["monsters"].map(func(m): return m["id"])
	game.battle.hand = [t.card("strike", owners[0], "pack_a"), t.card("strike", owners[1], "pack_b"), t.card("strike", owners[2], "pack_c")]
	var target: String = game.battle.enemies[2]["id"]
	game.play_card(0, target)
	game.play_card(0, target)
	var before: Dictionary = game.battle.to_dict()
	var loaded = t.state_at("trait_pack_save")
	t.check(loaded.load_game() and t.same_saved_value(before, loaded.battle.to_dict()) and loaded.battle.trait_state["owners"].size() == 2, "Real Continue preserves partial Pack owners, hand, energy, traits and RNG")
	t.check(game.play_card(0, game.battle.enemies[0]["id"]) and loaded.play_card(0, loaded.battle.enemies[0]["id"]), "Both saved continuations complete the third owner's actual action")
	t.check(t.same_saved_value(game.battle.to_dict(), loaded.battle.to_dict()) and count(loaded.battle, "pack_instinct") == 1, "Pack bonus drawing and activation count continue identically after reload")
	var completed = t.state_at("trait_pack_save")
	t.check(completed.load_game() and completed.battle.trait_state["pack_triggered"] and count(completed.battle, "pack_instinct") == 1, "Completed Pack reward is persisted rather than replayed by load")
	completed.battle.hand = [t.card("strike", owners[0])]
	var energy_before: int = completed.battle.energy
	completed.play_card(0, completed.battle.enemies[0]["id"])
	t.check(completed.battle.energy == energy_before - 1 and completed.battle.hand.is_empty() and count(completed.battle, "pack_instinct") == 1, "Reloaded completed combo cannot award a duplicate energy/card")

func champion(t):
	var random := RandomNumberGenerator.new()
	random.seed = 6647
	var captain: Dictionary = Data.generate_party(2, random)[0]
	var people: Array = t.roster()
	for actor in people: actor["hp"] = 100; actor["max_hp"] = 100
	return fixture(t, [], [captain], people)

func test_champion(t) -> void:
	var battle = champion(t)
	t.check(battle.enemies[0].get("champion", "") == "cinder_banner" and battle.enemies[0]["abilities"].has("banner_volley"), "Generated Captain owns the marked actual inheritable champion ability")
	for round_number in range(1, 8):
		t.check(battle.turn == round_number and (battle.intents[0]["ability"] == "banner_volley") == (round_number % 3 == 0), "Champion announces Banner Volley only on each third player round")
		if round_number < 7: battle.end_turn()
	var controlled = champion(t)
	controlled.end_turn()
	controlled.end_turn()
	var captain: Dictionary = controlled.enemies[0]
	var before: Dictionary = controlled.to_dict()
	var announced: Dictionary = Copy.intent(controlled, captain)
	t.check(announced["targets"].size() == 3 and announced["damage"] == 5 and announced["line"].contains("ALL monsters") and t.same_saved_value(before, controlled.to_dict()), "Announced champion volley describes five damage per actual destination and preserves simulation/RNG")
	controlled.hand = [t.card("snare_dungeon", "")]
	var hp_before: Array = controlled.monsters.map(func(m): return m["hp"])
	t.check(controlled.play_card(0, captain["id"]), "Player can counter the announced champion volley with a real dungeon Snare")
	controlled.end_turn()
	t.check(controlled.monsters.map(func(m): return m["hp"]) == hp_before and captain["statuses"].get("resolve", 0) == 1, "Stunned Captain skips its entire announced volley then gains normal Resolve")
	var defeated = champion(t)
	defeated.end_turn()
	defeated.end_turn()
	defeated.enemies[0]["hp"] = 5
	defeated.hand = [t.card("strike")]
	t.check(defeated.play_card(0, defeated.enemies[0]["id"]) and defeated.outcome == "won", "Defeating the Captain before its announced volley cancels the pending action")
	var inherited = fixture(t, [], [t.enemy("e0"), t.enemy("e1")])
	inherited.hand = [t.card("banner_volley")]
	t.check(inherited.play_card(0, "e0") and inherited.energy == 1 and inherited.enemies.all(func(e): return e["hp"] == 495 and e["statuses"].get("burn", 0) == 1), "Inherited champion card uses its real two-energy area damage/burn definition")
	var ordinary: Dictionary = t.enemy("e0", "banner_volley")
	var people: Array = t.roster()
	for actor in people: actor["hp"] = 100; actor["max_hp"] = 100
	var normal = fixture(t, [], [ordinary], people)
	for round_number in range(4):
		t.check(normal.intents[0]["ability"] == "banner_volley" and normal._targets("all_enemies", normal.enemies[0], "m0").size() == 3, "Unmarked explicit ability pool retains ordinary relative-faction area effects without Captain rhythm")
		normal.end_turn()

func test_replay(t) -> void:
	var battle = fixture(t, ["venom_nest", "spiteful_shields"], [t.enemy("e0", "strike", 3), t.enemy("e1")])
	battle.monsters[0]["block"] = 1
	battle._status(battle.enemies[0], "poison", 1)
	battle.intents = [{"enemy_id": "e0", "ability": "strike", "target_id": "m0", "text": "fixture"}, {"enemy_id": "e1", "ability": "guard", "target_id": "e1", "text": "fixture"}]
	var before: Dictionary = battle.to_dict()
	var expected = Combat.new()
	expected.restore(before, before["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	expected.end_turn()
	var replay = Replay.make(battle)
	t.check(t.same_saved_value(expected.to_dict(), replay.to_dict()) and t.same_saved_value(before, battle.to_dict()), "Combined retaliation/poison-spread replay exactly matches ordinary simulation without mutating its source")
	t.check(count(replay, "venom_nest") == 1 and count(replay, "spiteful_shields") == 1 and replay.enemies[1]["hp"] == 498, "Actual retaliation KO activates Venom once and its poison ticks at the later normal phase")
	var action: Dictionary = replay.frames.filter(func(frame): return frame["kind"] == "enemy")[0]
	t.check(action["target_ids"].has("m0") and action["target_ids"].has("e0") and action["target_ids"].has("e1"), "Replay identifies original recipient, retaliated caster and poison-spread receiver")
	var saved = Combat.new()
	saved.restore(replay.to_dict(), replay.monsters.duplicate(true), RandomNumberGenerator.new())
	var saved_before: Dictionary = saved.to_dict()
	saved._damage(saved.enemies[0], 3)
	t.check(t.same_saved_value(saved_before, saved.to_dict()), "Reloaded dead poison source cannot reactivate a persisted trait event")
