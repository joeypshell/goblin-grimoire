extends RefCounted

const Combat = preload("res://scripts/battle.gd")
const Recap = preload("res://scripts/battle_recap.gd")
const Forms = preload("res://scripts/battle_forms.gd")
const Replay = preload("res://scripts/battle_replay.gd")
const Data = preload("res://scripts/game_data.gd")

class FallenCasterBattle:
	extends "res://scripts/battle.gd"

	# Explicit future-effect fixture; current cards cannot kill their own caster.
	func _resolve(ability: Dictionary, caster: Dictionary, target_id: String) -> void:
		super._resolve(ability, caster, target_id)
		if caster.get("id", "") == "m0" and ability["effects"].any(func(effect): return effect.get("kind", "") == "damage"):
			caster["hp"] = 0

func run(t) -> void:
	t.group("authoritative raid recap: real cards/charge spends, partial legacy coverage, pre-recovery persistence")
	test_card_counts(t)
	test_charge_counts(t)
	test_snapshots_and_legacy(t)
	test_capture_and_persistence(t)
	test_legacy_active_victory(t)

func fixture(t, form: String = "green_ogre", traits: Array = [], fallen_caster: bool = false):
	var people: Array = t.roster()
	people[0]["form"] = form
	people[0]["hp"] = Data.FORMS[form]["max_hp"]
	people[0]["max_hp"] = Data.FORMS[form]["max_hp"]
	var battle = FallenCasterBattle.new() if fallen_caster else Combat.new()
	var random := RandomNumberGenerator.new()
	random.seed = 167923
	battle.setup(people, [t.enemy("e0"), t.enemy("e1"), t.enemy("e2")], random, traits)
	battle.energy = 20
	return battle

func play(t, battle, ability: String, target: String, owner: String = "m0") -> void:
	battle.hand = [t.card(ability, owner)]
	t.check(battle.play_card(0, target), "Recap fixture resolves a real accepted card: " + ability)

func test_card_counts(t) -> void:
	var battle = fixture(t)
	t.check(battle.recap_state == {"complete": true, "cards_played": 0, "bulwark": {}}, "Fresh setup starts complete per-raid counters with no fabricated payoff rows")
	battle.hand = [t.card("guard")]
	var before: Dictionary = battle.to_dict()
	t.check(not battle.play_card(-1, "m1") and not battle.play_card(0, "e0") and t.same_saved_value(before, battle.to_dict()), "Invalid index or faction target cannot increment recap or mutate combat/RNG")
	battle.energy = 0
	before = battle.to_dict()
	t.check(not battle.play_card(0, "m1") and t.same_saved_value(before, battle.to_dict()), "Unaffordable card changes no recap counter or charge")
	battle.energy = 20
	play(t, battle, "guard", "m1")
	play(t, battle, "rally", "m1", "")
	t.check(battle.recap_state["cards_played"] == 2 and battle.recap_state["bulwark"].is_empty(), "Accepted owned and shared cards each count once; protection alone spends no charge")
	var stats: Dictionary = battle.recap_state.duplicate(true)
	battle.end_turn()
	t.check(battle.recap_state == stats, "Discarding the remaining hand and resolving invader actions do not count player cards or charge spends")
	t.check(Recap.capture(battle, 0).is_empty(), "An active battle cannot produce a victory recap")

func test_charge_counts(t) -> void:
	for form in ["green_ogre", "ancient_ogre"]:
		var bonus: int = 14 if form == "ancient_ogre" else 10
		for defense in ["ordinary", "armor", "block", "evade", "overkill", "area"]:
			var battle = fixture(t, form)
			play(t, battle, "guard", "m1")
			if defense == "armor": battle.enemies[0]["armor"] = 100
			if defense == "block": battle.enemies[0]["block"] = 100
			if defense == "evade": battle._status(battle.enemies[0], "evasion", 1)
			if defense == "overkill": battle.enemies[0]["hp"] = 1
			var card: Dictionary = t.card("ember_burst" if defense == "area" else "strike")
			var before: Dictionary = battle.to_dict()
			for repeat in range(3):
				t.check(Forms.prepare(battle, card, "e0")["bulwark_bonus"] == bonus, "Prepared charged amount records advertised +%d before resolution" % bonus)
				battle.preview(card, "e0")
				Recap.capture(battle, 0)
			t.check(t.same_saved_value(before, battle.to_dict()), "Charge preparation, forecasting and recap queries never increment counters or consume RNG")
			play(t, battle, card["ability"], "e0")
			var row: Dictionary = battle.recap_state["bulwark"]["m0"]
			t.check(row == {"name": "Rook", "activations": 1, "bonus_total": bonus} and battle.recap_state["cards_played"] == 2, "One accepted charged card records one advertised spend independently of " + defense)
			play(t, battle, "strike", "e1")
			t.check(row["activations"] == 1 and row["bonus_total"] == bonus, "A subsequent uncharged attack cannot duplicate the prior payoff")
			if defense == "area": t.check(row["bonus_total"] == bonus, "Boosting three area recipients still records one charge size, not multiplied damage")
		var dead_owner = fixture(t, form, [], true)
		play(t, dead_owner, "guard", "m1")
		play(t, dead_owner, "strike", "e0")
		t.check(dead_owner.monsters[0]["hp"] == 0 and dead_owner.recap_state["bulwark"]["m0"]["bonus_total"] == bonus and dead_owner.recap_state["cards_played"] == 2, "An accepted boosted hit remains counted if an explicit future effect kills its caster after impact")

func test_snapshots_and_legacy(t) -> void:
	var battle = fixture(t, "green_ogre", ["war_drums"])
	play(t, battle, "guard", "m1")
	play(t, battle, "strike", "e0")
	var snapshot: Dictionary = battle.to_dict()
	var copy = Combat.new()
	copy.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(t.same_saved_value(snapshot, copy.to_dict()) and copy.recap_state["complete"], "Modern snapshots restore exact recap counters together with combat, charges, hand and RNG")
	copy.recap_state["bulwark"]["m0"]["activations"] += 100
	t.check(battle.recap_state["bulwark"]["m0"]["activations"] == 1 and snapshot["recap_state"]["bulwark"]["m0"]["activations"] == 1, "Restored and serialized nested recap dictionaries do not alias the authoritative battle")
	var before_replay: Dictionary = battle.to_dict()
	var replay = Replay.make(battle)
	t.check(t.same_saved_value(before_replay, battle.to_dict()) and replay.recap_state == battle.recap_state, "Cosmetic end-turn replay cannot add player cards or mutate live charge-spend history")
	var old: Dictionary = snapshot.duplicate(true)
	old.erase("recap_state")
	var legacy = Combat.new()
	legacy.restore(old, old["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	t.check(legacy.recap_state == {"complete": false, "cards_played": 0, "bulwark": {}}, "Missing old stats produce explicitly partial zero observed counters; logs are never reconstructed")
	var modern = Combat.new()
	modern.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	play(t, legacy, "strike", "e1")
	play(t, modern, "strike", "e1")
	var legacy_gameplay: Dictionary = legacy.to_dict()
	var modern_gameplay: Dictionary = modern.to_dict()
	legacy_gameplay.erase("recap_state")
	modern_gameplay.erase("recap_state")
	t.check(t.same_saved_value(legacy_gameplay, modern_gameplay), "Adding observed counters to old combat changes no damage, intents, shuffle state or gameplay RNG")
	t.check(not legacy.recap_state["complete"] and legacy.recap_state["cards_played"] == 1, "Later valid cards add only observed history and never relabel a partial old raid as complete")
	legacy.setup(t.roster(), [t.enemy()], RandomNumberGenerator.new())
	t.check(legacy.recap_state == {"complete": true, "cards_played": 0, "bulwark": {}}, "A fresh next raid resets prior and partial histories to complete zero counters")

func prepared_game(t, tag: String, raid_index: int = 0):
	# Explicit unit fixture; campaign reachability tests use earned builds/real HP.
	var game = t.state_at(tag)
	game.new_run(58721)
	game.run["raid"] = raid_index
	game.run.erase("party")
	var people: Array = game.run["monsters"]
	people[0]["form"] = "green_ogre"
	people[0]["max_hp"] = 28
	people[0]["hp"] = 12
	people[1]["hp"] = 7
	people[2]["hp"] = 0
	game.run["traits"] = ["war_drums", "venom_nest"]
	game.start_raid()
	for enemy in game.battle.enemies: enemy["hp"] = 1
	return game

func state_play(t, game, ability: String, target: String, owner: String = "m1") -> void:
	game.battle.hand = [t.card(ability, owner)]
	t.check(game.play_card(0, target), "Recap persistence fixture uses the normal State card API: " + ability)

func win_prepared(t, game) -> Dictionary:
	state_play(t, game, "guard", "m2")
	state_play(t, game, "rally", "m1", "")
	state_play(t, game, "ember_burst", game.battle.enemies[0]["id"])
	t.check(game.run["phase"] in ["trait", "feeding"] and game.run.has("raid_recap"), "Winning card commits its actual recap before early rewards or feeding")
	return game.run["raid_recap"].duplicate(true)

func resolve_feeding(t, game) -> void:
	if game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding": t.choose_campaign_trait(game)
	for index in range(game.run["rewards"].size()): t.check(game.skip_body(index), "Recap feeding fixture resolves every actual corpse through the normal skip API")
	t.check(game.finish_feeding(), "Recap fixture finishes feeding and applies ordinary victory recovery")

func test_capture_and_persistence(t) -> void:
	for raid_index in [0, 5]:
		var game = prepared_game(t, "recap_persistence_%d" % raid_index, raid_index)
		var recap: Dictionary = win_prepared(t, game)
		t.check(recap["raid"] == raid_index + 1 and recap["rounds"] == 1 and recap["complete"] and recap["cards_played"] == 3, "Recap counts the winning card, shared card and current round with one-based raid identity")
		t.check(recap["survivors"] == 2 and recap["party_size"] == 3 and recap["hp_remaining"] == 19 and recap["max_hp"] == 68, "Victory recap retains the actual pre-recovery full-roster HP and surviving monster count")
		t.check(recap["bulwark"] == [{"owner": "m1", "name": "Grub", "activations": 1, "bonus_total": 10}] and recap["traits"] == [{"id": "war_drums", "count": 1}], "Recap includes real charge/trait activations once and omits inactive payoff rows")
		var saved_rng: int = game.rng.state
		var mutable: Dictionary = Recap.capture(game.battle, raid_index)
		mutable["bulwark"][0]["bonus_total"] = 900
		mutable["traits"][0]["count"] = 900
		t.check(game.run["raid_recap"] == recap and game.battle.recap_state["bulwark"]["m1"]["bonus_total"] == 10 and game.rng.state == saved_rng, "Captured presentation data cannot mutate saved/live payoffs or gameplay RNG")
		var feeding_loaded = t.state_at("recap_persistence_%d" % raid_index)
		t.check(feeding_loaded.load_game() and feeding_loaded.run["raid_recap"] == recap and feeding_loaded.rng.state == saved_rng, "Reloading pending first reward or feeding preserves the exact victory recap and RNG")
		if raid_index == 0:
			t.check(game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding" and game.run["raid_recap"] == recap, "Early first trait reward preserves its untouched pre-recovery victory recap")
		resolve_feeding(t, game)
		t.check(game.run["monsters"].map(func(monster): return monster["hp"]).reduce(func(total, value): return total + value, 0) == 36 and game.run["raid_recap"] == recap, "Recovery changes live HP while preserving the immutable pre-recovery receipt")
		if raid_index == 0:
			t.check(game.run["phase"] == "result" and game.run["raid_recap"] == recap, "Choosing the early trait and completing feeding preserves the recap through result")
			game.continue_after_result()
			t.check(game.run["phase"] == "prep" and game.run["raid_recap"] == recap, "Preparing the next raid retains the previous recap until a valid start")
			game.start_raid()
			t.check(not game.run.has("raid_recap") and game.battle.recap_state == Recap.fresh_state(), "Starting the next actual raid clears the prior receipt and resets complete counters")
			game.run["raid_recap"] = recap.duplicate(true) # Stale legacy metadata fixture.
			for monster in game.run["monsters"]: monster["hp"] = 0
			game.end_turn()
			t.check(game.run["phase"] == "defeat" and not game.run.has("raid_recap") and Recap.capture(game.battle, 1).is_empty(), "Defeat cannot display or capture a stale victory recap")
		else:
			t.check(game.run["phase"] == "victory" and game.run["raid_recap"] == recap, "Final campaign victory retains its final raid recap")
			game.start_raid()
			t.check(game.run["raid_recap"] == recap, "Rejected start from terminal victory cannot erase its receipt")
			var victory_loaded = t.state_at("recap_persistence_5")
			t.check(victory_loaded.load_game() and victory_loaded.run["phase"] == "victory" and victory_loaded.run["raid_recap"] == recap, "Completed campaign save/load preserves the last real raid recap")
		game.new_run(58722)
		t.check(not game.run.has("raid_recap"), "Starting a fresh run cannot retain a previous victory recap")

func test_legacy_active_victory(t) -> void:
	var game = prepared_game(t, "recap_legacy_active")
	state_play(t, game, "guard", "m2")
	var snapshot: Dictionary = game._read_json(game._prefix + "run.json")
	snapshot["battle"].erase("recap_state")
	var saved_rng: int = game.rng.state
	t.check(game._write_json(game._prefix + "run.json", snapshot), "Explicit old active save omits only the new recap counters")
	var loaded = t.state_at("recap_legacy_active")
	t.check(loaded.load_game() and loaded.battle.recap_state == Recap.fresh_state(false) and loaded.rng.state == saved_rng, "Old active combat receives partial empty counters without reconstructing logged protection or changing RNG")
	state_play(t, loaded, "ember_burst", loaded.battle.enemies[0]["id"])
	var recap: Dictionary = loaded.run["raid_recap"].duplicate(true)
	t.check(not recap["complete"] and recap["cards_played"] == 1 and recap["bulwark"][0]["activations"] == 1 and recap["bulwark"][0]["bonus_total"] == 10, "A carried old charge and winning card count as observed payoffs while legacy coverage stays partial")
	t.check(recap["traits"] == [{"id": "war_drums", "count": 1}], "Existing authoritative trait totals remain known real history when recap coverage is partial")
	var feeding_loaded = t.state_at("recap_legacy_active")
	t.check(feeding_loaded.load_game() and feeding_loaded.run["raid_recap"] == recap, "Partial victory recap persists unchanged through its feeding save/reload")
