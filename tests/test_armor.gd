extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")

func run(t) -> void:
	t.group("permanent armor, temporary block, previews and persistence")
	var battle = t.fixture()
	var victim: Dictionary = battle.enemies[0]
	victim["armor"] = 2
	victim["block"] = 3
	victim["hp"] = 20
	victim["max_hp"] = 20
	var strike: Dictionary = t.card("strike")
	var before: Dictionary = battle.to_dict()
	var preview: String = Copy.preview(battle, strike, victim)
	t.check(preview.contains("1 HP lost") and preview.contains("2 armor") and preview.contains("3 blocked"), "Card preview explains armor then block and exact HP loss")
	t.check(t.same_saved_value(before, battle.to_dict()), "Armor preview does not mutate combat or RNG")
	battle.hand = [strike]
	t.check(battle.play_card(0, victim["id"]), "Normal card can hit an armored target")
	t.check(victim["hp"] == 19 and victim["block"] == 0 and victim["armor"] == 2, "Six damage loses two to permanent armor and spends three block")
	battle._damage(victim, 6)
	t.check(victim["hp"] == 15 and victim["armor"] == 2, "Armor prevents damage again on a second hit without being consumed")
	victim["block"] = 5
	battle._damage(victim, 1)
	t.check(victim["hp"] == 15 and victim["block"] == 5, "Armor can absorb a full hit without spending block or healing")
	victim["statuses"] = {"evasion": 1}
	battle._damage(victim, 6)
	t.check(victim["hp"] == 15 and victim["block"] == 5 and victim["statuses"].is_empty(), "Evasion prevents a hit before block and leaves armor intact")
	victim["statuses"] = {"poison": 3, "burn": 2}
	battle._tick_statuses([victim])
	t.check(victim["hp"] == 10 and victim["block"] == 5 and victim["armor"] == 2, "Poison and burning bypass armor and block")
	battle.end_turn()
	t.check(victim["armor"] == 2, "Turn changes do not expire permanent armor")
	t.check(Copy.defenses(victim) == "Armor 2 · Block 7", "Defense copy distinguishes permanent armor from refreshed Guard block")
	t.check(Data.armor({}) == 0 and Data.armor({"armor": -5}) == 0, "Missing or invalid negative armor is safely zero")
	for raid in range(6):
		var random := RandomNumberGenerator.new()
		random.seed = 2000 + raid
		for adventurer in Data.generate_party(raid, random):
			var expected: int = {"warrior": 1, "defender": 2}.get(adventurer["class_name"], 0)
			t.check(Data.armor(adventurer) == expected, "Generated class armor matches editable class balance")
	var state = t.state_at("armor_save")
	state.new_run(35191)
	state.start_raid()
	state.battle.enemies[0]["armor"] = 2
	state.battle.enemies[0]["block"] = 4
	state.save_game()
	var loaded = t.state_at("armor_save")
	t.check(loaded.load_game() and Data.armor(loaded.battle.enemies[0]) == 2 and loaded.battle.enemies[0]["block"] == 4, "Armor and block survive a combat save separately")
	loaded.battle.enemies[0].erase("armor")
	loaded.save_game()
	var legacy = t.state_at("armor_save")
	t.check(legacy.load_game() and Data.armor(legacy.battle.enemies[0]) == 0, "Continuing a prior save without armor preserves its unarmored enemy")
	state.run["phase"] = "feeding"
	state.run["rewards"] = [{"id": "armor_body", "name": "Armored defender", "class_name": "defender", "form": "defender", "armor": 2, "abilities": ["heavy_blow"], "claimed": false}]
	var monster: Dictionary = state.run["monsters"][0]
	t.check(state.claim_body(0, monster["id"]), "Armored corpse can grant its actual ability through random inheritance")
	t.check(Data.armor(monster) == 0 and monster["learned"].has("heavy_blow") and state.run["rewards"][0]["armor"] == 2, "Devouring grants an ability and retains corpse armor only as information")
