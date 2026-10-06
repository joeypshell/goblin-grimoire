extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const Rules = preload("res://scripts/encounter_rules.gd")
const Tactics = preload("res://scripts/invader_tactics.gd")
const Routes = preload("res://scripts/raid_routes.gd")

func run(t) -> void:
	t.group("contrasting encounter puzzles: deferred ward, interruptible ritual, exact saves and previews")
	test_ward_damage(t)
	test_ward_exclusions(t)
	test_ward_recipients(t)
	test_ward_preview_and_continue(t)
	test_ritual_schedule(t)
	test_ritual_interrupt_and_continue(t)
	test_generation(t)

func captain(t, hp: int = 30) -> Dictionary:
	var actor: Dictionary = t.enemy("captain", "guard", hp)
	actor["name"] = "Ward Captain"
	actor["class_name"] = "defender"
	actor["form"] = "defender"
	actor["armor"] = 2
	actor["encounter_rule"] = "ward_captain"
	return actor

func companion(t, id: String, hp: int = 20) -> Dictionary:
	var actor: Dictionary = t.enemy(id, "guard", hp)
	actor["name"] = id.capitalize()
	return actor

func ward_battle(t, hp: int = 30):
	var battle = t.fixture([], [captain(t, hp), companion(t, "scout"), companion(t, "archer")])
	battle.energy = 30
	return battle

func play(t, battle, ability: String, target: String, owner: String = "m0") -> void:
	battle.hand = [t.card(ability, owner, "encounter_" + ability)]
	t.check(battle.play_card(0, target), "Encounter fixture plays the actual production card: " + ability)

func ward_logs(battle) -> Array:
	return battle.action_log.filter(func(line): return str(line).begins_with(Rules.WARD_LOG_PREFIX))

func test_ward_damage(t) -> void:
	var battle = ward_battle(t)
	var random_before: int = battle.rng.state
	play(t, battle, "strike", "captain")
	t.check(battle.enemies[0]["hp"] == 26 and battle.enemies[1]["block"] == 4 and battle.enemies[2]["block"] == 0, "Six direct damage loses four HP through captain Armor, then grants exactly four Block to one ally")
	t.check(ward_logs(battle).size() == 1 and str(ward_logs(battle)[0]).contains("Ward Captain") and str(ward_logs(battle)[0]).contains("Scout"), "Ward log identifies the captain and the reinforced recipient")
	t.check(battle.rng.state == random_before, "Ward damage, recipient choice and logging consume no RNG")
	play(t, battle, "strike", "captain")
	t.check(battle.enemies[0]["hp"] == 22 and battle.enemies[1]["block"] == 8 and ward_logs(battle).size() == 1, "Ward may trigger on another card, stacking Block once for that card")
	var multi = ward_battle(t)
	multi.action_log.clear()
	multi._resolve({"target": "enemy", "affinity": "Neutral", "effects": [{"kind": "damage", "amount": 3}, {"kind": "damage", "amount": 3}]}, multi.monsters[0], "captain")
	t.check(multi.enemies[0]["hp"] == 28 and multi.enemies[1]["block"] == 4 and ward_logs(multi).size() == 1, "Two damaging hits in one card respect Armor per hit and reinforce only once")
	var area = ward_battle(t)
	play(t, area, "ember_burst", "captain")
	t.check(area.enemies.map(func(actor): return actor["hp"]) == [29, 17, 17], "Area damage finishes on every recipient before a surviving captain grants Block")
	t.check(area.enemies[1]["block"] == 4 and area.enemies[2]["block"] == 0 and area.enemies.all(func(actor): return actor["statuses"].get("burn", 0) == 1), "Area card completes its Burn effects, then gives exactly one ally the deferred ward")
	var lethal = ward_battle(t, 1)
	play(t, lethal, "ember_burst", "captain")
	t.check(lethal.enemies.map(func(actor): return actor["hp"]) == [0, 17, 17] and lethal.enemies[1]["block"] == 0 and ward_logs(lethal).is_empty(), "A captain defeated by the whole card never grants its pending ward")
	var late_lethal = ward_battle(t, 3)
	late_lethal._resolve({"target": "enemy", "affinity": "Neutral", "effects": [{"kind": "damage", "amount": 3}, {"kind": "damage", "amount": 4}]}, late_lethal.monsters[0], "captain")
	t.check(late_lethal.enemies[0]["hp"] == 0 and late_lethal.enemies[1]["block"] == 0, "Nonlethal first hit cannot grant a ward when a later hit in the same card defeats its captain")
	var shatter = ward_battle(t)
	play(t, shatter, "strike", "captain")
	play(t, shatter, "shatter_guard", "scout")
	t.check(shatter.enemies[1]["hp"] == 13 and shatter.enemies[1]["block"] == 0, "Real Shatter Guard removes the captain's ward before its seven-damage hit")

func test_ward_exclusions(t) -> void:
	for exclusion in ["block", "armor", "evade", "status_only", "healing", "legacy"]:
		var battle = ward_battle(t)
		match exclusion:
			"block": battle.enemies[0]["block"] = 4
			"armor": battle.enemies[0]["armor"] = 6
			"evade": battle.enemies[0]["statuses"]["evasion"] = 1
			"legacy": battle.enemies[0].erase("encounter_rule")
		var ability: String = "petrifying_gaze" if exclusion == "status_only" else ("patch_up" if exclusion == "healing" else "strike")
		play(t, battle, ability, "m0" if exclusion == "healing" else "captain")
		t.check(battle.enemies[1]["block"] == 0 and battle.enemies[2]["block"] == 0 and ward_logs(battle).is_empty(), "Ward excludes non-damaging or unflagged outcomes: " + exclusion)
	var statuses = ward_battle(t)
	statuses._status(statuses.enemies[0], "poison", 3)
	statuses._status(statuses.enemies[0], "burn", 2)
	statuses._tick_statuses(statuses.enemies)
	t.check(statuses.enemies[0]["hp"] == 25 and statuses.enemies[1]["block"] == 0 and ward_logs(statuses).is_empty(), "Poison and Burn pierce Armor but never activate Ward")
	var pending: Array = []
	Rules.collect_damage(statuses, statuses.enemies[1], statuses.enemies[0], 3, pending)
	Rules.apply_after_card(statuses, pending)
	t.check(pending.is_empty() and statuses.enemies[1]["block"] == 0, "An enemy caster cannot activate player-attack Ward")
	var shared = ward_battle(t)
	shared.enemies[0]["armor"] = 0
	play(t, shared, "snare_dungeon", "captain", "")
	t.check(shared.enemies[0]["hp"] == 28 and shared.enemies[1]["block"] == 4, "An ownerless shared dungeon attack is a player attack and triggers only after real HP loss")

func test_ward_recipients(t) -> void:
	var ratios = ward_battle(t)
	ratios.enemies[1]["hp"] = 10
	ratios.enemies[1]["max_hp"] = 20
	ratios.enemies[2]["hp"] = 12
	ratios.enemies[2]["max_hp"] = 30
	play(t, ratios, "strike", "captain")
	t.check(ratios.enemies[1]["block"] == 0 and ratios.enemies[2]["block"] == 4, "Ward prefers the lowest health percentage, rather than the lowest absolute HP")
	var tie = ward_battle(t)
	tie.enemies[1]["hp"] = 10
	tie.enemies[1]["max_hp"] = 20
	tie.enemies[2]["hp"] = 20
	tie.enemies[2]["max_hp"] = 40
	play(t, tie, "strike", "captain")
	t.check(tie.enemies[1]["block"] == 4 and tie.enemies[2]["block"] == 0, "Exactly tied health ratios preserve party order without random selection")
	var fallen = ward_battle(t)
	fallen.enemies[1]["hp"] = 1
	play(t, fallen, "ember_burst", "captain")
	t.check(fallen.enemies[1]["hp"] == 0 and fallen.enemies[2]["hp"] == 17 and fallen.enemies[2]["block"] == 4, "Recipient selection occurs after area damage, ignoring an ally that died during that card")
	var alone = ward_battle(t)
	alone.enemies[1]["hp"] = 0
	alone.enemies[2]["hp"] = 0
	play(t, alone, "strike", "captain")
	t.check(alone.enemies[0]["block"] == 0 and ward_logs(alone).is_empty(), "The last surviving captain cannot reinforce itself")

func test_ward_preview_and_continue(t) -> void:
	for variant in ["strike", "area", "lethal", "evade", "blocked", "break_block"]:
		var battle = ward_battle(t, 1 if variant == "lethal" else 30)
		if variant == "evade": battle.enemies[0]["statuses"]["evasion"] = 1
		if variant == "blocked": battle.enemies[0]["block"] = 50
		if variant == "break_block": battle.enemies[0]["block"] = 50
		var ability: String = "ember_burst" if variant in ["area", "lethal"] else ("shatter_guard" if variant == "break_block" else "strike")
		battle.hand = [t.card(ability)]
		var snapshot: Dictionary = battle.to_dict()
		var original_action_log: Array = battle.action_log.duplicate()
		var expected: bool = variant not in ["lethal", "evade", "blocked"]
		for repeat in range(3):
			var preview: String = Rules.card_preview(battle, battle.hand[0], "captain")
			t.check(preview.contains("+4 Block") == expected, "Ward preview predicts the real whole-card outcome: " + variant)
		t.check(t.same_saved_value(snapshot, battle.to_dict()) and battle.action_log == original_action_log, "Repeated Ward previews preserve all original fields, logs, locked intentions and RNG")
		var resumed = Combat.new()
		resumed.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
		t.check(t.same_saved_value(snapshot, resumed.to_dict()), "Continue restores flags, defenses and locked targets without generating encounter state")
		t.check(battle.play_card(0, "captain") and resumed.play_card(0, "captain") and t.same_saved_value(battle.to_dict(), resumed.to_dict()), "Resumed and uninterrupted Ward resolution produce identical saved results")

func priest(t, flagged: bool = true) -> Dictionary:
	var actor: Dictionary = t.enemy("priest", "arcane_bolt", 100)
	actor["name"] = "Ritual Priest"
	actor["class_name"] = "priest"
	actor["form"] = "priest"
	actor["abilities"] = ["arcane_bolt", "mend", "regrowth", "renewal_ritual"] if flagged else ["arcane_bolt", "mend", "regrowth"]
	actor["tactics"] = true
	if flagged: actor["encounter_rule"] = "ritual_priest"
	return actor

func ritual_battle(t):
	var people: Array = t.roster()
	for monster in people:
		monster["hp"] = 1000
		monster["max_hp"] = 1000
	var party: Array = [priest(t), companion(t, "scout", 100), companion(t, "archer", 100)]
	party[1]["hp"] = 20
	party[2]["hp"] = 40
	return t.fixture(people, party)

func test_ritual_schedule(t) -> void:
	var battle = ritual_battle(t)
	for round_number in range(1, 9):
		var intent: Dictionary = battle.intents.filter(func(value): return value["enemy_id"] == "priest")[0]
		var expected: String = "renewal_ritual" if round_number % 3 == 2 else ("mend" if round_number == 3 else ("regrowth" if round_number == 6 else "arcane_bolt"))
		t.check(intent["ability"] == expected and battle.enemies[0]["abilities"].has(intent["ability"]), "Ritual priest announces its actual owned scheduled ability on round %d" % round_number)
		if expected == "renewal_ritual":
			t.check(intent["target_id"] != "priest" and intent["target_id"] == "scout", "Ritual targets another wounded invader by a stable health ratio")
		var before: Dictionary = battle.to_dict()
		for repeat in range(3):
			Rules.description(battle.enemies[0])
			Tactics.choose_ability(battle, battle.enemies[0], battle.enemies[0]["abilities"])
		t.check(t.same_saved_value(before, battle.to_dict()), "Inspecting ritual cadence and rule copy never rerolls announced target or consumes RNG")
		if round_number < 8: battle.end_turn()
	var solo = t.fixture([], [priest(t)])
	solo.enemies[0]["hp"] = 40
	solo.turn = 2
	t.check(Tactics.choose_ability(solo, solo.enemies[0], solo.enemies[0]["abilities"]) == "arcane_bolt", "A wounded priest with no wounded living other invader keeps its normal offense on ritual rounds")
	var healthy = ritual_battle(t)
	for actor in healthy.enemies: actor["hp"] = actor["max_hp"]
	healthy.turn = 2
	t.check(Tactics.choose_ability(healthy, healthy.enemies[0], healthy.enemies[0]["abilities"]) == "arcane_bolt", "A healthy party does not announce an empty ritual")
	var legacy = ritual_battle(t)
	legacy.enemies[0].erase("encounter_rule")
	legacy.enemies[0]["abilities"].erase("renewal_ritual")
	legacy.turn = 2
	t.check(Tactics.choose_ability(legacy, legacy.enemies[0], legacy.enemies[0]["abilities"]) == "arcane_bolt", "Unflagged older priest preserves its original cadence")

func test_ritual_interrupt_and_continue(t) -> void:
	var battle = ritual_battle(t)
	battle.end_turn()
	var snapshot: Dictionary = battle.to_dict()
	var resumed = Combat.new()
	resumed.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(t.same_saved_value(snapshot, resumed.to_dict()) and resumed.intents[0]["ability"] == "renewal_ritual", "Continue restores the already-announced ritual, its exact target and RNG")
	# Changing health after announcement must not redirect the locked recipient.
	battle.enemies[2]["hp"] = 1
	resumed.enemies[2]["hp"] = 1
	var hp_before: int = battle.enemies[1]["hp"]
	battle.end_turn()
	resumed.end_turn()
	t.check(battle.enemies[1]["hp"] == hp_before + 9 and battle.enemies[2]["hp"] == 1, "Announced ritual restores exactly nine HP to its locked target despite later target-priority changes")
	t.check(t.same_saved_value(battle.to_dict(), resumed.to_dict()), "Saved and uninterrupted ritual resolve the same numeric effects, future hand and intents")
	for interruption in ["stun", "defeat"]:
		var interrupted = ritual_battle(t)
		interrupted.end_turn()
		hp_before = interrupted.enemies[1]["hp"]
		if interruption == "stun":
			play(t, interrupted, "snare_dungeon", "priest", "")
		else:
			interrupted.enemies[0]["hp"] = 1
			play(t, interrupted, "strike", "priest")
		var save: Dictionary = interrupted.to_dict()
		var reloaded = Combat.new()
		reloaded.restore(save, save["monster_combat"].duplicate(true), RandomNumberGenerator.new())
		interrupted.end_turn()
		reloaded.end_turn()
		t.check(interrupted.enemies[1]["hp"] == hp_before and t.same_saved_value(interrupted.to_dict(), reloaded.to_dict()), "Real %s interrupts the locked ritual identically after Continue" % interruption)
		if interruption == "stun": t.check(interrupted.enemies[0]["statuses"].get("resolve", 0) == 1, "Interrupted ritual consumes the existing Stun and grants normal Resolve")
	var dead_target = ritual_battle(t)
	dead_target.end_turn()
	dead_target.enemies[0]["hp"] = 40
	dead_target.enemies[1]["hp"] = 0
	dead_target.enemies[2]["hp"] = 40
	dead_target.end_turn()
	t.check(dead_target.enemies[0]["hp"] == 40 and dead_target.enemies[2]["hp"] == 49, "A defeated ritual recipient retargets another wounded living ally without healing the priest")
	var inherited = t.fixture()
	inherited.monsters[0]["hp"] = 1
	inherited.energy = 6
	play(t, inherited, "renewal_ritual", "m0")
	play(t, inherited, "renewal_ritual", "m0")
	t.check(inherited.monsters[0]["hp"] == 19 and inherited.energy == 2, "Inherited Renewal Ritual remains an ordinary repeatable two-energy nine-HP heal, including its owner")

func test_generation(t) -> void:
	for seed_value in range(12):
		var random := RandomNumberGenerator.new()
		random.seed = 3901 + seed_value
		var standard: Array = Data.generate_party(1, random)
		t.check(standard[0].get("encounter_rule", "") == "ward_captain", "Only newly generated standard raid two opts into the captain's encounter rule")
		var options: Array = Routes.choices(1, seed_value + 3901, standard)
		var alternate: Array = options.filter(func(option): return option["id"] == "alternate")[0]["party"]
		var ritual: Array = alternate.filter(func(actor): return actor.get("encounter_rule", "") == "ritual_priest")
		t.check(ritual.size() == 1 and ritual[0]["abilities"].has("renewal_ritual"), "Alternative raid two owns one actual transferable ritual ability on its flagged priest")
		if not ritual.is_empty():
			var outcomes: Array = Data.inheritance_outcomes(ritual[0]["abilities"], [])
			t.check(outcomes.any(func(value): return value["ability"] == "renewal_ritual" and value["rarity"] == "rare" and value["weight"] == 1 and value["chance"] > 0.0), "Ritual is a random rare actual-corpse inheritance with the original four/two/one weighting")
		for raid in [0, 2, 3, 4, 5]:
			var ordinary: Array = Data.generate_party(raid, random)
			t.check(not ordinary.any(func(actor): return actor.get("encounter_rule", "") in ["ward_captain", "ritual_priest"]), "Other raids do not silently inherit raid two's special rules")
