extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const State = preload("res://scripts/run_state.gd")
const Edges = preload("res://tests/test_edges.gd")
const Inheritance = preload("res://tests/test_inheritance.gd")
const Armor = preload("res://tests/test_armor.gd")
const Balance = preload("res://tests/test_balance.gd")
const Campaigns = preload("res://tests/test_campaigns.gd")
const Traits = preload("res://tests/test_traits.gd")
const Reports = preload("res://tests/test_reports.gd")
const PartyRoutes = preload("res://tests/test_party_routes.gd")
const FormTactics = preload("res://tests/test_form_tactics.gd")

var checks := 0
var failures: Array = []
var groups := 0
var profile_root: String
var campaign_turns := 0
var campaign_plays := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/gameplay_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(profile_root)
	print("Goblin Grimoire verification; isolated profile: ", profile_root)
	test_data_and_cards()
	test_healing_and_shuffle()
	test_knockout_and_faction()
	test_lineage_and_profile()
	test_breach_and_recovery()
	Edges.new().run(self)
	Inheritance.new().run(self)
	Armor.new().run(self)
	Balance.new().run(self)
	Traits.new().run(self)
	Reports.new().run(self)
	FormTactics.new().run(self)
	PartyRoutes.new().run(self)
	test_campaign()
	Campaigns.new().run(self)
	print("RESULT: %d checks across %d groups; %d failures; campaign %d turns / %d card plays" % [checks, groups, failures.size(), campaign_turns, campaign_plays])
	for failure in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func group(name: String) -> void:
	groups += 1
	print("CHECK GROUP: ", name)

func same_saved_value(left, right) -> bool:
	# JSON decodes all numbers as floats; compare semantically, preserving every field.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func roster() -> Array:
	return [Data.new_monster("m0", "Rook"), Data.new_monster("m1", "Moss"), Data.new_monster("m2", "Pip")]

func enemy(id: String = "e0", ability: String = "guard", hp: int = 500) -> Dictionary:
	return {"id": id, "name": "Fixture adventurer", "class_name": "warrior", "form": "warrior", "hp": hp, "max_hp": hp, "abilities": [ability], "block": 0, "statuses": {}}

func fixture(people: Array = [], party: Array = []) -> RefCounted:
	var battle = Combat.new()
	var random := RandomNumberGenerator.new()
	random.seed = 21891
	battle.setup(roster() if people.is_empty() else people, [enemy()] if party.is_empty() else party, random)
	return battle

func card(ability: String, owner: String = "m0", id: String = "fixture_card") -> Dictionary:
	return {"id": id, "ability": ability, "owner": owner}

func all_cards(battle) -> Array:
	return battle.hand + battle.draw_pile + battle.discard

func state_at(tag: String):
	var path := profile_root + tag + "/"
	DirAccess.make_dir_recursive_absolute(path)
	return State.new(path)

func test_data_and_cards() -> void:
	group("starting data, targeting, costs, locked intentions, discard")
	var people := roster()
	for monster in people:
		check(monster["max_hp"] == 20, "Starting goblin maximum HP is 20")
		check(monster["consumed"].is_empty() and monster["feeds"] == 0, "Starter abilities are not consumed feedings")
		check(Data.eligible(monster).is_empty(), "Starter skills unlock no hidden evolution")
	var battle = fixture(people)
	check(battle.hand.size() == 5 and all_cards(battle).size() == 12, "Initial 12-card deck draws five")
	check(battle.energy == 3, "Initial turn grants three energy")
	var instance_ids := {}
	for value in all_cards(battle):
		instance_ids[value["id"]] = true
	check(instance_ids.size() == 12, "Every deck card has its own instance ID")
	var strike := card("strike")
	var mend := card("mend")
	check(battle.legal_targets(strike) == ["e0"], "Attack can target enemy faction only")
	check(battle.legal_targets(mend).size() == 3, "Inherited/basic Mend can target monster allies")
	battle.hand = [strike]
	var energy_before: int = battle.energy
	var hp_before: int = battle.enemies[0]["hp"]
	var intentions_before := JSON.stringify(battle.intents)
	check(not battle.play_card(0, "m0"), "Illegal faction target rejected")
	check(battle.energy == energy_before and battle.hand.size() == 1, "Rejected card preserves energy and hand")
	check(not battle.play_card(99, "e0"), "Invalid hand index rejected")
	battle.energy = 0
	check(not battle.play_card(0, "e0"), "Unaffordable card rejected")
	battle.energy = energy_before
	check(battle.play_card(0, "e0"), "Legal affordable attack resolves")
	check(battle.enemies[0]["hp"] < hp_before, "Played attack immediately deals damage")
	check(battle.energy == energy_before - int(Data.ABILITIES["strike"]["cost"]), "Card charges its defined energy cost")
	check(battle.hand.is_empty() and battle.discard.back()["id"] == strike["id"], "Played instance enters discard")
	check(JSON.stringify(battle.intents) == intentions_before, "Card selection/play does not reroll announced intentions")
	check(not battle.preview(mend, "m0").is_empty(), "Target preview provides readable direct effect")
	for form in Data.FORMS.values():
		check(Data.ABILITIES.has(form["signature"]), "All forms have valid signature cards")

func test_healing_and_shuffle() -> void:
	group("repeatable healing and normal deck circulation")
	var people := roster()
	for monster in people:
		if not monster["learned"].has("mend"):
			monster["learned"].append("mend")
		monster["selected"] = ["strike", "mend"]
	people[0]["hp"] = 1
	var battle = fixture(people)
	var mend_instances := 0
	for value in all_cards(battle):
		if value["ability"] == "mend":
			mend_instances += 1
	var used := {}
	var heals := 0
	var repeated_instance := false
	for turn_index in range(24):
		people[0]["hp"] = 1
		for index in range(battle.hand.size() - 1, -1, -1):
			var value: Dictionary = battle.hand[index]
			if value["ability"] == "mend" and battle.energy >= int(Data.ABILITIES["mend"]["cost"]):
				var id: String = str(value["id"])
				if used.has(id):
					repeated_instance = true
				used[id] = true
				people[0]["hp"] = 1
				check(battle.play_card(index, "m0"), "Cycling Mend remains playable")
				check(people[0]["hp"] > 1, "Repeated Mend still heals")
				heals += 1
		battle.end_turn()
	check(heals > mend_instances * 2 and repeated_instance, "The same healing card reshuffles and heals repeatedly in one raid")
	check(all_cards(battle).size() == 12, "Repeated drawing/discard/shuffle conserves deck instances")
	check(battle.outcome == "active" and battle.hand.size() == 5, "Healing has no hidden limit or stall punishment")

func test_knockout_and_faction() -> void:
	group("knockouts, safe empty deck, relative faction targeting and statuses")
	var people := roster()
	people[0]["hp"] = 1
	var battle = fixture(people, [enemy("e0", "heavy_blow")])
	battle.intents = [{"enemy_id": "e0", "ability": "heavy_blow", "target_id": "m0", "text": "Fixture lethal action"}]
	var learned_before: Array = people[0]["learned"].duplicate()
	var selected_before: Array = people[0]["selected"].duplicate()
	battle.end_turn()
	check(people[0]["hp"] == 0, "Lethal announced enemy action knocks out its target")
	for value in all_cards(battle):
		check(value["owner"] != "m0", "KO owner cards removed from all circulation")
	check(people[0]["learned"] == learned_before and people[0]["selected"] == selected_before, "Knockout retains persistent skills and deck configuration")
	battle.hand = [card("strike", "m0")]
	check(not battle.play_card(0, "e0"), "Knocked-out owner cannot act through stale card")
	battle.hand = []
	battle.draw_pile = []
	battle.discard = []
	battle.end_turn()
	check(battle.hand.is_empty(), "An empty deck ends/draws safely")
	var allies := [enemy("e0", "mend", 100), enemy("e1", "guard", 100)]
	allies[1]["hp"] = 5
	var healer = fixture(roster(), allies)
	healer.intents = [{"enemy_id": "e0", "ability": "mend", "target_id": "e1", "text": "Heal enemy ally"}]
	var monster_hp: int = healer.monsters[0]["hp"]
	healer.end_turn()
	check(healer.enemies[1]["hp"] > 5 and healer.monsters[0]["hp"] == monster_hp, "Enemy Mend heals enemy allies through the same ability definition")
	var controlled = fixture(roster(), [enemy("e0", "heavy_blow")])
	controlled.enemies[0]["statuses"]["stun"] = 1
	controlled.enemies[0]["statuses"]["poison"] = 3
	var enemy_hp: int = controlled.enemies[0]["hp"]
	controlled.end_turn()
	check(controlled.monsters[0]["hp"] == 20, "Stunned enemy skips its locked attack")
	check(controlled.enemies[0]["hp"] < enemy_hp, "Enemy poison ticks at enemy turn end")
	check(int(controlled.enemies[0]["statuses"].get("stun", 0)) == 0, "A stun charge is consumed exactly once")

func test_lineage_and_profile() -> void:
	group("individual consumed histories, evolution retention, hidden permanent grimoire")
	var game = state_at("lineage")
	game.new_run(60410)
	check(game.discoveries().is_empty(), "Fresh isolated profile starts with a truly empty grimoire")
	var monster: Dictionary = game.run["monsters"][0]
	var other: Dictionary = game.run["monsters"][1]
	monster["learned"].append("heavy_blow")
	monster["learned"].append("firebolt")
	monster["feeds"] = 2
	check(game.eligible(monster["id"]).is_empty(), "Learned but unconsumed affinities do not unlock an evolution")
	monster["consumed"] = ["heavy_blow", "heavy_blow"]
	check(game.eligible(monster["id"]).is_empty(), "Duplicate absorbed ability cannot satisfy distinct requirements")
	monster["consumed"] = ["heavy_blow", "firebolt"]
	var choices: Array = game.eligible(monster["id"])
	check(not choices.is_empty(), "Two consumed affinities and feedings unlock first evolution")
	check(game.eligible(other["id"]).is_empty(), "Another monster cannot borrow individual consumption history")
	check(game.discoveries().is_empty(), "Eligibility alone does not discover a form")
	monster["hp"] = 6
	var previous_max: int = monster["max_hp"]
	var previous_skills: Array = monster["learned"].duplicate()
	var selected: Array = monster["selected"].duplicate()
	if not choices.is_empty():
		check(game.evolve(monster["id"], choices[0]["id"]), "Declined eligible transformation remains available during preparation")
		check(monster["form"] == choices[0]["result"], "Evolution sets the actual resulting form")
		check(monster["hp"] == roundi(6.0 * float(monster["max_hp"]) / float(previous_max)), "Evolution preserves rounded health percentage")
		check(monster["learned"] == previous_skills and monster["selected"] == selected, "Evolution preserves identity skills and selected loadout")
		check(game.discoveries().size() == 1, "Only a performed evolution enters the grimoire")
	game.save_game()
	var reload = state_at("lineage")
	check(reload.load_game(), "Evolved run reloads")
	check(reload.discoveries().size() == 1, "Permanent discovery survives save/load")
	reload.new_run(111)
	check(reload.run["monsters"][0]["form"] == "goblin" and reload.discoveries().size() == 1, "New Run resets team while preserving permanent discoveries")

func force_breach(game) -> void:
	if game.run["phase"] == "result":
		game.continue_after_result()
	game.start_raid()
	for monster in game.run["monsters"]:
		monster["hp"] = 0
	game.end_turn()

func test_breach_and_recovery() -> void:
	group("breach, one recovery per resolution, save/reload and terminal defeat")
	var game = state_at("breach")
	game.new_run(923)
	force_breach(game)
	check(game.run["core"] == 75 and game.run["raid"] == 0, "Breach subtracts 25 core once and retries same raid")
	check(game.run["phase"] == "result" and game.run["rewards"].is_empty(), "Surviving-core breach has no bodies and reaches results")
	for monster in game.run["monsters"]:
		check(monster["hp"] == 5, "KO goblin revives through normal ceil 25 percent recovery")
	game.end_turn()
	check(game.run["core"] == 75 and game.run["monsters"][0]["hp"] == 5, "Repeated resolution cannot deduct core or recover again")
	game.save_game()
	var reload = state_at("breach")
	check(reload.load_game(), "Breach result reloads")
	reload.continue_after_result()
	check(reload.run["monsters"][0]["hp"] == 5 and reload.run["core"] == 75, "Reload/continue cannot duplicate recovery or breach")
	for count in range(3):
		force_breach(reload)
	check(reload.run["core"] == 0 and reload.run["phase"] == "defeat", "Fourth breach reaches terminal run defeat")

func clone_battle(game):
	var copy = Combat.new()
	var random := RandomNumberGenerator.new()
	random.seed = game.rng.seed
	random.state = game.rng.state
	copy.restore(game.battle.to_dict(), game.run["monsters"].duplicate(true), random)
	return copy

func position_value(battle) -> float:
	var score := 0.0
	var threatened := {}
	for intent in battle.intents:
		var caster: Dictionary = battle.get_actor(intent["enemy_id"])
		if caster.is_empty() or int(caster["hp"]) <= 0 or int(caster.get("statuses", {}).get("stun", 0)) > 0:
			continue
		var ability: Dictionary = Data.ABILITIES[intent["ability"]]
		for target in battle._targets(ability["target"], caster, intent["target_id"]):
			for effect in ability["effects"]:
				if effect["kind"] == "damage":
					threatened[target["id"]] = float(threatened.get(target["id"], 0)) + battle._amount(effect, ability, caster, target)
	for actor in battle.monsters:
		score += float(actor["hp"]) * 1.2
		score -= maxf(0.0, float(actor["max_hp"]) * 0.45 - float(actor["hp"])) * 1.3
		if actor["hp"] <= 0:
			score -= 45.0
		if threatened.has(str(actor["id"])):
			score += minf(float(actor.get("block", 0)), threatened[actor["id"]]) * 1.25
		var statuses: Dictionary = actor.get("statuses", {})
		score += minf(status_potential(actor, "regen"), float(actor["max_hp"] - actor["hp"])) * 1.2
		score -= (status_potential(actor, "poison") + status_potential(actor, "burn")) * 1.3
		if threatened.has(actor["id"]): score += float(statuses.get("evasion", 0)) * 4.0
	for actor in battle.enemies:
		score -= float(actor["hp"]) * 1.5
		if actor["hp"] <= 0:
			score += 30.0
			continue
		var statuses: Dictionary = actor.get("statuses", {})
		score += (status_potential(actor, "poison") + status_potential(actor, "burn")) * 1.1
		# Consuming temporary defenses advances combat even when a hit loses no HP.
		score -= float(actor.get("block", 0)) * 0.9
		score -= float(statuses.get("evasion", 0)) * 6.0
		if int(statuses.get("stun", 0)) > 0: score += 6.0
	return score

func status_potential(actor: Dictionary, status_id: String) -> float:
	var layers: Array = actor.get("status_layers", {}).get(status_id, [])
	if layers.is_empty() and int(actor.get("statuses", {}).get(status_id, 0)) > 0:
		layers = [int(actor["statuses"][status_id])]
	var total := 0.0
	for strength in layers: total += float(strength * (strength + 1)) / 2.0
	return total

func win_raid(game, bound: int = 180) -> bool:
	var played := 0
	var turns := 0
	while game.run["phase"] == "combat" and turns < bound:
		for action in range(12):
			if game.run["phase"] != "combat":
				break
			var best_index := -1
			var best_target := ""
			var best_gain := 0.1
			var baseline := position_value(game.battle)
			for index in range(game.battle.hand.size()):
				var value: Dictionary = game.battle.hand[index]
				if int(Data.ABILITIES[value["ability"]]["cost"]) > game.battle.energy:
					continue
				for target in game.battle.legal_targets(value):
					var copy = clone_battle(game)
					if not copy.play_card(index, str(target)):
						continue
					# Every card consumes a hand slot, including free cards.
					var gain := (position_value(copy) - baseline) / maxf(1.0, float(Data.ABILITIES[value["ability"]]["cost"]))
					if copy.outcome == "won":
						gain += 1000.0
					if gain > best_gain:
						best_gain = gain
						best_index = index
						best_target = str(target)
			if best_index < 0:
				break
			check(game.play_card(best_index, best_target), "Campaign tactical driver plays through normal card API")
			played += 1
		if game.run["phase"] == "combat":
			game.end_turn()
			turns += 1
	campaign_turns += turns
	campaign_plays += played
	print("  raid ", game.run["raid"], ": ", turns, " turns, ", played, " card plays; phase ", game.run["phase"], "; monsters ", game.run["monsters"].map(func(m): return str(m["hp"]) + "/" + str(m["max_hp"])))
	if game.run["phase"] == "combat":
		print("  combat diagnostic: ", JSON.stringify(game.battle.to_dict()))
	return game.run["phase"] == "feeding"

func feed_campaign(game, test_partial: bool, spread: bool = false) -> bool:
	var partial_done := false
	for body_index in range(game.run["rewards"].size()):
		var body: Dictionary = game.run["rewards"][body_index]
		check(not body["abilities"].is_empty(), "Every actual defeated adventurer offers transferable abilities")
		var recipient: Dictionary = game.run["monsters"][0]
		if spread:
			for candidate in game.run["monsters"]:
				if not game.inheritance_outcomes(body_index, candidate["id"]).is_empty() and int(candidate["feeds"]) < int(recipient["feeds"]): recipient = candidate
		var outcomes: Array = game.inheritance_outcomes(body_index, recipient["id"])
		if outcomes.is_empty():
			for monster in game.run["monsters"]:
				outcomes = game.inheritance_outcomes(body_index, monster["id"])
				if not outcomes.is_empty():
					recipient = monster
					break
		if outcomes.is_empty():
			check(game.skip_body(body_index), "Bodies with no desired new skills may be skipped")
			continue
		var feed_before: int = recipient["feeds"]
		var random_before: int = game.rng.state
		check(not game.claim_body(body_index, "nonexistent_monster") and game.rng.state == random_before, "Invalid recipient cannot claim a real body or advance RNG")
		check(game.claim_body(body_index, recipient["id"]), "Claim real defeated body for chosen recipient with one random inheritance")
		var chosen: String = body["taken"]
		check(outcomes.any(func(value): return value["ability"] == chosen) and body["abilities"].has(chosen), "Random result comes from the actual corpse's eligible ability pool")
		check(recipient["feeds"] == feed_before + 1 and recipient["learned"].has(chosen) and recipient["consumed"].has(chosen), "Consumption records exactly one feeding, learned skill and affinity history")
		check(not game.claim_body(body_index, recipient["id"]), "Same body cannot be consumed twice")
		var eligible: Array = game.eligible(recipient["id"])
		if not eligible.is_empty():
			check(game.evolve(recipient["id"], eligible[0]["id"]), "Campaign reveals and performs an actually earned lineage branch")
		if test_partial and not partial_done:
			game.save_game()
			var replacement = state_at("campaign")
			check(replacement.load_game(), "Partially consumed feeding screen reloads")
			check(replacement.run["rewards"][body_index]["claimed"], "Body remains claimed after feeding reload")
			check(not replacement.claim_body(body_index, recipient["id"]), "Reload cannot reconsume an already claimed body")
			check(JSON.stringify(replacement.run["rewards"]) == JSON.stringify(game.run["rewards"]), "Partly fed reward identities and abilities do not reroll")
			game.run = replacement.run
			game.rng = replacement.rng
			partial_done = true
	return partial_done

func configure_loadout(game) -> void:
	var incoming: Array = game.party_preview().duplicate(true)
	for monster in game.run["monsters"]:
		var first := "strike"
		var best := ability_value(first, monster, incoming)
		for ability in monster["learned"]:
			var value := ability_value(ability, monster, incoming)
			if value > best:
				first = ability
				best = value
		var heal := "patch_up"
		# Keep one repeatable support card; incoming poison/burn makes cleansing useful.
		var ailments := false
		for invader in incoming:
			for ability in invader["abilities"]:
				for effect in Data.ABILITIES[ability]["effects"]:
					if effect.get("status", "") in ["poison", "burn"]: ailments = true
		if monster["learned"].has("mend") and ailments: heal = "mend"
		elif monster["learned"].has("regrowth"): heal = "regrowth"
		# Build around the currently visible form with actually learned skills.
		# No unmet recipe or unearned skill is inspected by the driver.
		match monster["form"]:
			"green_ogre", "ancient_ogre": heal = "guard"
			"basilisk", "ember_basilisk":
				if monster["learned"].has("poisoned_blade") and monster["learned"].has("snare"):
					first = "poisoned_blade"
					heal = "snare"
			"red_ogre", "oni":
				if monster["learned"].has("firebolt") and first != "firebolt": heal = "firebolt"
			"shadow_stalker", "nightstalker":
				for id in ["poisoned_blade", "firebolt", "snare"]:
					if monster["learned"].has(id) and first != id:
						heal = id
						break
		# Setters reject duplicate slots. Move the old second card aside first.
		if monster["selected"][1] == first:
			for spare in monster["learned"]:
				if spare != first and spare != monster["selected"][0]:
					check(game.set_selected(monster["id"], 1, spare), "Preparation makes a legal slot change without a duplicate card")
					break
		check(game.set_selected(monster["id"], 0, first), "Preparation selects an actually learned form-aware combat ability")
		check(game.set_selected(monster["id"], 1, heal), "Preparation selects an actually learned support or form-combo ability")

func ability_value(id: String, monster: Dictionary = {}, incoming: Array = []) -> float:
	var definition: Dictionary = Data.ABILITIES[id]
	if definition["target"] not in ["enemy", "all_enemies"]: return -1.0
	if not monster.is_empty() and not incoming.is_empty():
		return known_form_ability_value(id, monster, incoming)
	var score := 0.0
	for effect in definition["effects"]:
		var amount: int = effect["amount"]
		if effect["kind"] == "damage": score += amount
		if effect.get("status", "") in ["poison", "burn"]: score += amount * (amount + 1) * 0.375
		if effect.get("status", "") == "stun": score += 3.0
	return score / maxf(1.0, float(definition["cost"]))

func known_form_ability_value(id: String, monster: Dictionary, incoming: Array) -> float:
	# Resolution probes never use the run's objects, RNG, saves or report journal.
	var random := RandomNumberGenerator.new()
	random.seed = 28718
	var owner: Dictionary = monster.duplicate(true)
	owner["hp"] = owner["max_hp"]
	var foes: Array = incoming.duplicate(true)
	for foe in foes:
		# Rank reusable effects rather than incidental overkill on a tiny preview.
		foe["hp"] = 500
		foe["max_hp"] = 500
	var probe = Combat.new()
	probe.setup([owner, Data.new_monster("probe_a", "Probe A"), Data.new_monster("probe_b", "Probe B")], foes, random)
	probe.energy = 99
	var setup_skill := ""
	var setup_target: String = foes[0]["id"]
	match owner["form"]:
		"green_ogre", "ancient_ogre":
			setup_skill = "guard"
			setup_target = "probe_a"
		"red_ogre", "oni": setup_skill = Data.FORMS[owner["form"]]["signature"]
		"basilisk", "ember_basilisk", "shadow_stalker", "nightstalker":
			for learned in owner["learned"]:
				if Data.ABILITIES[learned]["effects"].any(func(effect): return effect.get("status", "") in ["poison", "burn", "stun"]):
					setup_skill = learned
					break
	if setup_skill != "":
		probe.hand = [card(setup_skill, owner["id"], "score_setup")]
		probe.play_card(0, setup_target)
	var before := probe_value(probe)
	var energy_before: int = probe.energy
	probe.hand = [card(id, owner["id"], "score_candidate")]
	if not probe.play_card(0, foes[0]["id"]): return -1.0
	var gain := probe_value(probe) - before
	gain += float(probe.hand.size()) * 2.0
	# Energy returns remain useful without making a fixed deck slot worth four cards.
	return gain / maxf(1.0, float(energy_before - probe.energy))

func probe_value(battle) -> float:
	var score := 0.0
	for foe in battle.enemies:
		score -= float(foe["hp"])
		score += (status_potential(foe, "poison") + status_potential(foe, "burn")) * 0.375
		score += float(foe.get("statuses", {}).get("stun", 0)) * 3.0
	for ally in battle.monsters:
		score += float(ally.get("block", 0)) * 0.25
		score += float(ally.get("statuses", {}).get("evasion", 0)) * 2.0
	return score

func choose_campaign_trait(game, preferred: Array = ["venom_nest", "spiteful_shields", "pack_instinct"]) -> void:
	while game.run["phase"] == "trait":
		var choices: Array = game.trait_choices()
		var chosen: String = str(choices[0]) if not choices.is_empty() else ""
		for id in preferred:
			if choices.has(id):
				chosen = id
				break
		var random_before: int = game.rng.state
		check(game.choose_trait(chosen), "Campaign chooses an actually offered dungeon trait through normal API")
		check(game.rng.state == random_before, "Dungeon trait choice preserves campaign RNG")
		if game.run["phase"] == "trait" and game.trait_choices() == choices: break

func test_campaign() -> void:
	group("normal real-card F/E campaign, partial feeding/combat saves, first and advanced evolution, promotion")
	var game = state_at("campaign")
	game.new_run(730204)
	var seen_ranks := {}
	for raid_index in range(6):
		check(game.run["raid"] == raid_index and game.run["phase"] == "prep", "Campaign arrives at expected raid preparation")
		seen_ranks[game.rank_name()] = true
		configure_loadout(game)
		var preview: Array = game.party_preview().duplicate(true)
		check(not preview.is_empty() and JSON.stringify(game.party_preview()) == JSON.stringify(preview), "Incoming-party preview is stable")
		game.start_raid()
		check(game.run["phase"] == "combat", "Prepared raid enters real combat")
		check(JSON.stringify(game.battle.enemies.map(func(a): return a["abilities"])) == JSON.stringify(preview.map(func(a): return a["abilities"])), "Combat uses the previewed actual transferable ability pools")
		if raid_index == 0:
			game.save_game()
			var reloaded = state_at("campaign")
			check(reloaded.load_game() and reloaded.run["phase"] == "combat", "Continue restores an active combat")
			check(same_saved_value(reloaded.battle.to_dict(), game.battle.to_dict()), "Combat save restores hand/piles/energy/locked intents without reroll")
			game = reloaded
		if not win_raid(game):
			check(false, "Bounded real-card driver must win raid %d (seed 730204)" % raid_index)
			return
		check(game.run["rewards"].size() == preview.size(), "Victory bodies correspond to generated adventurers")
		feed_campaign(game, raid_index == 0)
		var before_recovery: Array = game.run["monsters"].map(func(m): return int(m["hp"]))
		check(game.finish_feeding(), "After bodies are resolved, finish feeding advances raid")
		for index in range(3):
			var monster: Dictionary = game.run["monsters"][index]
			var expected := mini(int(monster["max_hp"]), int(before_recovery[index]) + int(ceil(float(monster["max_hp"]) * 0.25)))
			check(monster["hp"] == expected, "Win recovery occurs once after feeding, respecting maximum HP")
		check(not game.finish_feeding(), "Repeated feeding completion cannot recover/advance twice")
		choose_campaign_trait(game)
		if raid_index < 5:
			game.continue_after_result()
	check(seen_ranks.has("F") and seen_ranks.has("E"), "Both F and E rank campaigns were exercised")
	check(game.run["phase"] == "victory" and game.run["raid"] == 6 and game.run["promotion"] == "D", "E champion victory records promotion to D")
	check(game.discoveries().size() >= 2, "Normal campaign discovers first and advanced evolution")
	var advanced := false
	for monster in game.run["monsters"]:
		if monster["form"] in ["oni", "ember_basilisk", "ancient_ogre", "nightstalker"]:
			advanced = true
	check(advanced, "Normal campaign actually performs a later lineage branch")
	check(game.run["traits"].size() == 2 and game.run["trait_milestones"] == [1, 3], "Normal campaign earns two distinct trait milestones")
	var discovery_count: int = game.discoveries().size()
	game.new_run(44)
	check(game.discoveries().size() == discovery_count and game.run["raid"] == 0 and game.run["core"] == 100, "Restart after promotion preserves discovered-only grimoire and resets progression")
