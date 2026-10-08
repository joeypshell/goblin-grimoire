extends RefCounted

const Reports = preload("res://scripts/run_reports.gd")

func run(h) -> void:
	h.group("Spell and trader observations from accepted production actions")
	var game = h.state_at("loot_report_flow")
	game.new_run(730205)
	var initial: Dictionary = Reports.view(game.run)
	h.check(initial.get("gold", -1) == 0 and initial.get("dungeon_spells", []) == game.dungeon_spell_loadout(), "A new report starts with actual gold and shared cards")
	h.check(initial["deck"].size() == 12 and initial["deck"].filter(func(card): return card["owner"] == "").size() == 3, "Recorded deck retains nine owned and three shared cards")
	game.start_raid()
	if not h.win_raid(game):
		h.check(false, "Report integration earns its first victory through actual combat")
		return
	h.choose_campaign_trait(game)
	var offered: Array = game.spell_reward_choices()
	h.check(offered.size() == 3, "The recorded first reward is an actual three-spell offer")
	if offered.is_empty(): return
	var chosen: String = str(offered[0])
	for id in offered:
		if id in ["arcane_sweep", "ember_storm", "cinder_seed", "shatter_wave", "renewal_wave"]:
			chosen = str(id)
			break
	var roster_before: Array = game.run["monsters"].duplicate(true)
	var random_before: int = game.rng.state
	h.check(game.choose_spell_reward(chosen, 0), "The report observes a valid offered spell equipped immediately")
	h.check(game.rng.state == random_before and game.run["monsters"] == roster_before, "Recording a dungeon reward changes no monster skill provenance or gameplay RNG")
	var accepted: Dictionary = game.current_report()
	var current: Dictionary = accepted["summary"]["current"]
	h.check(current.get("gold", 0) == 35 and current["dungeon_spells"][0] == chosen and current["spell_library"].has(chosen), "The report records earned gold and the actual learned/equipped spell")
	h.check(current["deck"].any(func(card): return card["owner"] == "" and card["ability"] == chosen), "Latest deck contains the chosen shared spell instead of its replaced starter")
	var chosen_events: Array = accepted["events"].filter(func(entry): return entry["kind"] == "spell_reward_chosen")
	h.check(chosen_events.size() == 1 and accepted["events"].any(func(entry): return entry["kind"] == "spell_reward_offered"), "Offers and accepted choices have separate once-only observations")
	var revision: int = int(accepted["revision"])
	h.check(not game.choose_spell_reward(chosen, 1) and int(game.current_report()["revision"]) == revision, "A duplicate claim adds no observed action")
	current["dungeon_spells"].clear()
	current["spell_library"].clear()
	h.check(game.dungeon_spell_loadout()[0] == chosen and game.current_report()["summary"]["current"]["spell_library"].has(chosen), "Returned report arrays cannot mutate authoritative equipment or recorded state")
	game.save_game()
	var loaded = h.state_at("loot_report_flow")
	h.check(loaded.load_game() and h.same_saved_value(loaded.current_report(), game.current_report()), "Continue preserves the accepted spell report without fabricating another choice")
	game = loaded
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	h.check(game.finish_feeding(), "The report fixture completes one ordinary recovery after its reward")
	game.continue_after_result()
	game.start_raid()
	if not h.win_raid(game):
		h.check(false, "Report integration earns trader access through actual second combat")
		return
	h.choose_campaign_trait(game)
	h.check(game.skip_spell_reward(), "The second actual spell offer can be explicitly declined")
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	h.check(game.finish_feeding(), "Trader access follows actual second recovery")
	game.continue_after_result()
	h.check(game.run["phase"] == "trader", "The report observes the earned trader phase")
	var stock: Array = game.trader_stock()
	var purchase: Dictionary = {}
	for item in stock:
		if not item.get("sold", false) and not item.get("owned", false) and int(item["price"]) <= int(game.run["gold"]):
			purchase = item
			break
	h.check(not purchase.is_empty(), "Actual saved trader stock contains an affordable unowned spell")
	if purchase.is_empty(): return
	var gold_before: int = int(game.run["gold"])
	h.check(game.buy_spell(str(purchase["id"]), 1), "The report fixture makes a real affordable purchase and replacement")
	var bought: Dictionary = game.current_report()
	h.check(bought["summary"]["current"]["gold"] == gold_before - int(purchase["price"]) and bought["summary"]["current"]["dungeon_spells"][1] == purchase["ability"], "The report retains actual payment and purchased equipment")
	h.check(bought["events"].filter(func(entry): return entry["kind"] == "spell_purchased").size() == 1, "A valid purchase is recorded once")
	var purchase_revision: int = int(bought["revision"])
	h.check(not game.buy_spell(str(purchase["id"]), 2) and int(game.current_report()["revision"]) == purchase_revision, "A sold-stock repeat creates no false purchase event")
	var legacy: Dictionary = game.run.duplicate(true)
	for key in ["loot_version", "gold", "dungeon_spells", "spell_library", "spell_offer", "spell_history", "trader_stock", "trader_raid", "trader_visited_raids"]: legacy.erase(key)
	var legacy_view: Dictionary = Reports.view(legacy)
	h.check(not legacy_view.has("gold") and not legacy_view.has("spell_offer") and legacy_view["deck"].filter(func(card): return card["owner"] == "").map(func(card): return card["ability"]) == ["rally", "core_pulse", "snare_dungeon"], "Legacy views retain their original shared deck and omit unobserved loot history")
