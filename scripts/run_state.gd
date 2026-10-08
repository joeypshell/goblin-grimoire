class_name RunState
extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const Traits = preload("res://scripts/dungeon_traits.gd")
const Routes = preload("res://scripts/raid_routes.gd")
const Reports = preload("res://scripts/run_reports.gd")
const Recap = preload("res://scripts/battle_recap.gd")
const Loot = preload("res://scripts/dungeon_loot.gd")
const SAVE_VERSION = 1
const LOSS_RULE = "party_wipe_ends_run"

signal changed
signal report_changed(id: String)

var run: Dictionary = {}
var profile: Dictionary = {"discoveries": {}}
var rng = RandomNumberGenerator.new()
var battle: Battle
var last_evolution: Dictionary = {}
var _prefix: String
var _reports = Reports.new()
var _report_emitted: Dictionary = {}

func _init(save_prefix: String = "user://") -> void:
	_prefix = save_prefix.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_prefix)
	_load_profile()
	_reports.load_journal(_read_json(_prefix + "reports.json"))

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	var restored: Dictionary = _restore_numbers(parsed) if parsed is Dictionary else {}
	if path.get_file() == "run.json" and restored.get("seed") is String:
		restored["seed"] = int(restored["seed"])
	return restored

func _restore_numbers(value):
	# JSON decodes integers as floats. Preserve IDs, counters and HP as integers.
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		for index in range(value.size()):
			value[index] = _restore_numbers(value[index])
	elif value is Dictionary:
		for key in value:
			value[key] = _restore_numbers(value[key])
	return value

func _write_json(path: String, value: Dictionary) -> bool:
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save Goblin Grimoire: " + path)
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	var result = DirAccess.rename_absolute(temporary, path)
	if result != OK:
		push_error("Cannot replace save: " + error_string(result))
	return result == OK

func _load_profile() -> void:
	var saved = _read_json(_prefix + "grimoire.json")
	if saved.get("discoveries") is Dictionary:
		profile = saved

func has_save() -> bool:
	var saved = _read_json(_prefix + "run.json")
	return saved.get("version", 0) == SAVE_VERSION and saved.get("monsters") is Array and saved.get("phase", "") in ["prep", "combat", "feeding", "trait", "result", "trader", "victory", "defeat"]

func save_game() -> void:
	if run.is_empty():
		return
	run["version"] = SAVE_VERSION
	run["rng_state"] = str(rng.state)
	if battle != null and run["phase"] == "combat":
		run["battle"] = battle.to_dict()
	else:
		run.erase("battle")
	_reports.ensure(run)
	_reports.sync_view(run)
	_reports.finish(run)
	_write_json(_prefix + "grimoire.json", profile)
	# JSON numbers lose low bits of a 64-bit seed. Keep the live API integer-valued,
	# but persist its exact decimal spelling, just as we already do for RNG state.
	var saved_run := run.duplicate()
	saved_run["seed"] = str(run["seed"])
	if _write_json(_prefix + "run.json", saved_run): _persist_report(run["report"])

func _persist_report(report: Dictionary) -> void:
	_reports.upsert(report)
	if not _write_json(_prefix + "reports.json", _reports.journal()): return
	var id: String = report["id"]
	if int(_report_emitted.get(id, -1)) != int(report["revision"]):
		_report_emitted[id] = report["revision"]
		report_changed.emit(id)

func current_report() -> Dictionary:
	return run.get("report", {}).duplicate(true)

func report_list() -> Array:
	var result: Array = _reports.reports.duplicate(true)
	var current := current_report()
	if current.is_empty(): return result
	for index in range(result.size()):
		if result[index].get("id", "") == current["id"]:
			if int(current["revision"]) >= int(result[index]["revision"]): result[index] = current
			return result
	result.append(current)
	while result.size() > Reports.MAX_REPORTS: result.pop_front()
	return result

func _abandon_previous_report() -> void:
	var previous: Dictionary = run.duplicate(true) if not run.is_empty() else _read_json(_prefix + "run.json")
	if previous.is_empty(): return
	if battle != null and previous.get("phase", "") == "combat": previous["battle"] = battle.to_dict()
	_reports.ensure(previous)
	_reports.finish(previous, true)
	_persist_report(previous["report"])

func load_game() -> bool:
	if not has_save():
		return false
	_load_profile()
	run = _read_json(_prefix + "run.json")
	var legacy_loss: bool = run.has("core") and run.get("last_result", "") == "breach" and run.get("phase", "") in ["prep", "result", "trait", "defeat"]
	run.erase("core")
	run["loss_rule"] = LOSS_RULE
	if not run.get("traits") is Array: run["traits"] = []
	if not run.get("trait_milestones") is Array: run["trait_milestones"] = []
	# Existing runs keep their old rewards and timing. Default shared spells do
	# not opt a historical run into the new economy.
	if not run.get("dungeon_spells") is Array: run["dungeon_spells"] = Loot.STARTERS.duplicate()
	if not run.get("spell_library") is Array: run["spell_library"] = Loot.STARTERS.duplicate()
	if not run.has("gold"): run["gold"] = 0
	Data.ensure_priest_offense(run.get("party", []))
	Data.ensure_champion_mechanics(run.get("party", []))
	if run.get("battle") is Dictionary:
		Data.ensure_priest_offense(run["battle"].get("enemies", []))
		Data.ensure_champion_mechanics(run["battle"].get("enemies", []))
	rng.seed = int(run["seed"])
	rng.state = int(run["rng_state"])
	battle = null
	last_evolution = {}
	if run["phase"] == "combat":
		if not run.get("battle") is Dictionary:
			return false
		battle = Combat.new()
		battle.restore(run["battle"], run["monsters"], rng)
	var previous_phase: String = run["phase"]
	if legacy_loss:
		for monster in run["monsters"]: monster["hp"] = 0
		run["rewards"] = []
		run["phase"] = "defeat"
		run.erase("trait_return")
	if run["phase"] == "defeat": run.erase("raid_recap")
	# Legacy pending rewards receive their stable offer at load, never on query.
	if run["phase"] == "trait": _ensure_first_trait_offer()
	_reports.ensure(run)
	if legacy_loss:
		if run["report"].get("status", "active") == "active":
			_reports.record(run, "rules_changed", {"rule": LOSS_RULE, "from": previous_phase})
	elif battle != null:
		# A saved full wipe ends the run without drawing cards or replaying an action.
		battle._check_outcome()
		_resolve_battle()
	# Old runs receive earned choices at a safe preparation/result boundary.
	if run["phase"] in ["prep", "result"]: _open_trait_reward(run["phase"])
	save_game()
	changed.emit()
	return true

func new_run(seed_value: int = 0) -> void:
	_abandon_previous_report()
	_load_profile()
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	rng.seed = seed_value
	run = {
		"seed": seed_value, "monsters": [Data.new_monster("m1", "Grub"), Data.new_monster("m2", "Nix"), Data.new_monster("m3", "Moss")],
		"raid": 0, "phase": "prep", "rewards": [],
		"loss_rule": LOSS_RULE,
		"resolved_id": 0, "recovered_id": 0, "last_result": "", "promotion": "", "evolution_budget": 0,
		"traits": [], "trait_milestones": [],
		"loot_version": 1, "dungeon_spells": Loot.STARTERS.duplicate(), "spell_library": Loot.STARTERS.duplicate(),
		"gold": 0, "spell_history": [], "trader_visited_raids": [],
	}
	battle = null
	last_evolution = {}
	_reports.begin(run)
	party_preview()
	save_game()
	changed.emit()

func party_preview() -> Array:
	if run.is_empty() or int(run["raid"]) >= _campaign_size():
		return []
	if not run.has("party"):
		run["party"] = Data.generate_party(int(run["raid"]), rng)
		var options := Routes.choices(int(run["raid"]), int(run["seed"]), run["party"])
		if not options.is_empty():
			run["party_options"] = options
			run["party_options_raid"] = int(run["raid"])
			run["party_choice"] = "standard"
			run["party_locked"] = false
		save_game()
	Data.ensure_champion_mechanics(run["party"])
	return run["party"]

func party_choices() -> Array:
	if run.get("phase", "") != "prep" or run.get("party_locked", false): return []
	if int(run.get("party_options_raid", -1)) != int(run.get("raid", -2)): return []
	return run.get("party_options", []).duplicate(true)

func select_party(id: String) -> bool:
	for option in party_choices():
		if option["id"] != id: continue
		if run.get("party_choice", "") == id: return true
		run["party_choice"] = id
		run["party"] = option["party"].duplicate(true)
		_reports.record(run, "party_selected", {"choice": id, "name": option["name"], "party": run["party"].duplicate(true)})
		save_game()
		changed.emit()
		return true
	return false

func selected_party_name() -> String:
	if int(run.get("party_options_raid", -1)) == int(run.get("raid", -2)):
		for option in run.get("party_options", []):
			if option["id"] == run.get("party_choice", ""): return option["name"]
	var raid := int(run.get("raid", 0))
	return Data.ENCOUNTERS[raid]["name"] if raid >= 0 and raid < Data.ENCOUNTERS.size() else "Campaign complete"

func start_raid() -> void:
	if run.get("phase", "") != "prep":
		return
	run.erase("raid_recap")
	run.erase("spell_offer")
	var party := party_preview()
	run["party_locked"] = true
	battle = Combat.new()
	battle.setup(run["monsters"], party, rng, run.get("traits", []), dungeon_spell_loadout())
	run["phase"] = "combat"
	run["promotion"] = ""
	run["evolution_budget"] = 0
	_reports.start_attempt(run, Reports.capture(battle, true))
	_resolve_battle()
	save_game()
	changed.emit()

func play_card(index: int, target: String) -> bool:
	if run.get("phase", "") != "combat" or battle == null:
		return false
	var before := Reports.capture(battle)
	var card: Dictionary = battle.hand[index].duplicate(true) if index >= 0 and index < battle.hand.size() else {}
	var targets: Array = []
	if not card.is_empty():
		var definition: Dictionary = Data.ABILITIES[card["ability"]]
		targets = battle.legal_targets(card) if definition["target"] in ["all_allies", "all_enemies"] else [target if target != "" else card["owner"]]
	var success = battle.play_card(index, target)
	if success:
		_reports.played(run, card, targets, before, Reports.capture(battle), Reports.recent_log(battle))
		_resolve_battle()
		save_game()
		changed.emit()
	return success

func end_turn() -> void:
	if run.get("phase", "") != "combat" or battle == null:
		return
	var before := Reports.capture(battle)
	battle.end_turn()
	_reports.ended_turn(run, before, Reports.capture(battle), Reports.recent_log(battle))
	_resolve_battle()
	save_game()
	changed.emit()

func _resolve_battle() -> void:
	if battle == null or battle.outcome == "active":
		return
	# Resolution is a single persistent transition; wrappers cannot resolve twice.
	if run["phase"] != "combat":
		return
	run["resolved_id"] = int(run["resolved_id"]) + 1
	run["last_result"] = battle.outcome
	_reports.resolved(run, battle)
	if battle.outcome == "won":
		run["raid_recap"] = Recap.capture(battle, int(run["raid"]))
		run["rewards"] = []
		for enemy in battle.enemies:
			run["rewards"].append({"id": enemy["id"], "name": enemy["name"], "class_name": enemy["class_name"], "form": enemy["form"], "armor": Data.armor(enemy), "abilities": enemy["abilities"].duplicate(), "claimed": false})
		run["phase"] = "feeding"
		if int(run.get("loot_version", 0)) == 1:
			var gold_earned: int = 60 if int(run["raid"]) in [2, 5] else 35
			run["gold"] = int(run.get("gold", 0)) + gold_earned
			_reports.count(run, "gold_earned", gold_earned)
			_reports.record(run, "gold_earned", {"raid": int(run["raid"]) + 1, "amount": gold_earned, "gold": run["gold"]})
		if int(run.get("loot_version", 0)) == 1 and int(run["raid"]) + 1 < _campaign_size():
			run["spell_offer"] = Loot.reward(int(run["seed"]), int(run["raid"]), run["spell_library"])
			_reports.record(run, "spell_reward_offered", {"raid": int(run["raid"]) + 1, "offered": run["spell_offer"]["options"].duplicate()})
		if int(run["raid"]) == 0: _open_trait_reward("feeding")
	else:
		run.erase("raid_recap")
		run["rewards"] = []
		run.erase("spell_offer")
		run["phase"] = "defeat"
	_reports.record(run, "phase_changed", {"to": run["phase"]})

func get_monster(id: String) -> Dictionary:
	for monster in run.get("monsters", []):
		if monster["id"] == id:
			return monster
	return {}

func set_selected(monster_id: String, slot: int, ability_id: String) -> bool:
	if run.get("phase", "") not in ["prep", "feeding", "result"] or slot not in [0, 1]:
		return false
	var monster = get_monster(monster_id)
	if monster.is_empty() or ability_id not in monster["learned"]:
		return false
	# Two different choices keep a twelve-card deck with meaningful selections.
	if monster["selected"][1 - slot] == ability_id:
		return false
	var previous: String = monster["selected"][slot]
	monster["selected"][slot] = ability_id
	if previous != ability_id: _reports.record(run, "selection_changed", {"monster": monster_id, "slot": slot, "from": previous, "to": ability_id})
	save_game()
	changed.emit()
	return true

func inheritance_outcomes(body_index: int, monster_id: String) -> Array:
	if run.get("phase", "") != "feeding" or body_index < 0 or body_index >= run["rewards"].size():
		return []
	var body = run["rewards"][body_index]
	var monster = get_monster(monster_id)
	if monster.is_empty() or body.get("claimed", false):
		return []
	return Data.inheritance_outcomes(body.get("abilities", []), monster.get("learned", []))

func claim_body(body_index: int, monster_id: String) -> bool:
	var outcomes: Array = inheritance_outcomes(body_index, monster_id)
	if outcomes.is_empty():
		return false
	var total_weight: int = 0
	for outcome in outcomes: total_weight += int(outcome["weight"])
	# Only a valid consumption advances RNG, exactly once, before it is saved.
	var roll: int = rng.randi_range(1, total_weight)
	var ability_id: String = outcomes.back()["ability"]
	for outcome in outcomes:
		roll -= int(outcome["weight"])
		if roll <= 0:
			ability_id = outcome["ability"]
			break
	var body = run["rewards"][body_index]
	var monster = get_monster(monster_id)
	body["claimed"] = true
	body["recipient"] = monster_id
	body["taken"] = ability_id
	run["last_meal"] = {"body": body_index, "recipient": monster_id, "ability": ability_id}
	monster["learned"].append(ability_id)
	monster["consumed"].append(ability_id)
	monster["feeds"] = int(monster["feeds"]) + 1
	run["evolution_budget"] = 1
	last_evolution = {}
	_reports.count(run, "bodies_claimed")
	_reports.record(run, "body_claimed", {"body": body.duplicate(true), "recipient": monster_id, "outcomes": outcomes, "taken": ability_id})
	save_game()
	changed.emit()
	return true

func skip_body(index: int) -> bool:
	if run.get("phase", "") != "feeding" or index < 0 or index >= run["rewards"].size() or run["rewards"][index]["claimed"]:
		return false
	run["rewards"][index]["claimed"] = true
	run["rewards"][index]["skipped"] = true
	_reports.count(run, "bodies_skipped")
	_reports.record(run, "body_skipped", {"body": run["rewards"][index].duplicate(true)})
	save_game()
	changed.emit()
	return true

func eligible(monster_id: String) -> Array:
	var monster = get_monster(monster_id)
	return [] if monster.is_empty() else Data.eligible(monster)

func evolve(monster_id: String, recipe_id: String) -> bool:
	if run.get("phase", "") not in ["prep", "feeding", "result"]:
		return false
	if run["phase"] == "feeding" and int(run.get("evolution_budget", 0)) < 1:
		return false
	var monster = get_monster(monster_id)
	for recipe in eligible(monster_id):
		if recipe["id"] != recipe_id:
			continue
		var old_form = monster["form"]
		var next_form = recipe["result"]
		var health_ratio = float(monster["hp"]) / float(monster["max_hp"])
		monster["form"] = next_form
		monster["max_hp"] = int(Data.FORMS[next_form]["max_hp"])
		monster["hp"] = clampi(roundi(health_ratio * monster["max_hp"]), 0, monster["max_hp"])
		# A living creature keeps at least one HP when rounding a tiny percentage.
		if health_ratio > 0.0:
			monster["hp"] = maxi(1, int(monster["hp"]))
		run["evolution_budget"] = 0
		last_evolution = {"monster_id": monster_id, "from": old_form, "to": next_form, "recipe": recipe.duplicate(true)}
		profile["discoveries"][next_form] = {"form": next_form, "source": old_form, "recipe": recipe.duplicate(true), "first_seed": run["seed"]}
		_reports.count(run, "evolutions")
		_reports.record(run, "evolved", last_evolution)
		save_game()
		changed.emit()
		return true
	return false

func _recover() -> void:
	if int(run["recovered_id"]) == int(run["resolved_id"]):
		return
	var before := Reports.roster(run["monsters"])
	for monster in run["monsters"]:
		var amount = ceili(float(monster["max_hp"]) * float(Data.BALANCE["recovery"]))
		monster["hp"] = mini(int(monster["max_hp"]), int(monster["hp"]) + amount)
		monster["block"] = 0
		monster["statuses"] = {}
		monster["status_layers"] = {}
	run["recovered_id"] = run["resolved_id"]
	_reports.count(run, "recoveries")
	_reports.record(run, "recovered", {"resolved_id": run["resolved_id"], "before": before, "after": Reports.roster(run["monsters"])})

func finish_feeding() -> bool:
	if run.get("phase", "") != "feeding":
		return false
	if run.get("spell_offer") is Dictionary and not run["spell_offer"].get("resolved", false): return false
	for body in run["rewards"]:
		if not body["claimed"]:
			return false
	_recover()
	var previous_rank = rank_name()
	run["raid"] = int(run["raid"]) + 1
	run.erase("party")
	run.erase("last_meal")
	for key in ["party_options", "party_options_raid", "party_choice", "party_locked"]: run.erase(key)
	run["evolution_budget"] = 0
	if rank_name() != previous_rank:
		run["promotion"] = rank_name()
	run["phase"] = "victory" if int(run["raid"]) >= _campaign_size() else "result"
	if int(run.get("loot_version", 0)) == 1 and Loot.TRADER_RAIDS.has(int(run["raid"])) and int(run.get("trader_raid", -1)) != int(run["raid"]):
		run["trader_raid"] = int(run["raid"])
		run["trader_stock"] = Loot.stock(int(run["seed"]), run["spell_library"], int(run["raid"]))
	if run["phase"] == "result": _open_trait_reward("result")
	_reports.record(run, "feeding_finished", {"promotion": run["promotion"]})
	save_game()
	changed.emit()
	return true

func continue_after_result() -> void:
	if run.get("phase", "") != "result":
		return
	if _open_trait_reward("result"):
		save_game()
		changed.emit()
		return
	if int(run.get("loot_version", 0)) == 1 and Loot.TRADER_RAIDS.has(int(run["raid"])) and not run.get("trader_visited_raids", []).has(int(run["raid"])):
		run["phase"] = "trader"
		_reports.record(run, "trader_opened", {"raid": int(run["raid"]) + 1, "gold": run.get("gold", 0), "stock": trader_stock()})
		save_game()
		changed.emit()
		return
	run["phase"] = "prep"
	battle = null
	run["rewards"] = []
	party_preview()
	_reports.record(run, "preparation_entered")
	save_game()
	changed.emit()

func dungeon_spell_loadout() -> Array:
	return run.get("dungeon_spells", Loot.STARTERS).duplicate()

func spell_reward_choices() -> Array:
	if run.get("phase", "") != "feeding" or not run.get("spell_offer") is Dictionary: return []
	var offer: Dictionary = run["spell_offer"]
	if offer.get("resolved", false): return []
	return offer.get("options", []).duplicate()

func _spell_slot_valid(slot: int, ability: String) -> bool:
	if slot < 0 or slot > 2 or not Loot.valid_spell(ability): return false
	var spells: Array = dungeon_spell_loadout()
	if spells.size() != 3: return false
	for index in range(spells.size()):
		if index != slot and spells[index] == ability: return false
	return true

func choose_spell_reward(id: String, slot: int) -> bool:
	if not spell_reward_choices().has(id) or run.get("spell_library", Loot.STARTERS).has(id) or not _spell_slot_valid(slot, id): return false
	var offer: Dictionary = run["spell_offer"]
	var previous: String = run["dungeon_spells"][slot]
	run["spell_library"].append(id)
	run["dungeon_spells"][slot] = id
	offer["resolved"] = true
	offer["chosen"] = id
	offer["slot"] = slot
	run["spell_history"].append({"raid": offer["raid"], "ability": id, "slot": slot})
	_reports.count(run, "spells_chosen")
	_reports.record(run, "spell_reward_chosen", {"raid": offer["raid"], "offered": offer["options"].duplicate(), "ability": id, "slot": slot, "replaced": previous})
	save_game()
	changed.emit()
	return true

func skip_spell_reward() -> bool:
	if spell_reward_choices().is_empty(): return false
	run["spell_offer"]["resolved"] = true
	run["spell_offer"]["skipped"] = true
	_reports.count(run, "spells_skipped")
	_reports.record(run, "spell_reward_skipped", {"raid": run["spell_offer"]["raid"], "offered": run["spell_offer"]["options"].duplicate()})
	save_game()
	changed.emit()
	return true

func select_dungeon_spell(slot: int, id: String) -> bool:
	if run.get("phase", "") not in ["prep", "feeding", "result", "trader"] or not run.get("spell_library", Loot.STARTERS).has(id) or not _spell_slot_valid(slot, id): return false
	if run["dungeon_spells"][slot] == id: return true
	var previous: String = run["dungeon_spells"][slot]
	run["dungeon_spells"][slot] = id
	_reports.record(run, "dungeon_spell_selected", {"ability": id, "slot": slot, "replaced": previous})
	save_game()
	changed.emit()
	return true

func trader_stock() -> Array:
	if run.get("phase", "") not in ["result", "trader"] or int(run.get("loot_version", 0)) != 1: return []
	return run.get("trader_stock", []).duplicate(true)

func buy_spell(stock_id: String, slot: int) -> bool:
	if run.get("phase", "") != "trader" or int(run.get("loot_version", 0)) != 1: return false
	for row in run.get("trader_stock", []):
		if row["id"] != stock_id: continue
		var ability: String = row["ability"]
		if row.get("sold", false) or row.get("owned", false) or run["spell_library"].has(ability) or int(run.get("gold", 0)) < int(row["price"]) or not _spell_slot_valid(slot, ability): return false
		var previous: String = run["dungeon_spells"][slot]
		run["gold"] = int(run["gold"]) - int(row["price"])
		row["sold"] = true
		run["spell_library"].append(ability)
		run["dungeon_spells"][slot] = ability
		_reports.count(run, "spells_purchased")
		_reports.count(run, "gold_spent", int(row["price"]))
		_reports.record(run, "spell_purchased", {"raid": int(run["raid"]) + 1, "stock_id": stock_id, "ability": ability, "price": row["price"], "gold": run["gold"], "slot": slot, "replaced": previous})
		save_game()
		changed.emit()
		return true
	return false

func leave_trader() -> bool:
	if run.get("phase", "") != "trader" or int(run.get("loot_version", 0)) != 1: return false
	run["trader_visited_raids"].append(int(run["raid"]))
	run["phase"] = "prep"
	battle = null
	run["rewards"] = []
	party_preview()
	_reports.record(run, "trader_left", {"raid": int(run["raid"]) + 1, "gold": run["gold"]})
	_reports.record(run, "preparation_entered")
	save_game()
	changed.emit()
	return true

func _pending_trait_milestone() -> int:
	if int(run.get("raid", 0)) >= _campaign_size(): return -1
	var earned_raids: int = int(run.get("raid", 0))
	var first_win_waiting: bool = earned_raids == 0 and run.get("last_result", "") == "won" and int(run.get("resolved_id", 0)) > int(run.get("recovered_id", 0))
	var before_first_feeding: bool = run.get("phase", "") == "feeding" or (run.get("phase", "") == "trait" and run.get("trait_return", "") == "feeding")
	# Only the first won raid offers its trait before meals/recovery. Champion
	# rewards retain the existing post-feeding completed-raid boundary.
	if first_win_waiting and before_first_feeding: earned_raids = 1
	for milestone in Traits.MILESTONES:
		if earned_raids >= milestone and not run.get("trait_milestones", []).has(milestone):
			return milestone
	return -1

func _open_trait_reward(return_phase: String) -> bool:
	if _pending_trait_milestone() < 0 or Traits.choices(run.get("traits", [])).is_empty(): return false
	_ensure_first_trait_offer()
	run["trait_return"] = return_phase
	run["phase"] = "trait"
	return true

func _ensure_first_trait_offer() -> void:
	if _pending_trait_milestone() != int(Traits.MILESTONES[0]): return
	var available: Array = Traits.choices(run.get("traits", []))
	var offered = run.get("first_trait_offer")
	if offered is Array and offered.size() == mini(2, available.size()):
		var unique: Array = []
		for id in offered:
			if available.has(id) and not unique.has(id): unique.append(id)
		if unique.size() == offered.size(): return
	# Keep after selection for saved history. Only new or missing/invalid pending
	# offers are generated; a normal first reward has all four traits available.
	run["first_trait_offer"] = Traits.first_offer(int(run["seed"]), run.get("traits", []))

func trait_choices() -> Array:
	if run.get("phase", "") != "trait" or _pending_trait_milestone() < 0: return []
	if _pending_trait_milestone() == int(Traits.MILESTONES[0]): return run.get("first_trait_offer", []).duplicate()
	return Traits.choices(run.get("traits", []))

func choose_trait(id: String) -> bool:
	var offered: Array = trait_choices()
	if not offered.has(id): return false
	var milestone := _pending_trait_milestone()
	run["traits"].append(id)
	run["trait_milestones"].append(milestone)
	var return_phase: String = run.get("trait_return", "result")
	run["phase"] = return_phase
	run.erase("trait_return")
	_open_trait_reward(return_phase)
	_reports.count(run, "traits_chosen")
	_reports.record(run, "trait_chosen", {"trait": id, "milestone": milestone, "offered": offered})
	save_game()
	changed.emit()
	return true

func rank_name() -> String:
	var raid = int(run.get("raid", 0))
	for rank_id in Data.RANKS:
		var definition = Data.RANKS[rank_id]
		if not definition["playable"] or raid < int(definition["raids"]):
			return rank_id
		raid -= int(definition["raids"])
	return "S"

func _campaign_size() -> int:
	var count = 0
	for definition in Data.RANKS.values():
		if definition["playable"]:
			count += int(definition["raids"])
	return count

func raid_name() -> String:
	var raid = int(run.get("raid", 0))
	if raid >= _campaign_size():
		return "Campaign complete"
	var rank_id = rank_name()
	for earlier in Data.RANKS:
		if earlier == rank_id:
			break
		raid -= int(Data.RANKS[earlier]["raids"])
	var total = int(Data.RANKS[rank_id]["raids"])
	return "%s rank · %s" % [rank_id, "Champion raid" if raid == total - 1 else "Raid %d of %d" % [raid + 1, total]]

func discoveries() -> Array:
	var entries: Array = []
	for key in profile["discoveries"]:
		entries.append(profile["discoveries"][key])
	return entries

func status_text() -> String:
	if run.is_empty():
		return "A dungeon waiting to awaken."
	return "%s  ·  Seed %d" % [raid_name(), run["seed"]]

func debug_reset_profile() -> void:
	# Explicit test/debug API, never exposed in normal gameplay.
	profile = {"discoveries": {}}
	_write_json(_prefix + "grimoire.json", profile)
