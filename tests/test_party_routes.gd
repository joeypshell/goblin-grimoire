extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const CountingState = preload("res://tests/flow_state_fixture.gd")
const ROUTE_KEYS = ["party_options", "party_options_raid", "party_choice", "party_locked"]

# Fixed v0.9 tuning fixtures (seed 640297): deliberate HP/kit changes are explicit.
# These still guard actor identity, class armor, champion skills and RNG stability.
const ORIGINAL_PARTIES = [
	[["Bran", "warrior", 15, 1, ["heavy_blow", "strike"]], ["Caldus", "mage", 11, 0, ["firebolt", "arcane_bolt"]], ["Silas", "rogue", 12, 0, ["smoke_step", "poisoned_blade"]]],
	[["Vera", "defender", 19, 2, ["shield_wall", "heavy_blow", "shield_bash", "shatter_guard"]], ["Vale", "controller", 13, 0, ["snare"]], ["Silas", "rogue", 13, 0, ["poisoned_blade"]]],
	[["Captain Torren", "warrior", 18, 1, ["heavy_blow", "strike", "shatter_guard", "banner_volley"]], ["Caldus", "mage", 14, 0, ["firebolt", "arcane_bolt", "ember_burst"]], ["Aster", "priest", 16, 0, ["regrowth", "mend", "arcane_bolt"]]],
	[["Iris", "mage", 16, 0, ["firebolt", "arcane_bolt", "ember_burst"]], ["Oswin", "defender", 21, 2, ["shield_wall", "heavy_blow", "shatter_guard"]], ["Orrin", "controller", 16, 0, ["snare", "smoke_step"]]],
	[["Kestrel", "rogue", 19, 0, ["poisoned_blade", "smoke_step", "quick_jab"]], ["Brother Sol", "priest", 19, 0, ["regrowth", "mend", "arcane_bolt"]], ["Edric", "warrior", 20, 1, ["heavy_blow", "strike"]]],
	[["Marshal Vera", "defender", 26, 2, ["shield_wall", "heavy_blow", "shatter_guard", "breach_order"]], ["Caldus", "mage", 19, 0, ["firebolt", "arcane_bolt"]], ["Orrin", "controller", 20, 0, ["snare", "arcane_bolt"]]]
]

func run(t) -> void:
	t.group("deterministic raid party choices, actual corpse pools, terminal destruction and legacy saves")
	test_original_parties(t)
	test_candidates(t)
	test_future_choice_after_reload(t)
	test_switches_and_saves(t)
	test_actual_combat_and_corpses(t)
	test_locked_destruction(t)
	test_advancement(t)
	test_legacy(t)
	test_alternate_campaign(t)

func game_at(t, tag: String):
	return CountingState.new(t.profile_root + "party_routes_" + tag + "/")

func prepare(game, raid: int, seed_value: int) -> void:
	# Explicit phase fixture. Normal advancement is exercised separately below.
	game.new_run(seed_value)
	game.run["raid"] = raid
	game.run["phase"] = "prep"
	game.run["trait_milestones"] = [1, 3]
	game.run.erase("party")
	for key in ROUTE_KEYS: game.run.erase(key)
	game.battle = null

func brief(party: Array) -> Array:
	var result: Array = []
	for actor in party:
		result.append([actor["name"], actor["class_name"], actor["max_hp"], Data.armor(actor), actor["abilities"]])
	return result

func same_actor_pool(left: Dictionary, right: Dictionary) -> bool:
	for key in ["id", "name", "class_name", "form", "abilities"]:
		if left[key] != right[key]: return false
	return Data.armor(left) == Data.armor(right)

func unchanged(t, game, before: Dictionary, random_before: int, message: String) -> void:
	t.check(t.same_saved_value(game.run, before) and game.rng.state == random_before and game.save_calls == 0, message)

func victory(game) -> void:
	# Phase fixture resolves production enemy data into production corpse data.
	for actor in game.battle.enemies: actor["hp"] = 0
	game.end_turn()

func skip_and_advance(game) -> bool:
	if game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding": accept_traits(game)
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	return game.finish_feeding()

func accept_traits(game) -> void:
	while game.run["phase"] == "trait":
		var choices: Array = game.trait_choices()
		if choices.is_empty(): return
		game.choose_trait(choices[0])

func test_original_parties(t) -> void:
	for raid in range(6):
		var random := RandomNumberGenerator.new()
		random.seed = 640297
		var party := Data.generate_party(raid, random)
		t.check(brief(party) == ORIGINAL_PARTIES[raid] and random.state == -1082805750736773630, "Raid %d generation matches intentional v0.9 HP/kit fixtures with stable identity, armor and RNG" % raid)
		for slot in range(party.size()):
			t.check(party[slot]["id"] == "raid_%d_foe_%d" % [raid, slot] and party[slot]["hp"] == party[slot]["max_hp"], "Released party identifiers and initial health remain unchanged")
	for raid in [0, 2, 5]:
		var game = game_at(t, "fixed_%d" % raid)
		prepare(game, raid, 640297)
		game.party_preview()
		var before: Dictionary = game.run.duplicate(true)
		var random_before: int = game.rng.state
		game.save_calls = 0
		t.check(game.party_choices().is_empty() and not game.select_party("alternate"), "Intro and champion raid %d cannot be replaced by a route choice" % raid)
		unchanged(t, game, before, random_before, "Fixed encounter selection rejection preserves the run, RNG and save count")
		if raid == 2:
			t.check(game.run["party"][0].get("champion") == "cinder_banner" and game.run["party"][0]["abilities"].has("banner_volley"), "Fixed F champion keeps its announced volley mechanic")

func test_candidates(t) -> void:
	for raid in [1, 3, 4]:
		for seed_value in [1, 81248, 640297, 9223372036854775807]:
			var game = game_at(t, "candidate_%d_%d" % [raid, seed_value])
			prepare(game, raid, seed_value)
			var reference := RandomNumberGenerator.new()
			reference.seed = game.rng.seed
			reference.state = game.rng.state
			var baseline := Data.generate_party(raid, reference)
			game.party_preview()
			var choices: Array = game.party_choices()
			t.check(choices.size() == 2 and choices.map(func(option): return option["id"]) == ["standard", "alternate"], "Each eligible raid offers exactly two named party choices")
			if choices.size() != 2: continue
			t.check(choices[0]["party"] == baseline and game.run["party"] == baseline and game.rng.state == reference.state, "Generating alternatives keeps the original selected party and consumes only the original party's RNG")
			t.check(choices[0]["party"].map(func(actor): return actor["class_name"]) != choices[1]["party"].map(func(actor): return actor["class_name"]), "The alternate changes actual enemy classes rather than only the encounter label")
			for option in choices:
				t.check(not option["name"].is_empty() and not option["description"].is_empty() and option["party"].size() == 3, "Each offered party has a threat description and exactly three real invaders")
				for slot in range(option["party"].size()):
					var actor: Dictionary = option["party"][slot]
					t.check(Data.CLASSES.has(actor["class_name"]) and actor["form"] == actor["class_name"] and actor["id"] == "raid_%d_foe_%d" % [raid, slot], "Alternate previews contain actual raid actors and reveal no undiscovered monster forms")
					t.check(Data.armor(actor) == Data.CLASSES[actor["class_name"]].get("armor", 0) and actor["hp"] == actor["max_hp"] and actor["hp"] > 0, "Every preview retains its class armor and full initial HP")
					for ability in actor["abilities"]: t.check(Data.ABILITIES.has(ability), "Every offered enemy skill is a real combat and inheritance ability")
			var second = game_at(t, "candidate_copy_%d_%d" % [raid, seed_value])
			prepare(second, raid, seed_value)
			second.party_preview()
			t.check(second.party_choices() == choices and second.rng.state == game.rng.state, "Independent runs reproduce both cached parties from the same seed")
			var before: Dictionary = game.run.duplicate(true)
			var profile_before: Dictionary = game.profile.duplicate(true)
			var random_before: int = game.rng.state
			game.save_calls = 0
			for query in range(12):
				game.party_choices()
				game.party_preview()
				game.selected_party_name()
			unchanged(t, game, before, random_before, "Repeated party queries do not regenerate parties, advance RNG, recover HP or save")
			choices[1]["party"][0]["hp"] = 1
			choices[1]["party"][0]["abilities"].clear()
			choices[0]["name"] = "Changed local copy"
			unchanged(t, game, before, random_before, "Mutating returned candidate previews cannot alter cached enemies or names")
			t.check(game.profile == profile_before and game.discoveries().is_empty(), "Inspecting offered party paths discovers no hidden forms")

func test_future_choice_after_reload(t) -> void:
	for seed_value in [638217, 9223372036854775806]:
		var tag := "future_choices_%d" % seed_value
		var original = game_at(t, tag)
		original.new_run(seed_value)
		original.start_raid()
		victory(original)
		t.check(skip_and_advance(original), "A resolved intro reaches the safe boundary before future parties are generated")
		accept_traits(original)
		var loaded = game_at(t, tag)
		t.check(loaded.load_game() and loaded.run["seed"] is int and loaded.run["seed"] == seed_value and loaded.rng.state == original.rng.state, "Reload before future route generation preserves the integer seed and exact gameplay RNG")
		original.continue_after_result()
		loaded.continue_after_result()
		t.check(original.party_choices().size() == 2 and original.party_choices() == loaded.party_choices() and original.rng.state == loaded.rng.state, "Future standard and alternate parties match uninterrupted play after save/reload, including a full-width seed")

func test_switches_and_saves(t) -> void:
	var game = game_at(t, "switch_save")
	prepare(game, 3, 638217)
	game.party_preview()
	var choices: Array = game.party_choices()
	var random_before: int = game.rng.state
	var people_before: Array = game.run["monsters"].duplicate(true)
	var profile_before: Dictionary = game.profile.duplicate(true)
	for id in ["alternate", "standard", "alternate"]:
		game.save_calls = 0
		var selected: Dictionary = choices[1] if id == "alternate" else choices[0]
		t.check(game.select_party(id) and game.run["party"] == selected["party"] and game.run["party_choice"] == id and game.selected_party_name() == selected["name"], "Choosing a path selects its exact cached actors and visible encounter name")
		t.check(game.rng.state == random_before and game.run["monsters"] == people_before and game.profile == profile_before and game.save_calls == 1, "Changing party saves once without RNG, recovery, progression or discoveries")
		t.check(game.party_choices() == choices, "Switching paths cannot reroll either offered party")
	var before: Dictionary = game.run.duplicate(true)
	game.save_calls = 0
	t.check(game.select_party("alternate"), "Reselecting the current offered party is a successful no-op")
	unchanged(t, game, before, random_before, "Reselecting the current path adds no save, report event or RNG draw")
	t.check(not game.select_party("made_up") and not game.select_party(""), "Unknown and empty route ids are rejected")
	unchanged(t, game, before, random_before, "Invalid path selection cannot mutate or persist the run")
	var loaded = game_at(t, "switch_save")
	t.check(loaded.load_game() and t.same_saved_value(loaded.run, before) and loaded.rng.state == random_before, "Continue restores the selected party and full cached alternatives with exact RNG")
	t.check(loaded.party_choices() == choices and loaded.selected_party_name() == choices[1]["name"], "Saved preparation retains its two exact choices and selected title")
	loaded.select_party("standard")
	t.check(game.run["party"] == choices[1]["party"] and game.party_choices() == choices, "A restored run's route changes do not alias the original state")
	for phase in ["combat", "feeding", "trait", "result", "victory", "defeat"]:
		game.run["phase"] = phase
		before = game.run.duplicate(true)
		game.save_calls = 0
		t.check(game.party_choices().is_empty() and not game.select_party("standard"), "Route selection is unavailable during phase " + phase)
		unchanged(t, game, before, random_before, "Wrong-phase route requests preserve all state and persistence")
	game.run["phase"] = "prep"
	game.run["party_options_raid"] = 1
	before = game.run.duplicate(true)
	game.save_calls = 0
	t.check(game.party_choices().is_empty() and not game.select_party("standard"), "An outdated raid's cached choices cannot be applied to a later raid")
	unchanged(t, game, before, random_before, "Stale-cache rejection consumes no RNG, save or progression")

func test_actual_combat_and_corpses(t) -> void:
	t.check(Data.INHERITANCE_WEIGHTS == {"common": 4, "uncommon": 2, "rare": 1}, "Party routing preserves the established 4:2:1 random inheritance weights")
	for raid in [1, 3, 4]:
		for choice in ["standard", "alternate"]:
			var game = game_at(t, "corpse_%d_%s" % [raid, choice])
			prepare(game, raid, 914725)
			game.party_preview()
			t.check(game.select_party(choice), "A valid preparation selects the path before combat")
			var chosen: Array = game.run["party"].duplicate(true)
			game.start_raid()
			t.check(game.run["phase"] == "combat" and game.run.get("party_locked", false) and game.party_choices().is_empty(), "First attempt locks its selected party and hides route controls")
			t.check(game.battle.enemies.size() == chosen.size(), "Actual raid uses the selected three-invader party")
			for slot in range(chosen.size()):
				t.check(same_actor_pool(game.battle.enemies[slot], chosen[slot]) and game.battle.enemies[slot]["hp"] == chosen[slot]["hp"], "Combat enemy identity, armor, HP and abilities exactly match the selected preview")
			victory(game)
			t.check(game.run["phase"] == "feeding" and game.run["rewards"].size() == chosen.size() and game.run["party"] == chosen, "Winning produces one corpse per selected invader while keeping the selected party history intact")
			var monster: Dictionary = game.run["monsters"][0]
			for slot in range(chosen.size()):
				var body: Dictionary = game.run["rewards"][slot]
				t.check(same_actor_pool(body, chosen[slot]), "The corpse's armor and transferable skills come from the selected actual enemy")
				var options: Array = game.inheritance_outcomes(slot, monster["id"])
				var expected: Array = []
				for ability in chosen[slot]["abilities"]:
					if not monster["learned"].has(ability) and not expected.has(ability): expected.append(ability)
				t.check(options.map(func(option): return option["ability"]) == expected, "Selected-route inheritance uses only unknown skills on its actual corpse")
				var chance := 0.0
				for option in options:
					chance += float(option["chance"])
					t.check(option["weight"] == Data.INHERITANCE_WEIGHTS[option["rarity"]], "Selected-route corpse probabilities keep the original rarity weights")
				t.check(options.is_empty() or is_equal_approx(chance, 1.0), "Random inheritance probabilities remain normalized for each selected corpse")
			var expected_first: Array = game.inheritance_outcomes(0, monster["id"]).map(func(option): return option["ability"])
			if not expected_first.is_empty():
				t.check(game.claim_body(0, monster["id"]) and expected_first.has(game.run["rewards"][0]["taken"]), "Devouring a selected-path body still rolls one of its weighted actual skills")

func test_locked_destruction(t) -> void:
	var game = game_at(t, "route_destruction")
	prepare(game, 1, 39852)
	game.party_preview()
	game.select_party("alternate")
	var chosen: Array = game.run["party"].duplicate(true)
	var chosen_name: String = game.selected_party_name()
	game.start_raid()
	var saved_combat: Dictionary = game.battle.to_dict()
	var loaded = game_at(t, "route_destruction")
	t.check(loaded.load_game() and t.same_saved_value(saved_combat, loaded.battle.to_dict()) and loaded.run["party"] == chosen and loaded.selected_party_name() == chosen_name, "Continue in active alternate combat preserves enemies, cards, locked intentions and party name")
	for monster in loaded.run["monsters"]: monster["hp"] = 0
	loaded.end_turn()
	t.check(loaded.run["phase"] == "defeat" and not loaded.run.has("core") and loaded.run["raid"] == 1 and loaded.run["monsters"].all(func(monster): return monster["hp"] == 0), "Losing an alternate route immediately destroys the dungeon, without Core HP or monster revival")
	t.check(loaded.run["party"] == chosen and loaded.selected_party_name() == chosen_name and loaded.run["rewards"].is_empty(), "Destruction preserves selected-party history without granting corpses or contaminating saved enemy HP")
	var result = game_at(t, "route_destruction")
	t.check(result.load_game() and result.run["phase"] == "defeat" and result.run["party"] == chosen and result.run["monsters"].all(func(monster): return monster["hp"] == 0), "Destroyed-route save reloads the same terminal result and knocked-out roster")
	var before: Dictionary = result.run.duplicate(true)
	var random_before: int = result.rng.state
	result.save_calls = 0
	t.check(result.party_choices().is_empty() and not result.select_party("standard") and not result.select_party("alternate"), "Neither route can be selected after dungeon destruction")
	result.continue_after_result()
	result.start_raid()
	result.end_turn()
	t.check(not result.play_card(0, "e0") and not result.finish_feeding(), "A destroyed dungeon rejects combat and feeding requests")
	unchanged(t, result, before, random_before, "Terminal route actions cannot retry, heal, change foes, reroll or save")
	var again = game_at(t, "route_destruction")
	t.check(again.load_game() and again.run["phase"] == "defeat" and again.party_choices().is_empty() and again.run["party"] == chosen and again.rng.state == random_before, "Repeated loading cannot reopen route selection or restart destroyed combat")

func test_advancement(t) -> void:
	var game = game_at(t, "advance")
	prepare(game, 1, 657127)
	game.party_preview()
	game.select_party("alternate")
	game.start_raid()
	victory(game)
	t.check(skip_and_advance(game) and game.run["raid"] == 2, "Resolving bodies advances the chosen raid normally")
	t.check(not game.run.has("party") and ROUTE_KEYS.all(func(key): return not game.run.has(key)), "Successful advancement clears the old party, choices, selected path and combat lock")
	game.continue_after_result()
	t.check(game.party_choices().is_empty() and game.selected_party_name() == Data.ENCOUNTERS[2]["name"], "The next F champion remains fixed after an alternate route victory")
	game.start_raid()
	victory(game)
	t.check(skip_and_advance(game), "Champion corpse resolution reaches the next rank's reward normally")
	accept_traits(game)
	game.continue_after_result()
	t.check(game.run["raid"] == 3 and game.party_choices().size() == 2 and game.run["party_choice"] == "standard" and not game.run["party_locked"], "A future eligible raid gets fresh cached choices with the standard path selected and unlocked")
	game.new_run(1183)
	t.check(game.run["raid"] == 0 and game.party_choices().is_empty() and ROUTE_KEYS.all(func(key): return not game.run.has(key)), "New Run cannot inherit a previous run's party options or combat lock")

func test_legacy(t) -> void:
	for active in [false, true]:
		var tag: String = "legacy_combat" if active else "legacy_prep"
		var old = game_at(t, tag)
		prepare(old, 1, 712418)
		old.party_preview()
		old.select_party("alternate")
		if active: old.start_raid()
		var original_party: Array = old.run["party"].duplicate(true)
		var original_combat: Dictionary = old.battle.to_dict() if active else {}
		var original_random: int = old.rng.state
		var snapshot: Dictionary = old.run.duplicate(true)
		for key in ROUTE_KEYS: snapshot.erase(key)
		old._write_json(old._prefix + "run.json", snapshot)
		var loaded = game_at(t, tag)
		t.check(loaded.load_game() and loaded.run["party"] == original_party and loaded.rng.state == original_random, "Legacy save with an existing party preserves the exact invaders and gameplay RNG")
		var before: Dictionary = loaded.run.duplicate(true)
		loaded.save_calls = 0
		t.check(loaded.party_choices().is_empty() and not loaded.select_party("standard") and not loaded.select_party("alternate"), "A legacy existing party cannot receive retroactive alternate offers")
		unchanged(t, loaded, before, original_random, "Legacy path queries leave the restored save and random stream untouched")
		if active:
			t.check(loaded.run["phase"] == "combat" and t.same_saved_value(original_combat, loaded.battle.to_dict()), "Legacy active combat retains its original hand, piles, energy, HP and announced actions")
		else:
			loaded.start_raid()
		victory(loaded)
		t.check(skip_and_advance(loaded), "A preserved legacy party remains playable and advances normally")
		loaded.continue_after_result()
		loaded.start_raid()
		victory(loaded)
		skip_and_advance(loaded)
		accept_traits(loaded)
		loaded.continue_after_result()
		t.check(loaded.run["raid"] == 3 and loaded.party_choices().size() == 2 and not loaded.run["party_locked"], "Legacy runs receive choices at a future newly generated eligible raid")

func test_alternate_campaign(t) -> void:
	# A bounded policy establishes integrated reachability, not a human win rate.
	# No HP, skills, inheritance rolls or battle outcomes are edited in this test.
	var previous_turns: int = t.campaign_turns
	var previous_plays: int = t.campaign_plays
	var completed := false
	for seed_value in [730204, 101]:
		var game = t.state_at("party_routes_campaign_%d" % seed_value)
		game.new_run(seed_value)
		var turns_before: int = t.campaign_turns
		var plays_before: int = t.campaign_plays
		var defeats := 0
		var attempts := 0
		var alternate_raids := {}
		while game.run["phase"] == "prep" and attempts < 6:
			attempts += 1
			if not game.party_choices().is_empty():
				t.check(game.select_party("alternate"), "Real-card campaign selects the alternate through its offered preparation choice")
				alternate_raids[int(game.run["raid"])] = true
			t.configure_loadout(game)
			var preview: Array = game.party_preview().duplicate(true)
			game.start_raid()
			t.check(brief(game.battle.enemies) == brief(preview), "Real-card alternate campaign fights its actual selected party")
			if t.win_raid(game, 120):
				t.feed_campaign(game, false)
				t.check(game.finish_feeding(), "Real-card alternate victory consumes actual corpses and advances with normal recovery")
				t.choose_campaign_trait(game)
			else:
				t.check(game.run["phase"] == "defeat" and game.run["monsters"].all(func(monster): return monster["hp"] == 0) and game.run["rewards"].is_empty(), "A lost alternate encounter immediately ends its campaign without recovery, corpses or retries")
				if game.run["phase"] == "combat": break
				defeats += 1
			if game.run["phase"] == "result": game.continue_after_result()
		t.check(game.run["phase"] in ["victory", "defeat"], "Alternate campaign terminates within bounded normal raid attempts")
		t.check(defeats <= 1 and not game.run.has("core"), "Alternate campaign has at most one terminal loss and no Core HP budget")
		print("ALTERNATE CAMPAIGN: ", JSON.stringify({"seed": seed_value, "phase": game.run["phase"], "raids": game.run["raid"], "alternate_raids": alternate_raids.keys(), "attempts": attempts, "turns": t.campaign_turns - turns_before, "plays": t.campaign_plays - plays_before, "defeats": defeats, "traits": game.run["traits"], "forms": game.run["monsters"].map(func(monster): return monster["form"])}))
		if game.run["phase"] == "victory" and alternate_raids.size() == 3:
			completed = true
			break
	t.check(completed, "At least one actual six-raid campaign choosing every offered alternate wins with production cards and random inheritance")
	t.campaign_turns = previous_turns
	t.campaign_plays = previous_plays
