extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const CountingState = preload("res://tests/flow_state_fixture.gd")

func run(t) -> void:
	t.group("weighted random inheritance, corpse filtering, rejected claims and persisted results")
	test_actual_corpses(t)
	test_rejected_claims(t)
	test_weights(t)

func actual_feeding(t, tag: String):
	var game = CountingState.new(t.profile_root + tag + "/")
	game.new_run(81248)
	game.start_raid()
	for actor in game.battle.enemies: actor["hp"] = 0
	game.end_turn()
	t.choose_campaign_trait(game)
	game.save_calls = 0
	return game

func unchanged(t, game, before: Dictionary, random_before: int, saves: int, message: String) -> void:
	t.check(t.same_saved_value(game.run, before) and game.rng.state == random_before and game.save_calls == saves, message)

func test_actual_corpses(t) -> void:
	var game = actual_feeding(t, "random_actual_corpses")
	var monster: Dictionary = game.run["monsters"][0]
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	var expected: Array = []
	for ability in game.run["rewards"][0]["abilities"]:
		if Data.ABILITIES.has(ability) and not monster["learned"].has(ability) and not expected.has(ability): expected.append(ability)
	var outcomes: Array = game.inheritance_outcomes(0, monster["id"])
	t.check(outcomes.map(func(value): return value["ability"]) == expected, "Inheritance candidates are only actual corpse abilities unknown to this recipient")
	var chance := 0.0
	for option in outcomes:
		chance += float(option["chance"])
		t.check(option["weight"] == Data.INHERITANCE_WEIGHTS[option["rarity"]] and float(option["chance"]) > 0, "Each actual candidate exposes its rarity weight and nonzero probability")
	t.check(is_equal_approx(chance, 1.0), "Actual corpse outcome probabilities sum to one")
	for repeat in range(20): game.inheritance_outcomes(0, monster["id"])
	unchanged(t, game, before, random_before, 0, "Repeated outcome previews do not roll, save or mutate the run")
	var other_before: Array = game.run["monsters"].slice(1).duplicate(true)
	var hp: int = monster["hp"]
	var selected: Array = monster["selected"].duplicate()
	t.check(game.claim_body(0, monster["id"]), "Real defeated corpse is consumed without a caller-selected ability")
	var body: Dictionary = game.run["rewards"][0]
	var taken: String = body["taken"]
	t.check(expected.has(taken) and body["recipient"] == monster["id"] and body["claimed"], "One actual weighted result and recipient are recorded on the corpse")
	t.check(monster["learned"].count(taken) == 1 and monster["consumed"].count(taken) == 1 and monster["feeds"] == 1, "Random inheritance grants exactly one new skill, unique consumed entry and feeding")
	t.check(monster["hp"] == hp and monster["selected"] == selected and t.same_saved_value(other_before, game.run["monsters"].slice(1)), "Inheritance does not heal, replace loadouts or affect other recipients")
	t.check(game.save_calls == 1 and game.inheritance_outcomes(0, monster["id"]).is_empty(), "Successful claim saves once and removes that corpse from future outcomes")
	var result: Dictionary = game.run.duplicate(true)
	var result_random: int = game.rng.state
	var reloaded = t.state_at("random_actual_corpses")
	t.check(reloaded.load_game() and t.same_saved_value(result, reloaded.run) and reloaded.rng.state == result_random, "Reload retains the random ability, recipient, learned history and exact post-roll RNG")
	t.check(not reloaded.claim_body(0, monster["id"]) and t.same_saved_value(result, reloaded.run) and reloaded.rng.state == result_random, "Reload cannot reroll or reconsume the resolved corpse")
	unchanged(t, game, result, result_random, 1, "Saved successful result remains independent of reload checks")

func test_rejected_claims(t) -> void:
	var game = actual_feeding(t, "random_rejections")
	var monster: Dictionary = game.run["monsters"][0]
	var body: Dictionary = game.run["rewards"][0]
	# Explicit damaged-data fixture; none of these additions earns a real reward.
	body["abilities"].append("not_a_real_ability")
	body["abilities"].append(body["abilities"][0])
	body["abilities"].append("strike")
	var options: Array = game.inheritance_outcomes(0, monster["id"])
	var candidates: Array = options.map(func(value): return value["ability"])
	t.check(not candidates.has("not_a_real_ability") and not candidates.has("strike") and candidates.count("heavy_blow") == 1, "Unknown IDs, recipient-known skills and duplicate corpse entries are filtered")
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	for request in [[-1, monster["id"]], [99, monster["id"]], [0, "missing_recipient"]]:
		t.check(game.inheritance_outcomes(request[0], request[1]).is_empty() and not game.claim_body(request[0], request[1]), "Invalid index or recipient has no outcomes and cannot claim")
		unchanged(t, game, before, random_before, 0, "Rejected invalid claim preserves all state, RNG and save count")
	game.run["phase"] = "prep"
	before = game.run.duplicate(true)
	t.check(game.inheritance_outcomes(0, monster["id"]).is_empty() and not game.claim_body(0, monster["id"]), "Claims and outcome previews require the feeding phase")
	unchanged(t, game, before, random_before, 0, "Wrong-phase claim produces no RNG, save or feeding effects")
	game.run["phase"] = "feeding"
	body["abilities"] = ["strike", "guard", "not_a_real_ability"]
	before = game.run.duplicate(true)
	t.check(game.inheritance_outcomes(0, monster["id"]).is_empty() and not game.claim_body(0, monster["id"]), "A corpse with no unknown valid skill cannot be consumed")
	unchanged(t, game, before, random_before, 0, "Empty eligible pool does not consume the corpse or advance RNG")
	body["abilities"] = ["heavy_blow"]
	t.check(game.claim_body(0, monster["id"]), "A sole unknown candidate still resolves through ordinary random inheritance")
	before = game.run.duplicate(true)
	random_before = game.rng.state
	t.check(not game.claim_body(0, monster["id"]) and not game.claim_body(0, game.run["monsters"][1]["id"]), "Already consumed corpse cannot be claimed again by either recipient")
	unchanged(t, game, before, random_before, 1, "Repeated claims preserve result, feeding, RNG and save count")

func weighted_samples(t, tag: String, pool: Array) -> Array:
	# Each event is a different explicit fixture corpse. Production campaign
	# claims below are never rerolled or edited to obtain a wanted inheritance.
	var game = CountingState.new(t.profile_root + tag + "/")
	game.new_run(998721)
	game.run["phase"] = "feeding"
	game.rng.seed = 640297
	var monster: Dictionary = game.run["monsters"][0]
	var results: Array = []
	for sample in range(512):
		monster["learned"] = []
		monster["consumed"] = []
		monster["feeds"] = 0
		game.run["rewards"] = [{"id": "sample_%d" % sample, "name": "Probability fixture", "class_name": "mage", "form": "mage", "abilities": pool.duplicate(), "claimed": false}]
		t.check(game.claim_body(0, monster["id"]), "Weighted sample consumes a fresh fixture corpse once")
		results.append(game.run["rewards"][0]["taken"])
	return results

func test_weights(t) -> void:
	t.check(Data.INHERITANCE_WEIGHTS == {"common": 4, "uncommon": 2, "rare": 1}, "Inheritance uses explicit common/uncommon/rare weights of 4:2:1")
	var pool: Array = []
	for rarity in ["common", "uncommon", "rare"]:
		for ability in Data.ABILITIES:
			if Data.ABILITIES[ability].get("rarity", "") == rarity and not Data.ABILITIES[ability].get("shared_only", false):
				pool.append(ability)
				break
	t.check(pool.size() == 3, "Ability data contains a real representative of every inheritance rarity")
	if pool.size() != 3: return
	var first: Array = weighted_samples(t, "weighted_a", pool)
	var second: Array = weighted_samples(t, "weighted_b", pool)
	t.check(first == second, "Independent isolated runs with identical seed and corpse pools reproduce every weighted result")
	var expected := [4.0 / 7.0, 2.0 / 7.0, 1.0 / 7.0]
	for index in range(pool.size()):
		var count: int = first.count(pool[index])
		t.check(count > 0 and absf(float(count) / first.size() - expected[index]) < 0.09, "Fixed-seed sample includes rarity %s near its declared probability" % Data.ABILITIES[pool[index]]["rarity"])
	t.check(first.count(pool[0]) > first.count(pool[1]) and first.count(pool[1]) > first.count(pool[2]), "Common outcomes occur more often than uncommon, which occur more often than rare")
