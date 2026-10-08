extends RefCounted

const Loot = preload("res://scripts/dungeon_loot.gd")
const CountingState = preload("res://tests/flow_state_fixture.gd")

func run(t) -> void:
	t.group("saved shared spell drafts, separate economy, two trader visits and unchanged legacy runs")
	test_seeded_pools(t)
	test_pending_and_claim(t)
	test_two_traders(t)
	test_legacy_and_loss(t)

func state(t, tag: String):
	return CountingState.new(t.profile_root + tag + "/")

func win_fixture(game) -> void:
	# Reward-phase fixture; separate campaign checks play real cards without grants.
	game.start_raid()
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()

func accept_early(game) -> void:
	if game.run["phase"] == "trait": game.choose_trait(str(game.trait_choices()[0]))

func skip_meals(game) -> void:
	for index in range(game.run["rewards"].size()): game.skip_body(index)

func unchanged(t, game, before: Dictionary, random_before: int, message: String) -> void:
	t.check(game.run == before and game.rng.state == random_before and game.save_calls == 0, message)

func test_seeded_pools(t) -> void:
	var offer_variants: Dictionary = {}
	var stock_variants: Dictionary = {}
	var rarity_counts: Dictionary = {}
	for seed_value in range(1, 101):
		var offer: Dictionary = Loot.reward(seed_value, 0, Loot.STARTERS)
		var options: Array = offer["options"]
		t.check(options.size() == 3 and options[0] != options[1] and options[1] != options[2] and options[0] != options[2] and options.all(func(id): return Loot.SPELLS.has(id)), "Each seeded draft has three distinct new shared spells")
		t.check(offer == Loot.reward(seed_value, 0, Loot.STARTERS), "A separate derived stream reproduces the same earned draft")
		offer_variants[str(options)] = true
		for id in options:
			var rarity: String = str(t.Data.ABILITIES[id]["rarity"])
			rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
		# Two prior choices cannot exhaust any role at the first trader.
		var library: Array = Loot.STARTERS.duplicate() + [options[0], options[1]]
		var stock: Array = Loot.stock(seed_value, library, 2)
		stock_variants[str(stock)] = true
		t.check(stock.size() in [3, 4] and stock == Loot.stock(seed_value, library, 2), "First trader has three covered roles and optional rare, generated deterministically")
		var ids: Array = []
		for row in stock:
			t.check(not library.has(row["ability"]) and not ids.has(row["ability"]) and row["price"] == Loot.price(row["ability"]) and not row["sold"], "First stock excludes known/duplicate spells and preserves real rarity prices")
			ids.append(row["ability"])
		for role in Loot.ROLES:
			t.check(stock.any(func(row): return row["id"] == "trader_2_" + str(role) and Loot.ROLES[role].has(row["ability"])), "First stock guarantees an unknown " + str(role) + " option")
		t.check(stock.any(func(row): return int(row["price"]) <= 70), "Every first stock contains an affordable choice at the 70-gold earned boundary")
	t.check(offer_variants.size() > 20 and stock_variants.size() > 10, "Saved offers and shops vary across bounded run seeds")
	t.check(int(rarity_counts.get("rare", 0)) > 0 and int(rarity_counts.get("common", 0)) > int(rarity_counts.get("rare", 0)), "Weighted unknown-spell draws still offer real rares while favoring common cards across bounded seeds")
	var exhausted: Array = Loot.stock(413, Loot.STARTERS.duplicate() + Loot.ROLES["heal"], 5)
	var known: Dictionary = exhausted.filter(func(row): return row["id"] == "trader_5_heal")[0]
	t.check(known["owned"] and known["sold"] and known["price"] == 0 and Loot.ROLES["heal"].has(known["ability"]), "An exhausted later role is an honest already-learned reference, never invented or charged")

func test_pending_and_claim(t) -> void:
	var game = state(t, "loot_pending")
	game.new_run(52014)
	t.check(game.run["loot_version"] == 1 and game.run["gold"] == 0 and game.run["spell_library"] == Loot.STARTERS and game.dungeon_spell_loadout() == Loot.STARTERS, "New runs opt into the economy with exactly the original three shared spells")
	var returned: Array = game.dungeon_spell_loadout()
	returned.clear()
	t.check(game.dungeon_spell_loadout() == Loot.STARTERS, "Shared loadout accessor returns an independent array")
	game.run["monsters"][0]["hp"] = 5
	win_fixture(game)
	var random_before: int = game.rng.state
	t.check(game.run["phase"] == "trait" and game.spell_reward_choices().is_empty() and game.run["gold"] == 35 and game.run["spell_offer"]["options"].size() == 3, "First win saves gold/draft while the early trait still controls the initial reward screen")
	accept_early(game)
	var options: Array = game.spell_reward_choices()
	var monsters: Array = game.run["monsters"].duplicate(true)
	var bodies: Array = game.run["rewards"].duplicate(true)
	var offer: Dictionary = game.run["spell_offer"].duplicate(true)
	game.save_game()
	var loaded = state(t, "loot_pending")
	t.check(loaded.load_game() and loaded.run["spell_offer"] == offer and loaded.run["gold"] == 35 and loaded.run["monsters"] == monsters and loaded.run["rewards"] == bodies and loaded.rng.state == random_before, "Pending Continue preserves draft, earned gold, actual bodies, raw HP and gameplay RNG")
	var modified: Array = loaded.spell_reward_choices()
	modified.clear()
	var before: Dictionary = loaded.run.duplicate(true)
	loaded.save_calls = 0
	for repeat in range(5): loaded.spell_reward_choices()
	t.check(not loaded.choose_spell_reward("rally", 0) and not loaded.choose_spell_reward(str(options[0]), -1) and not loaded.choose_spell_reward(str(options[0]), 3), "Known/unoffered spells and invalid slots cannot resolve an earned draft")
	unchanged(t, loaded, before, random_before, "Invalid/repeated queries leave reward, report, saves and RNG unchanged")
	skip_meals(loaded)
	before = loaded.run.duplicate(true)
	loaded.save_calls = 0
	t.check(not loaded.finish_feeding(), "Actual bodies alone cannot bypass the unresolved shared spell decision")
	unchanged(t, loaded, before, random_before, "Blocked recovery cannot heal, advance or write a report while its draft is pending")
	var chosen: String = str(options[0])
	t.check(loaded.choose_spell_reward(chosen, 0) and loaded.dungeon_spell_loadout()[0] == chosen and loaded.run["spell_library"].has(chosen) and loaded.run["spell_offer"]["chosen"] == chosen and loaded.run["spell_offer"]["slot"] == 0 and loaded.run["spell_offer"]["resolved"], "Choosing one offered spell learns it and explicitly replaces one of three shared slots")
	t.check(loaded.run["monsters"] == monsters and loaded.rng.state == random_before and loaded.run["recovered_id"] == 0 and loaded.run["spell_history"] == [{"raid": 1, "ability": chosen, "slot": 0}], "Shared acquisition never feeds/teaches/heals a monster or consumes gameplay RNG")
	before = loaded.run.duplicate(true)
	loaded.save_calls = 0
	t.check(not loaded.choose_spell_reward(str(options[1]), 1) and not loaded.skip_spell_reward() and not loaded.select_dungeon_spell(1, chosen), "Resolved drafts, repeated skips and duplicate equipped copies are rejected")
	unchanged(t, loaded, before, random_before, "Rejected repeated reward actions cannot duplicate skill, gold, report or persistence")
	var selected = state(t, "loot_pending")
	t.check(selected.load_game() and selected.run["spell_offer"] == loaded.run["spell_offer"] and selected.dungeon_spell_loadout() == loaded.dungeon_spell_loadout() and selected.rng.state == random_before, "Chosen reward and replaced shared loadout survive Continue without another grant")
	t.check(selected.finish_feeding() and selected.run["phase"] == "result" and selected.run["monsters"][0]["hp"] == 10 and selected.run["gold"] == 35, "Only final reward completion applies normal recovery once")
	t.check(selected.select_dungeon_spell(0, "rally") and selected.dungeon_spell_loadout() == Loot.STARTERS, "A retained original spell can be freely re-equipped from the shared library")
	selected.continue_after_result()
	selected.select_dungeon_spell(0, chosen)
	selected.start_raid()
	t.check(t.all_cards(selected.battle).size() == 12 and t.all_cards(selected.battle).any(func(card): return card["owner"] == "" and card["ability"] == chosen), "The next actual battle uses its chosen shared spell inside the unchanged twelve-card deck")
	before = selected.run.duplicate(true)
	selected.save_calls = 0
	t.check(not selected.select_dungeon_spell(0, "rally"), "Shared spell selection is locked in active combat")
	unchanged(t, selected, before, selected.rng.state, "A combat selection request cannot alter the current battle loadout")

func test_two_traders(t) -> void:
	var game = state(t, "loot_two_traders")
	game.new_run(52017)
	var spent: int = 0
	var first_stock_id: String = ""
	for raid in range(6):
		win_fixture(game)
		accept_early(game)
		var monsters: Array = game.run["monsters"].duplicate(true)
		if raid < 5:
			var choices: Array = game.spell_reward_choices()
			t.check(choices.size() == 3 and choices.all(func(id): return not game.run["spell_library"].has(id)), "Every actual nonfinal win offers three distinct unknown spells")
			if raid == 0: t.check(game.skip_spell_reward() and game.run["spell_offer"]["skipped"] and game.run["spell_history"].is_empty(), "Explicit skip resolves only the spell draft, without fabricating a learned choice")
			else: t.check(game.choose_spell_reward(str(choices[0]), raid % 3), "Later wins choose an actual unknown offered spell")
		else: t.check(game.spell_reward_choices().is_empty() and not game.run.has("spell_offer"), "The final victory has no unusable draft")
		t.check(game.run["monsters"] == monsters, "Draft/skip never alters the goblin consumed histories, forms or learned skills")
		skip_meals(game)
		t.check(game.finish_feeding(), "Chosen or skipped draft and resolved bodies permit one ordinary recovery")
		while game.run["phase"] == "trait": game.choose_trait(str(game.trait_choices()[0]))
		if raid == 5: break
		var random_before: int = game.rng.state
		var hp: Array = game.run["monsters"].map(func(monster): return monster["hp"])
		var stock_before: Array = game.trader_stock()
		game.continue_after_result()
		if raid not in [1, 4]:
			t.check(game.run["phase"] == "prep", "Other results continue directly to preparation")
			continue
		t.check(game.run["phase"] == "trader" and game.run["trader_raid"] == raid + 1 and game.trader_stock() == stock_before and game.rng.state == random_before and game.run["monsters"].map(func(monster): return monster["hp"]) == hp, "An earned trader opens with saved stock and no repeated recovery or gameplay RNG")
		var expected_gold: int = (70 if raid == 1 else 200) - spent
		t.check(game.run["gold"] == expected_gold, "Regular/champion victory awards accumulate exactly once before this trader")
		var loaded = state(t, "loot_two_traders")
		t.check(loaded.load_game() and loaded.run["phase"] == "trader" and loaded.trader_stock() == stock_before and loaded.run["gold"] == expected_gold and loaded.rng.state == random_before, "Trader Continue retains the exact stock, prices, gold and RNG")
		var copied: Array = loaded.trader_stock()
		copied[0]["sold"] = not copied[0]["sold"]
		t.check(loaded.trader_stock() == stock_before, "Stock getter returns independent dictionaries")
		var before: Dictionary = loaded.run.duplicate(true)
		loaded.save_calls = 0
		t.check(not loaded.buy_spell("missing", 0) and not loaded.buy_spell(str(stock_before[0]["id"]), 9), "Invalid stock or equip slot cannot purchase anything")
		for expensive in stock_before:
			if not expensive["sold"] and int(expensive["price"]) > int(loaded.run["gold"]):
				t.check(not loaded.buy_spell(str(expensive["id"]), 0), "An unaffordable real stock spell cannot be charged or granted")
		if raid == 4: t.check(not loaded.buy_spell(first_stock_id, 0), "A stale first-visit stock ID cannot purchase a new second-visit spell")
		unchanged(t, loaded, before, random_before, "Rejected purchases leave stock, balance, report and RNG untouched")
		var purchases: Array = loaded.trader_stock().filter(func(row): return not row["sold"] and int(row["price"]) <= int(loaded.run["gold"]))
		t.check(not purchases.is_empty(), "Both earned traders have a usable affordable unknown spell")
		if not purchases.is_empty():
			var row: Dictionary = purchases[0]
			first_stock_id = str(row["id"]) if raid == 1 else first_stock_id
			var roster: Array = loaded.run["monsters"].duplicate(true)
			t.check(loaded.buy_spell(str(row["id"]), 2) and loaded.run["gold"] == expected_gold - int(row["price"]) and loaded.dungeon_spell_loadout()[2] == row["ability"], "One actual shop purchase deducts its saved price and equips its new spell")
			t.check(loaded.run["monsters"] == roster and loaded.rng.state == random_before, "Spell purchases never change corpse inheritance/evolution history or gameplay RNG")
			spent += int(row["price"])
			before = loaded.run.duplicate(true)
			loaded.save_calls = 0
			t.check(not loaded.buy_spell(str(row["id"]), 1), "Sold stock cannot be bought again")
			unchanged(t, loaded, before, random_before, "Repeated buys cannot double-charge or double-grant")
		var bought = state(t, "loot_two_traders")
		t.check(bought.load_game() and bought.run == loaded.run, "Purchased stock/loadout/balance preserve exactly across Continue")
		t.check(bought.leave_trader() and bought.run["phase"] == "prep" and bought.run["trader_visited_raids"].has(raid + 1), "Leaving records this earned trader visit and enters the next actual preparation")
		before = bought.run.duplicate(true)
		bought.save_calls = 0
		t.check(not bought.leave_trader() and not bought.buy_spell(str(stock_before[0]["id"]), 0), "Closed traders cannot reopen or accept a delayed purchase")
		unchanged(t, bought, before, bought.rng.state, "Stale closed-shop actions cannot mutate the next preparation")
		game = bought
	t.check(game.run["phase"] == "victory" and game.run["trader_visited_raids"] == [2, 5] and game.run["gold"] == 260 - spent, "Six earned wins finish with two real visits, both champion gold awards and no final unusable draft")

func test_legacy_and_loss(t) -> void:
	var old = state(t, "loot_legacy")
	old.new_run(84011)
	old.start_raid()
	# Explicit v0.15 combat fixture has existing Block and layered statuses, but
	# no Echo state or flags for the four newly introduced traits.
	old.battle.monsters[0]["block"] = 7
	old.battle._status(old.battle.monsters[0], "poison", 2)
	old.battle._status(old.battle.enemies[0], "burn", 2)
	old.save_game()
	var saved: Dictionary = old._read_json(old._prefix + "run.json")
	for key in ["loot_version", "dungeon_spells", "spell_library", "gold", "spell_history", "trader_visited_raids"]: saved.erase(key)
	saved["battle"].erase("dungeon_state")
	for key in ["blood_cauldron_triggered", "wildfire_triggered", "spellweaver_triggered"]: saved["battle"]["trait_state"].erase(key)
	for id in ["blood_cauldron", "wildfire", "lingering_wards", "spellweaver"]: saved["battle"]["trait_state"]["trigger_counts"].erase(id)
	saved["report"]["build"] = "0.15.0"
	for key in ["loot_version", "dungeon_spells", "spell_library", "gold", "spell_history", "trader_visited_raids"]: saved["report"]["summary"]["current"].erase(key)
	var old_events: Array = saved["report"]["events"].duplicate(true)
	var historical: Dictionary = saved["report"].duplicate(true)
	historical["id"] = "legacy_closed_loot_test"
	historical["status"] = "victory"
	historical["summary"]["current"]["phase"] = "victory"
	old._reports.upsert(historical)
	old._write_json(old._prefix + "reports.json", old._reports.journal())
	old._write_json(old._prefix + "run.json", saved)
	var loaded = state(t, "loot_legacy")
	t.check(loaded.load_game() and not loaded.run.has("loot_version") and loaded.dungeon_spell_loadout() == Loot.STARTERS and loaded.run["gold"] == 0 and not loaded.battle.dungeon_state["echo_ready"], "A genuine missing-state v0.15 save receives unarmed Echo/default shared spells without opting into new rewards")
	var restored: Dictionary = loaded.battle.to_dict()
	restored.erase("dungeon_state")
	for key in ["blood_cauldron_triggered", "wildfire_triggered", "spellweaver_triggered"]: restored["trait_state"].erase(key)
	for id in ["blood_cauldron", "wildfire", "lingering_wards", "spellweaver"]: restored["trait_state"]["trigger_counts"].erase(id)
	t.check(t.same_saved_value(restored, saved["battle"]), "Additive internal defaults preserve all old hand/piles/intents/actor status layers/Block/turn/RNG/trait counters")
	t.check(loaded.current_report()["build"] == "0.15.0" and loaded.current_report()["events"] == old_events and loaded.report_list().any(func(report): return report == historical), "Continue adds no historical actions and leaves the old closed report immutable")
	for raid in range(2):
		if raid > 0: loaded.start_raid()
		for enemy in loaded.battle.enemies: enemy["hp"] = 0
		loaded.end_turn()
		accept_early(loaded)
		t.check(not loaded.run.has("spell_offer") and loaded.spell_reward_choices().is_empty() and loaded.run["gold"] == 0, "Future legacy wins have no retroactive gold or new spell draft")
		skip_meals(loaded)
		t.check(loaded.finish_feeding(), "Legacy meals need no extra spell decision")
		while loaded.run["phase"] == "trait": loaded.choose_trait(str(loaded.trait_choices()[0]))
		loaded.continue_after_result()
	t.check(loaded.run["phase"] == "prep" and loaded.run["raid"] == 2 and not loaded.run.has("trader_stock") and not loaded.leave_trader(), "Legacy progression passes the old first-champion boundary without a retroactive trader")
	var defeat = state(t, "loot_loss")
	defeat.new_run(44012)
	defeat.start_raid()
	for monster in defeat.run["monsters"]: monster["hp"] = 0
	defeat.end_turn()
	var before: Dictionary = defeat.run.duplicate(true)
	defeat.save_calls = 0
	t.check(defeat.run["phase"] == "defeat" and defeat.run["gold"] == 0 and not defeat.run.has("spell_offer") and defeat.spell_reward_choices().is_empty() and not defeat.choose_spell_reward("arcane_sweep", 0) and not defeat.skip_spell_reward() and not defeat.buy_spell("trader_2_heal", 0) and not defeat.select_dungeon_spell(0, "rally") and not defeat.leave_trader(), "Immediate full wipe cannot grant or use a draft, purchase, selection or trader")
	unchanged(t, defeat, before, defeat.rng.state, "Terminal economy requests are mutation/save/RNG free")
