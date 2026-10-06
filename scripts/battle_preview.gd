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
	if ability["target"] in ["enemy", "ally"] and not battle.legal_targets(card).has(target_id):
		return "Choose a living legal target."
	var targets: Array = battle._targets(ability["target"], owner, target_id)
	if targets.is_empty():
		return "Choose a living legal target."
	var lines: Array = []
	for actor in targets:
		var parts: Array = []
		var simulated: Dictionary = actor.duplicate(true)
		for effect in ability["effects"]:
			if int(simulated["hp"]) <= 0: break
			if effect.get("to", "target") == "self" and actor != owner:
				continue
			var amount: int = battle._amount(effect, ability, owner, actor)
			match effect["kind"]:
				"break_block":
					parts.append("remove %d Block" % int(simulated.get("block", 0)))
					simulated["block"] = 0
				"damage":
					var prevented: Dictionary = battle.damage_breakdown(simulated, amount)
					if int(simulated.get("statuses", {}).get("evasion", 0)) > 0:
						parts.append("evades %d damage" % amount)
						simulated["statuses"]["evasion"] = int(simulated["statuses"]["evasion"]) - 1
					else:
						parts.append("%d damage (%d HP, %d armor, %d blocked)" % [amount, prevented["hp"], prevented["armor"], prevented["block"]])
						simulated["block"] = int(simulated.get("block", 0)) - int(prevented["block"])
						simulated["hp"] = int(simulated["hp"]) - int(prevented["hp"])
						if battle.traits.has("venom_nest") and int(prevented["hp"]) >= int(actor["hp"]) and int(actor.get("statuses", {}).get("poison", 0)) > 0:
							parts.append("poisoned KO spreads 2 Poison to other living invaders")
				"block": parts.append("+%d block" % amount)
				"heal": parts.append("heal %d HP" % mini(amount, int(actor["max_hp"]) - int(actor["hp"])))
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
		lines.append("%s: %s" % [actor["name"], ", ".join(parts)])
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
	var trait_hint: String = Traits.card_preview(battle, card, Forms.prepare(battle, card, target_id))
	if trait_hint != "": lines.append(trait_hint)
	var encounter_hint: String = EncounterRules.card_preview(battle, card, target_id)
	if encounter_hint != "": lines.append(encounter_hint)
	return "\n".join(lines)
