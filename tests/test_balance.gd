extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")

func run(t) -> void:
	t.group("energy tradeoffs, independent applications, Resolve, seeded targets and new lineages")
	test_card_tradeoffs(t)
	test_layers(t)
	test_resolve(t)
	test_targets_and_priests(t)
	test_status_saves(t)
	test_lineages(t)
	test_driver(t)

func lock(battle, ability: String = "heavy_blow", target: String = "m0") -> void:
	battle.intents = [{"enemy_id": "e0", "ability": ability, "target_id": target, "text": "Fixture locked action"}]

func test_card_tradeoffs(t) -> void:
	var battle = t.fixture()
	battle.hand = [t.card("heavy_blow")]
	battle.energy = 1
	var before: Dictionary = battle.to_dict()
	t.check(not battle.play_card(0, "e0") and t.same_saved_value(before, battle.to_dict()), "Two-energy Heavy Blow rejects one energy without any combat/RNG mutation")
	battle.energy = 2
	t.check(battle.play_card(0, "e0") and battle.energy == 0 and battle.enemies[0]["hp"] == 488, "Heavy Blow spends two energy for twelve immediate damage")
	battle = t.fixture()
	battle.hand = [t.card("strike")]
	t.check(battle.play_card(0, "e0") and battle.energy == 2 and battle.enemies[0]["hp"] == 494, "Strike remains a distinct affordable six-damage one-energy card")
	battle.hand = [t.card("shield_wall")]
	t.check(battle.play_card(0, "m0") and battle.energy == 0 and battle.monsters.all(func(m): return m["block"] == 8), "Shield Wall costs two energy and gives every living ally eight block")
	var support = t.fixture()
	var patient: Dictionary = support.monsters[0]
	patient["hp"] = 8
	support._status(patient, "poison", 3)
	support._status(patient, "burn", 2)
	support._status(patient, "regen", 3)
	patient["statuses"]["evasion"] = 1
	support.hand = [t.card("mend")]
	t.check(support.play_card(0, "m0") and patient["hp"] == 12 and support.energy == 2, "Mend trades healing magnitude for cleanse at one energy")
	t.check(not patient["statuses"].has("poison") and not patient["statuses"].has("burn") and not patient["status_layers"].has("poison") and not patient["status_layers"].has("burn"), "Mend cleanses both harmful aggregates and their application layers")
	t.check(patient["statuses"].get("regen", 0) == 3 and patient["statuses"].get("evasion", 0) == 1, "Cleanse preserves beneficial regeneration and evasion")
	support._status(patient, "poison", 3)
	support.hand = [t.card("patch_up")]
	t.check(support.play_card(0, "m0") and patient["hp"] == 18 and patient["statuses"].get("poison", 0) == 3, "Patch Up still heals six but cannot replace Mend's cleansing utility")
	for id in ["ogre_aegis", "burning_cleave", "petrifying_gaze", "spirit_flame", "ember_venom", "renewing_aegis", "nightfall"]:
		var signature = t.fixture()
		signature.hand = [t.card(id)]
		signature.energy = 1
		var target: String = signature.legal_targets(signature.hand[0])[0]
		t.check(int(Data.ABILITIES[id]["cost"]) == 2 and not signature.play_card(0, target), "Area/control signature cannot bypass its two-energy cost: " + id)
		signature.energy = 2
		t.check(signature.play_card(0, target) and signature.energy == 0, "Affordable signature uses its defined energy through normal card API: " + id)

func test_layers(t) -> void:
	for status_id in ["poison", "burn", "regen"]:
		var battle = t.fixture()
		var actor: Dictionary = battle.enemies[0] if status_id != "regen" else battle.monsters[0]
		actor["hp"] = 50
		actor["max_hp"] = 100
		actor["armor"] = 9
		actor["block"] = 99
		battle._status(actor, status_id, 3)
		battle._status(actor, status_id, 3)
		t.check(actor["status_layers"][status_id] == [3, 3] and actor["statuses"][status_id] == 6, "Reapplication stores two separate layers with a summed display: " + status_id)
		for amount in [6, 4, 2]:
			var hp_before: int = actor["hp"]
			battle._tick_statuses([actor])
			var actual: int = actor["hp"] - hp_before if status_id == "regen" else hp_before - actor["hp"]
			t.check(actual == amount, "Independent applications tick %d, rather than an extended summed tail: %s" % [amount, status_id])
		t.check(actor["hp"] == (62 if status_id == "regen" else 38) and not actor["statuses"].has(status_id) and not actor["status_layers"].has(status_id), "Two strength-three applications total twelve and expire completely: " + status_id)
	var cards = t.fixture()
	cards.hand = [t.card("poisoned_blade", "m0", "poison_a"), t.card("poisoned_blade", "m1", "poison_b")]
	t.check(cards.play_card(0, "e0") and cards.play_card(0, "e0"), "Different real card instances can apply the same status")
	var enemy: Dictionary = cards.enemies[0]
	t.check(enemy["hp"] == 492 and enemy["status_layers"]["poison"] == [3, 3], "Poisoned Blade keeps both direct hits and independent applications")
	for tick in range(3): cards._tick_statuses(cards.enemies)
	t.check(enemy["hp"] == 480, "Two Poisoned Blades deal eight direct plus twelve damage over time")
	var lethal = t.fixture()
	lethal.monsters[0]["hp"] = 1
	lethal._status(lethal.monsters[0], "poison", 3)
	lethal._status(lethal.monsters[0], "regen", 3)
	lethal._tick_statuses(lethal.monsters)
	t.check(lethal.monsters[0]["hp"] == 0 and lethal.monsters[0]["statuses"].is_empty() and lethal.monsters[0]["status_layers"].is_empty(), "Lethal damage clears layers and cannot regenerate a knocked-out owner")

func test_resolve(t) -> void:
	var battle = t.fixture()
	for actor in battle.monsters: actor["hp"] = 100; actor["max_hp"] = 100
	battle.hand = [t.card("snare", "m0", "control_a"), t.card("snare", "m1", "control_b")]
	t.check(battle.play_card(0, "e0") and battle.play_card(0, "e0") and battle.enemies[0]["statuses"].get("stun", 0) == 1, "Repeated Snare deals its damage but cannot stack skipped actions")
	lock(battle)
	battle.end_turn()
	var foe: Dictionary = battle.enemies[0]
	t.check(battle.monsters[0]["hp"] == 100 and foe["statuses"].get("stun", 0) == 0 and foe["statuses"].get("resolve", 0) == 1, "Skipping an announced action consumes stun and grants Resolve")
	battle.hand = [t.card("snare")]
	var hp_before: int = foe["hp"]
	t.check(battle.play_card(0, "e0") and foe["hp"] == hp_before - 3 and foe["statuses"].get("stun", 0) == 0, "Resolve prevents restun while allowing the card's damage")
	lock(battle)
	battle.end_turn()
	t.check(battle.monsters[0]["hp"] == 88 and foe["statuses"].get("resolve", 0) == 0, "Previously stunned enemy completes its next normal action before Resolve expires")
	battle.hand = [t.card("snare")]
	t.check(battle.play_card(0, "e0") and foe["statuses"].get("stun", 0) == 1, "Stun becomes available again after a normal enemy action")
	var friendly = t.fixture(t.roster(), [t.enemy("e0", "snare")])
	var owner: Dictionary = friendly.monsters[0]
	friendly._status(owner, "stun", 1)
	friendly._status(owner, "stun", 1)
	t.check(owner["statuses"]["stun"] == 1 and friendly.legal_targets(t.card("strike")).is_empty(), "Friendly stun is also nonstacking and blocks owned cards")
	lock(friendly, "snare")
	friendly.end_turn()
	t.check(owner["statuses"].get("resolve", 0) == 1 and owner["statuses"].get("stun", 0) == 0 and not friendly.legal_targets(t.card("strike")).is_empty(), "Recovered monster resists enemy restun and can play during its protected player turn")
	lock(friendly, "snare")
	friendly.end_turn()
	t.check(owner["statuses"].get("resolve", 0) == 0 and owner["statuses"].get("stun", 0) == 1, "Friendly Resolve expires after its normal player turn, allowing a later stun")

func test_targets_and_priests(t) -> void:
	var destinations := {}
	for seed_value in range(32):
		var random := RandomNumberGenerator.new()
		random.seed = seed_value + 1914
		var battle = Combat.new()
		battle.setup(t.roster(), [t.enemy("e0", "strike"), t.enemy("e1", "strike"), t.enemy("e2", "strike")], random)
		var saved: Dictionary = battle.to_dict()
		for intent in battle.intents:
			destinations[intent["target_id"]] = true
			t.check(["m0", "m1", "m2"].has(intent["target_id"]), "Production offensive intent locks a living monster destination")
		var copy = Combat.new()
		copy.restore(saved, saved["monster_combat"].duplicate(true), RandomNumberGenerator.new())
		t.check(t.same_saved_value(saved, copy.to_dict()), "Restoring seeded offensive targets preserves locked intentions and RNG")
	t.check(destinations.size() == 3, "Seeded targeting reaches rear monsters instead of always focusing frontline")
	var redirected = t.fixture(t.roster(), [t.enemy("e0", "strike"), t.enemy("e1", "strike")])
	redirected.monsters[2]["hp"] = 1
	redirected.intents = [{"enemy_id": "e0", "ability": "strike", "target_id": "m2", "text": "locked"}, {"enemy_id": "e1", "ability": "strike", "target_id": "m2", "text": "locked"}]
	redirected.end_turn()
	t.check(redirected.monsters[2]["hp"] == 0 and redirected.monsters[0]["hp"] == 14 and redirected.monsters[1]["hp"] == 20, "KO of a random rear target redirects only subsequent locked actions to the first survivor")
	var priests := 0
	for seed_value in range(32):
		var random := RandomNumberGenerator.new()
		random.seed = seed_value + 472
		for raid in range(6):
			for actor in Data.generate_party(raid, random):
				if actor["class_name"] != "priest": continue
				priests += 1
				t.check(actor["abilities"].has("arcane_bolt"), "Every generated priest can attack even when its healing choices are redundant")
				var battle = t.fixture(t.roster(), [actor])
				t.check(battle.intents[0]["ability"] == "arcane_bolt", "Healthy lone production priest announces offense rather than empty healing")
				battle.end_turn()
				t.check(battle.monsters.map(func(m): return m["hp"]).reduce(func(a, b): return a + b, 0) == 53, "Production priest's locked Arcane Bolt actually deals seven HP damage")
	t.check(priests > 0, "Priest-offense coverage exercised generated encounters")

func test_status_saves(t) -> void:
	var game = t.state_at("balance_status_save")
	game.new_run(8172)
	game.start_raid()
	var actor: Dictionary = game.battle.enemies[0]
	game.battle._status(actor, "poison", 3)
	game.battle._status(actor, "poison", 3)
	actor["statuses"]["resolve"] = 1
	game.battle.monsters[0]["hp"] = 10
	game.battle._status(game.battle.monsters[0], "regen", 3)
	game.battle._status(game.battle.monsters[0], "regen", 1)
	game.save_game()
	var loaded = t.state_at("balance_status_save")
	t.check(loaded.load_game() and t.same_saved_value(game.battle.to_dict(), loaded.battle.to_dict()), "Layered status strengths, Resolve, hand and RNG survive a real combat save")
	game.end_turn()
	loaded.end_turn()
	t.check(t.same_saved_value(game.run, loaded.run) and t.same_saved_value(game.battle.to_dict(), loaded.battle.to_dict()), "Saved layered battle continues identically through actions, decay, targeting and shuffle")
	var legacy = t.fixture(t.roster(), [t.enemy("e0", "mend")])
	legacy.enemies[0]["class_name"] = "priest"
	legacy.enemies[0]["form"] = "priest"
	legacy.enemies[0]["abilities"] = ["mend", "regrowth"]
	var saved: Dictionary = legacy.to_dict()
	for value in saved["monster_combat"] + saved["enemies"]: value.erase("status_layers")
	saved["enemies"][0]["statuses"] = {"poison": 3, "resolve": 1}
	var copy = Combat.new()
	copy.restore(saved, saved["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(copy.enemies[0]["status_layers"]["poison"] == [3] and copy.enemies[0]["statuses"]["poison"] == 3, "Legacy numeric poison restores as one application, never three separate applications")
	t.check(copy.enemies[0]["abilities"] == saved["enemies"][0]["abilities"] and copy.intents == saved["intents"] and str(copy.rng.state) == saved["rng_state"], "Pure Battle restore preserves fixture ability pools, saved action and RNG")
	var hp_before: int = copy.enemies[0]["hp"]
	for tick in range(3): copy._tick_statuses(copy.enemies)
	t.check(copy.enemies[0]["hp"] == hp_before - 6 and not copy.enemies[0]["statuses"].has("poison"), "Migrated one-application poison retains the original three-two-one continuation")
	var old_control = t.fixture(t.roster(), [t.enemy("e0", "guard")])
	var old_snapshot: Dictionary = old_control.to_dict()
	old_snapshot["monster_combat"][0]["statuses"] = {"stun": 3}
	var control_loaded = Combat.new()
	control_loaded.restore(old_snapshot, old_snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(control_loaded.monsters[0]["statuses"].get("stun", 0) == 1 and control_loaded.legal_targets(t.card("strike")).is_empty(), "Legacy three-charge friendly stun displays and blocks only one skipped turn")
	t.check(control_loaded.intents == old_snapshot["intents"] and str(control_loaded.rng.state) == old_snapshot["rng_state"], "Legacy stun normalization preserves locked intentions and RNG")
	control_loaded._tick_statuses(control_loaded.monsters)
	t.check(control_loaded.monsters[0]["statuses"].get("stun", 0) == 0 and control_loaded.monsters[0]["statuses"].get("resolve", 0) == 1 and not control_loaded.legal_targets(t.card("strike")).is_empty(), "One skipped legacy-stun turn grants Resolve and restores owned-card play")
	t.check(control_loaded.intents == old_snapshot["intents"] and str(control_loaded.rng.state) == old_snapshot["rng_state"], "Consuming legacy stun and granting Resolve do not reroll announced actions")
	var prep = t.state_at("balance_legacy_priest")
	prep.new_run(981)
	prep.run["party"] = [legacy.enemies[0].duplicate(true)]
	var rng_before: int = prep.rng.state
	prep.save_game()
	var prep_loaded = t.state_at("balance_legacy_priest")
	t.check(prep_loaded.load_game() and prep_loaded.party_preview()[0]["abilities"].has("arcane_bolt") and prep_loaded.rng.state == rng_before, "Old preparation save gains priest offense without changing RNG or regenerating its party")
	prep.start_raid()
	var locked_before: Array = prep.battle.intents.duplicate(true)
	rng_before = prep.rng.state
	prep.save_game()
	var combat_loaded = t.state_at("balance_legacy_priest")
	t.check(combat_loaded.load_game() and combat_loaded.run["party"][0]["abilities"].has("arcane_bolt") and combat_loaded.battle.enemies[0]["abilities"].has("arcane_bolt"), "Production Continue migrates both old active priest pools")
	t.check(combat_loaded.battle.intents == locked_before and combat_loaded.rng.state == rng_before, "Active priest migration preserves its already announced action and RNG")
	combat_loaded.end_turn()
	t.check(combat_loaded.battle.intents[0]["ability"] == "arcane_bolt", "Migrated healthy priest selects offense on its next newly announced action")
	combat_loaded.end_turn()
	t.check(combat_loaded.run["monsters"].map(func(m): return m["hp"]).reduce(func(a, b): return a + b, 0) == 53, "Continued legacy priest actually attacks through normal RunState end_turn")

func test_lineages(t) -> void:
	for sample in [{"source": "green_ogre", "result": "ancient_ogre", "ability": "mend"}, {"source": "shadow_stalker", "result": "nightstalker", "ability": "poisoned_blade"}]:
		var game = t.state_at("balance_lineage_" + sample["result"])
		game.new_run(3741)
		var actor: Dictionary = game.run["monsters"][0]
		actor["form"] = sample["source"]
		actor["max_hp"] = Data.FORMS[sample["source"]]["max_hp"]
		actor["hp"] = actor["max_hp"] / 2
		actor["feeds"] = 4
		actor["learned"].append(sample["ability"])
		t.check(game.eligible(actor["id"]).is_empty(), "New advanced branch requires an actually consumed affinity: " + sample["result"])
		actor["consumed"] = [sample["ability"]]
		t.check(game.eligible(actor["id"]).any(func(recipe): return recipe["id"] == sample["result"]), "Previously terminal first form now exposes its earned advanced branch")
		var skills: Array = actor["learned"].duplicate()
		t.check(game.evolve(actor["id"], sample["result"]) and actor["form"] == sample["result"] and actor["learned"] == skills, "New advanced evolution uses normal API and retains learned cards")
		game.start_raid()
		t.check(t.all_cards(game.battle).any(func(card): return card["owner"] == actor["id"] and card["ability"] == Data.FORMS[sample["result"]]["signature"]), "New evolved signature enters the real raid deck")
	var ancient = t.fixture()
	ancient.monsters[0]["form"] = "ancient_ogre"
	ancient.hand = [t.card("renewing_aegis")]
	for actor in ancient.monsters: actor["hp"] = 10
	t.check(ancient.play_card(0, "m0") and ancient.monsters.all(func(m): return m["hp"] == 13 and m["block"] == 10), "Ancient Ogre signature heals all allies and applies its plus-three block passive")
	var night = t.fixture()
	night.monsters[0]["form"] = "nightstalker"
	night._status(night.enemies[0], "poison", 1)
	night.hand = [t.card("nightfall")]
	t.check(night.play_card(0, "e0") and night.enemies[0]["hp"] == 490 and night.monsters[0]["statuses"].get("evasion", 0) == 1, "Nightstalker signature gains evasion and plus-three damage against a harmful-status victim")

func test_driver(t) -> void:
	var battle = t.fixture()
	battle.enemies[0]["statuses"]["evasion"] = 1
	battle.hand = [t.card("strike")]
	var before: float = t.position_value(battle)
	battle.play_card(0, "e0")
	t.check(t.position_value(battle) > before, "Tactical scorer values removing evasion even when no HP is lost")
	battle.enemies[0]["block"] = 20
	battle.hand = [t.card("strike")]
	before = t.position_value(battle)
	battle.play_card(0, "e0")
	t.check(t.position_value(battle) > before, "Tactical scorer values consuming block instead of discarding every zero-HP attack")
