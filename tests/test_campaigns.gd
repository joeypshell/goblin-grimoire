extends RefCounted

# These are bounded scripted-policy reachability checks, not human win rates.
# Different policies consume shared RNG differently, so later encounters are
# not matched comparisons even when the initial seed is identical.
func run(t) -> void:
	t.group("additional production campaigns with concentrated and spread inheritance")
	var main_turns: int = t.campaign_turns
	var main_plays: int = t.campaign_plays
	var completed := 0
	for seed_value in [101, 730205]:
		for spread in [false, true]:
			var policy := "spread" if spread else "concentrated"
			var game = t.state_at("campaign_%s_%d" % [policy, seed_value])
			game.new_run(seed_value)
			var turns_before: int = t.campaign_turns
			var plays_before: int = t.campaign_plays
			var defeats := 0
			var attempts := 0
			var bodies := 0
			while game.run["phase"] == "prep" and attempts < 6:
				attempts += 1
				t.configure_loadout(game)
				var preview: Array = game.party_preview().duplicate(true)
				game.start_raid()
				t.check(game.battle.enemies.map(func(a): return a["abilities"]) == preview.map(func(a): return a["abilities"]), "Additional campaign uses its actual previewed invader pools")
				var won: bool = t.win_raid(game, 120)
				if won:
					bodies += game.run["rewards"].size()
					if game.run["phase"] == "trait" and game.run.get("trait_return", "") == "feeding":
						t.choose_campaign_trait(game, ["pack_instinct", "venom_nest", "spiteful_shields"] if spread else ["venom_nest", "spiteful_shields", "pack_instinct"])
					t.feed_campaign(game, false, spread)
					t.check(game.finish_feeding(), "Additional campaign resolves real bodies and ordinary recovery")
					t.choose_campaign_trait(game, ["pack_instinct", "venom_nest", "spiteful_shields"] if spread else ["venom_nest", "spiteful_shields", "pack_instinct"])
				else:
					t.check(game.run["phase"] == "defeat" and game.run["monsters"].all(func(monster): return monster["hp"] == 0) and game.run["rewards"].is_empty(), "Losing an additional campaign immediately destroys the dungeon without recovery, rewards or retries")
					if game.run["phase"] == "combat": break
					defeats += 1
				if game.run["phase"] == "result": t.advance_campaign(game)
			t.check(game.run["phase"] in ["victory", "defeat"], "Additional campaign finishes within bounded normal attempts")
			if game.run["phase"] == "victory": completed += 1
			t.check(defeats <= 1 and not game.run.has("core"), "Additional campaign has at most one terminal defeat and no independent Core HP")
			print("CAMPAIGN POLICY: ", JSON.stringify({"seed": seed_value, "policy": policy, "phase": game.run["phase"], "raids": game.run["raid"], "turns": t.campaign_turns - turns_before, "plays": t.campaign_plays - plays_before, "defeats": defeats, "bodies": bodies, "traits": game.run["traits"], "forms": game.run["monsters"].map(func(m): return m["form"]), "feeds": game.run["monsters"].map(func(m): return m["feeds"]), "hp": game.run["monsters"].map(func(m): return m["hp"])}))
	t.check(completed > 0, "The revised generic driver demonstrates additional six-raid victories with real costs and random inheritance")
	# Keep the primary regression campaign's summary independently identifiable.
	t.campaign_turns = main_turns
	t.campaign_plays = main_plays
