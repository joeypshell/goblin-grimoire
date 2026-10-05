class_name RunState
extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/battle.gd")
const SAVE_VERSION = 1

signal changed

var run: Dictionary = {}
var profile: Dictionary = {"discoveries": {}}
var rng = RandomNumberGenerator.new()
var battle: Battle
var last_evolution: Dictionary = {}
var _prefix: String

func _init(save_prefix: String = "user://") -> void:
	_prefix = save_prefix.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_prefix)
	_load_profile()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return _restore_numbers(parsed) if parsed is Dictionary else {}

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
	return saved.get("version", 0) == SAVE_VERSION and saved.get("monsters") is Array and saved.get("phase", "") in ["prep", "combat", "feeding", "result", "victory", "defeat"]

func save_game() -> void:
	if run.is_empty():
		return
	run["version"] = SAVE_VERSION
	run["rng_state"] = str(rng.state)
	if battle != null and run["phase"] == "combat":
		run["battle"] = battle.to_dict()
	else:
		run.erase("battle")
	_write_json(_prefix + "grimoire.json", profile)
	_write_json(_prefix + "run.json", run)

func load_game() -> bool:
	if not has_save():
		return false
	_load_profile()
	run = _read_json(_prefix + "run.json")
	Data.ensure_priest_offense(run.get("party", []))
	if run.get("battle") is Dictionary:
		Data.ensure_priest_offense(run["battle"].get("enemies", []))
	rng.seed = int(run["seed"])
	rng.state = int(run["rng_state"])
	battle = null
	last_evolution = {}
	if run["phase"] == "combat":
		if not run.get("battle") is Dictionary:
			return false
		battle = Combat.new()
		battle.restore(run["battle"], run["monsters"], rng)
	changed.emit()
	return true

func new_run(seed_value: int = 0) -> void:
	_load_profile()
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	rng.seed = seed_value
	run = {
		"seed": seed_value, "monsters": [Data.new_monster("m1", "Grub"), Data.new_monster("m2", "Nix"), Data.new_monster("m3", "Moss")],
		"core": int(Data.BALANCE["core"]), "raid": 0, "phase": "prep", "rewards": [],
		"resolved_id": 0, "recovered_id": 0, "last_result": "", "promotion": "", "evolution_budget": 0,
	}
	battle = null
	last_evolution = {}
	party_preview()
	save_game()
	changed.emit()

func party_preview() -> Array:
	if run.is_empty() or int(run["raid"]) >= _campaign_size():
		return []
	if not run.has("party"):
		run["party"] = Data.generate_party(int(run["raid"]), rng)
		save_game()
	return run["party"]

func start_raid() -> void:
	if run.get("phase", "") != "prep":
		return
	battle = Combat.new()
	battle.setup(run["monsters"], party_preview(), rng)
	run["phase"] = "combat"
	run["promotion"] = ""
	run["evolution_budget"] = 0
	_resolve_battle()
	save_game()
	changed.emit()

func play_card(index: int, target: String) -> bool:
	if run.get("phase", "") != "combat" or battle == null:
		return false
	var success = battle.play_card(index, target)
	if success:
		_resolve_battle()
		save_game()
		changed.emit()
	return success

func end_turn() -> void:
	if run.get("phase", "") != "combat" or battle == null:
		return
	battle.end_turn()
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
	if battle.outcome == "won":
		run["rewards"] = []
		for enemy in battle.enemies:
			run["rewards"].append({"id": enemy["id"], "name": enemy["name"], "class_name": enemy["class_name"], "form": enemy["form"], "armor": Data.armor(enemy), "abilities": enemy["abilities"].duplicate(), "claimed": false})
		run["phase"] = "feeding"
	else:
		run["core"] = maxi(0, int(run["core"]) - int(Data.BALANCE["breach"]))
		run["rewards"] = []
		_recover()
		run["phase"] = "defeat" if int(run["core"]) == 0 else "result"

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
	monster["selected"][slot] = ability_id
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
	monster["learned"].append(ability_id)
	monster["consumed"].append(ability_id)
	monster["feeds"] = int(monster["feeds"]) + 1
	run["evolution_budget"] = 1
	last_evolution = {}
	save_game()
	changed.emit()
	return true

func skip_body(index: int) -> bool:
	if run.get("phase", "") != "feeding" or index < 0 or index >= run["rewards"].size() or run["rewards"][index]["claimed"]:
		return false
	run["rewards"][index]["claimed"] = true
	run["rewards"][index]["skipped"] = true
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
		save_game()
		changed.emit()
		return true
	return false

func _recover() -> void:
	if int(run["recovered_id"]) == int(run["resolved_id"]):
		return
	for monster in run["monsters"]:
		var amount = ceili(float(monster["max_hp"]) * float(Data.BALANCE["recovery"]))
		monster["hp"] = mini(int(monster["max_hp"]), int(monster["hp"]) + amount)
		monster["block"] = 0
		monster["statuses"] = {}
		monster["status_layers"] = {}
	run["recovered_id"] = run["resolved_id"]

func finish_feeding() -> bool:
	if run.get("phase", "") != "feeding":
		return false
	for body in run["rewards"]:
		if not body["claimed"]:
			return false
	_recover()
	var previous_rank = rank_name()
	run["raid"] = int(run["raid"]) + 1
	run.erase("party")
	run["evolution_budget"] = 0
	if rank_name() != previous_rank:
		run["promotion"] = rank_name()
	run["phase"] = "victory" if int(run["raid"]) >= _campaign_size() else "result"
	save_game()
	changed.emit()
	return true

func continue_after_result() -> void:
	if run.get("phase", "") != "result":
		return
	run["phase"] = "prep"
	battle = null
	run["rewards"] = []
	party_preview()
	save_game()
	changed.emit()

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
	return "%s  ·  Core %d/%d  ·  Seed %d" % [raid_name(), run["core"], Data.BALANCE["core"], run["seed"]]

func debug_reset_profile() -> void:
	# Explicit test/debug API, never exposed in normal gameplay.
	profile = {"discoveries": {}}
	_write_json(_prefix + "grimoire.json", profile)
