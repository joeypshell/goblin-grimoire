extends RefCounted

const Data = preload("res://scripts/game_data.gd")

# Only intent generation calls these helpers. Skill schedules do not consume RNG;
# random targets are rolled once by Battle and then remain locked for the turn.
static func choose_ability(battle, enemy: Dictionary, choices: Array) -> String:
	var available: Array = []
	for id in choices:
		if Data.ABILITIES.has(id) and enemy.get("abilities", []).has(id) and not available.has(id):
			available.append(id)
	if available.is_empty(): return ""
	var round_number: int = maxi(1, int(battle.turn))
	var cycle: int = (round_number - 1) % 3
	if enemy.get("encounter_rule", "") == "ritual_priest":
		var ritual_ready: bool = false
		for ally in battle.enemies:
			if ally.get("id", "") != enemy.get("id", "") and int(ally.get("hp", 0)) > 0 and int(ally["hp"]) < int(ally["max_hp"]):
				ritual_ready = true
				break
		if round_number % 3 == 2 and ritual_ready and available.has("renewal_ritual"):
			return "renewal_ritual"
		available.erase("renewal_ritual")
		if available.is_empty(): return ""
	var priorities: Array = []
	match enemy.get("class_name", enemy.get("form", "")):
		"warrior":
			if cycle == 2 and available.has("shatter_guard"):
				priorities = ["shatter_guard"]
			else:
				priorities = ["heavy_blow", "strike"] if round_number % 2 == 1 else ["strike", "heavy_blow"]
		"defender":
			match cycle:
				0: priorities = ["shield_bash", "heavy_blow", "shatter_guard"]
				1: priorities = ["shield_wall", "shield_bash", "heavy_blow"]
				2: priorities = ["shatter_guard", "heavy_blow", "shield_bash"]
		"mage":
			if cycle == 2 and available.has("ember_burst"):
				priorities = ["ember_burst"]
			else:
				priorities = ["firebolt", "arcane_bolt"] if round_number % 2 == 1 else ["arcane_bolt", "firebolt"]
		"rogue":
			if cycle == 2: priorities = ["smoke_step", "poisoned_blade", "quick_jab", "strike"]
			elif cycle == 1: priorities = ["quick_jab", "poisoned_blade", "strike"]
			else: priorities = ["poisoned_blade", "quick_jab", "strike"]
		"controller":
			if cycle == 2 and not available.has("arcane_bolt"):
				priorities = ["smoke_step", "snare"]
			else:
				priorities = ["snare", "arcane_bolt"] if round_number % 2 == 1 else ["arcane_bolt", "snare"]
		"priest":
			var wounded: bool = false
			for ally in battle.enemies:
				if int(ally.get("hp", 0)) > 0 and int(ally["hp"]) < int(ally["max_hp"]):
					wounded = true
					break
			if cycle == 2 and wounded:
				priorities = ["mend", "regrowth", "arcane_bolt"] if round_number % 6 == 3 else ["regrowth", "mend", "arcane_bolt"]
			else:
				priorities = ["arcane_bolt"]
	for id in priorities:
		if available.has(id): return id
	# An incomplete generated kit still prefers pressure over idle defense.
	for id in available:
		if Data.ABILITIES[id]["target"] in ["enemy", "all_enemies"]: return id
	return str(available[0])

static func choose_target(battle, enemy: Dictionary, ability: Dictionary, candidates: Array) -> Dictionary:
	if candidates.is_empty(): return {}
	if enemy.get("encounter_rule", "") == "ritual_priest" and ability == Data.ABILITIES.get("renewal_ritual", {}):
		var ritual_allies: Array = candidates.filter(func(actor): return actor.get("id", "") != enemy.get("id", "") and int(actor.get("hp", 0)) > 0 and int(actor["hp"]) < int(actor["max_hp"]))
		if ritual_allies.is_empty(): return {}
		candidates = ritual_allies
	var target: Dictionary = candidates[0]
	if ability["target"] == "enemy":
		var actor_class: String = enemy.get("class_name", enemy.get("form", ""))
		if actor_class in ["rogue", "warrior"]:
			for candidate in candidates:
				if (actor_class == "rogue" and int(candidate["hp"]) < int(target["hp"])) or (actor_class == "warrior" and int(candidate["hp"]) > int(target["hp"])):
					target = candidate
			return target
		return candidates[battle.rng.randi_range(0, candidates.size() - 1)]
	if ability["target"] == "ally":
		for candidate in candidates:
			if float(candidate["hp"]) / maxf(1.0, float(candidate["max_hp"])) < float(target["hp"]) / maxf(1.0, float(target["max_hp"])):
				target = candidate
	return target

static func description(enemy: Dictionary) -> String:
	if not enemy.get("tactics", false): return ""
	var owned: Array = enemy.get("abilities", [])
	var suffix: String = ""
	if enemy.get("champion", "") == "cinder_banner":
		suffix = " Banner Volley replaces the normal action every third round."
	elif enemy.get("champion", "") == "iron_marshal":
		suffix = " Breach Order replaces the normal action on rounds 2, 5, 8…; it removes monster Block and hits the whole pack."
	match enemy.get("class_name", enemy.get("form", "")):
		"warrior":
			return "TACTIC / Alternates Heavy Blow and Strike; aims at the monster with the most HP." + (" Uses Shatter Guard every third round." if owned.has("shatter_guard") else "") + suffix
		"defender":
			var first: String = "Shield Bash" if owned.has("shield_bash") else "Heavy Blow"
			var last: String = "Shatter Guard" if owned.has("shatter_guard") else "Heavy Blow"
			return "TACTIC / Repeats %s → Shield Wall → %s. Single attacks choose a living monster." % [first, last] + suffix
		"mage":
			return "TACTIC / Alternates Firebolt and Arcane Bolt; single attacks choose a living monster." + (" Ember Burst hits the whole pack every third round." if owned.has("ember_burst") else "") + suffix
		"rogue":
			var attack: String = "Poisoned Blade" if owned.has("poisoned_blade") else ("Quick Jab" if owned.has("quick_jab") else "Strike")
			return "TACTIC / Aims %s at the monster with the least HP." % attack + (" Uses Quick Jab on each second round in its cycle." if owned.has("quick_jab") else "") + (" Uses Smoke Step every third round." if owned.has("smoke_step") else " Keeps attacking each round.") + suffix
		"controller":
			return "TACTIC / Alternates Snare and Arcane Bolt; chooses a living monster." + suffix if owned.has("arcane_bolt") else "TACTIC / Uses Snare against a living monster." + (" Uses Smoke Step every third round." if owned.has("smoke_step") else "") + suffix
		"priest":
			return "TACTIC / Uses Arcane Bolt; every third round heals a wounded ally instead. Single attacks choose a living monster." + suffix
	return "" + suffix
