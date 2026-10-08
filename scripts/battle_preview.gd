extends RefCounted

# Read-only combat descriptions; no effect resolution or RNG.
const Data = preload("res://scripts/game_data.gd")
const Forms = preload("res://scripts/battle_forms.gd")
const Traits = preload("res://scripts/battle_traits.gd")
const EncounterRules = preload("res://scripts/encounter_rules.gd")

static func describe(battle, card: Dictionary, target_id: String) -> String:
	if not Data.ABILITIES.has(card.get("ability", "")):
		return "Unknown card."
	var owner: Dictionary = battle.get_actor(card.get("owner", ""))
	if not owner.is_empty() and int(owner.get("statuses", {}).get("stun", 0)) > 0:
		return "%s is stunned this turn. Owned cards cannot be played; dungeon cards remain available." % owner["name"]
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var legal: Array = battle.legal_targets(card)
	if legal.is_empty() or (ability["target"] in ["enemy", "ally"] and not legal.has(target_id)):
		if card["ability"] == "echo_rune" and battle.dungeon_state.get("echo_ready", false): return "Echo already armed. Play an owned attack to spend it."
		if card["ability"] == "echo_rune" and not battle.has_owned_attack(): return "No living monster-owned attack remains in this deck."
		if card["ability"] == "plague_bloom": return "Choose a poisoned foe with another living foe to receive the spread."
		if card["ability"] == "renewal_wave" and legal.is_empty(): return "No missing HP or Poison/Burn to cleanse."
		return "Choose a living legal target."
	var targets: Array = battle._targets(ability["target"], owner, target_id)
	if targets.is_empty():
		return "Choose a living legal target."
	var lines: Array = []
	var direct_kills: Array = []
	var before: Dictionary = Forms.prepare(battle, card, target_id)
	before["healed"] = 0
	before["damaged"] = []
	var echo: bool = not owner.is_empty() and battle._is_monster(owner["id"]) and battle.dungeon_state.get("echo_ready", false) and battle._is_attack(ability)
	for actor in targets:
		var parts: Array = []
		var simulated: Dictionary = actor.duplicate(true)
		for effect in ability["effects"]:
			if int(simulated["hp"]) <= 0: break
			if effect.get("to", "target") == "self" and actor != owner:
				continue
			var amount: int = battle._amount(effect, ability, owner, simulated)
			match effect["kind"]:
				"break_block":
					parts.append("remove %d Block" % int(simulated.get("block", 0)))
					simulated["block"] = 0
				"damage":
					for hit in range(2 if echo else 1):
						if int(simulated["hp"]) <= 0: break
						amount = battle._amount(effect, ability, owner, simulated)
						var prevented: Dictionary = battle.damage_breakdown(simulated, amount)
						var prefix: String = "Echo: " if hit == 1 else ""
						if int(simulated.get("statuses", {}).get("evasion", 0)) > 0:
							parts.append(prefix + "evades %d damage" % amount)
							simulated["statuses"]["evasion"] = int(simulated["statuses"]["evasion"]) - 1
						else:
							parts.append(prefix + "%d damage (%d HP, %d armor, %d blocked)" % [amount, prevented["hp"], prevented["armor"], prevented["block"]])
							simulated["block"] = int(simulated.get("block", 0)) - int(prevented["block"])
							simulated["hp"] = int(simulated["hp"]) - int(prevented["hp"])
						if not owner.is_empty() and battle._is_monster(owner["id"]) and int(simulated.get("statuses", {}).get("marked", 0)) > 0:
							simulated["statuses"].erase("marked")
							parts.append("Hunter's Mark spent")
						if int(simulated["hp"]) <= 0 and not direct_kills.has(actor["id"]):
							direct_kills.append(actor["id"])
							if battle.traits.has("venom_nest") and int(actor.get("statuses", {}).get("poison", 0)) > 0: parts.append("poisoned KO spreads 2 Poison to other living invaders")
				"block": parts.append("+%d block" % amount)
				"heal":
					var healed: int = mini(amount, maxi(0, int(simulated["max_hp"]) - int(simulated["hp"])))
					simulated["hp"] = int(simulated["hp"]) + healed
					if battle._is_monster(actor["id"]): before["healed"] += healed
					parts.append("heal %d HP" % healed)
				"status":
					var status_id: String = effect["status"]
					if status_id == "stun" and int(actor.get("statuses", {}).get("resolve", 0)) > 0:
						parts.append("Resolve blocks stun")
					elif status_id == "stun" and int(actor.get("statuses", {}).get("stun", 0)) > 0:
						parts.append("already stunned; stun does not stack")
					else:
						parts.append("+%d %s%s" % [amount, battle._status_name(status_id), " (decays independently)" if status_id in battle.LAYERED_STATUSES else ""])
				"cleanse":
					var removed: Array = []
					for status_id in effect.get("statuses", []):
						if int(actor.get("statuses", {}).get(status_id, 0)) > 0: removed.append(battle._status_name(status_id))
					parts.append("cleanse " + ", ".join(removed) if not removed.is_empty() else "nothing to cleanse")
		if ability["target"] == "all_enemies" and int(simulated["hp"]) > 0 and int(simulated["hp"]) < int(actor["hp"]): before["damaged"].append(actor["id"])
		if not parts.is_empty(): lines.append("%s: %s" % [actor["name"], ", ".join(parts)])
	for effect in ability["effects"]:
		match effect["kind"]:
			"draw": lines.append("Dungeon: draw up to %d cards once." % int(effect["amount"]))
			"echo": lines.append("Dungeon: arm Echo. Next owned attack repeats direct hits once; status riders and tactics happen once.")
			"poison_spread":
				var source: Dictionary = battle.get_actor(target_id)
				var names: Array = []
				for foe in battle.enemies:
					if foe["id"] != target_id and int(foe["hp"]) > 0: names.append(foe["name"])
				lines.append("%s keeps its Poison; add %d fresh Poison to %s." % [source.get("name", "Source"), int(source.get("statuses", {}).get("poison", 0)), ", ".join(names)])
			"heal_on_kill":
				var simulated_roster: Array = battle.monsters.duplicate(true)
				for _kill in direct_kills:
					var recipient: Dictionary = {}
					for monster in simulated_roster:
						if int(monster["hp"]) > 0 and int(monster["hp"]) < int(monster["max_hp"]) and (recipient.is_empty() or float(monster["hp"]) / float(monster["max_hp"]) < float(recipient["hp"]) / float(recipient["max_hp"])): recipient = monster
					if not recipient.is_empty():
						var healed: int = mini(int(effect["amount"]), int(recipient["max_hp"]) - int(recipient["hp"]))
						recipient["hp"] = int(recipient["hp"]) + healed
						before["healed"] += healed
						lines.append("Soul Harvest: %s heals %d HP from a direct kill." % [recipient["name"], healed])
	if echo: lines.append("Echo charge spent; status riders and monster tactics happen once.")
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self" and not owner.is_empty() and not targets.has(owner):
			lines.append("%s: +%d %s" % [owner["name"], battle._amount(effect, ability, owner, owner), battle._status_name(effect.get("status", "block"))])
	if not owner.is_empty() and owner.get("form", "") == "red_ogre":
		for effect in ability["effects"]:
			if effect["kind"] == "damage":
				lines.append("Kindling adds 1 burning to each victim.")
				break
	if not owner.is_empty() and owner.get("form", "") == "ember_basilisk":
		for effect in ability["effects"]:
			if effect.get("status", "") == "poison":
				lines.append("Volatile venom adds 2 burning to each victim.")
				break
	if battle.traits.has("pack_instinct") and not owner.is_empty() and not battle.trait_state.get("pack_triggered", false):
		var owners: Array = battle.trait_state.get("owners", [])
		if owners.size() == 2 and not owners.has(owner["id"]):
			lines.append("Pack Instinct: this third monster grants 1 energy and draws 1 card.")
	var form_hint: String = Forms.preview(battle, card, target_id)
	if form_hint != "": lines.append(form_hint)
	var trait_hint: String = Traits.card_preview(battle, card, before)
	if trait_hint != "": lines.append(trait_hint)
	var encounter_hint: String = EncounterRules.card_preview(battle, card, target_id)
	if encounter_hint != "": lines.append(encounter_hint)
	return "\n".join(lines)
