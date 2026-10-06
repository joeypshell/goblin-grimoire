extends RefCounted

const Data = preload("res://scripts/game_data.gd")

# Each transformation changes the order and targets of its owner's ordinary cards.
# State is per turn, included in snapshots, and never advanced by a preview.
static func begin_turn(battle) -> void:
	battle.form_state.clear()
	for owner in battle.monsters:
		battle.form_state[owner["id"]] = {"ready": false, "used": false}

static func _state(battle, owner: Dictionary) -> Dictionary:
	return battle.form_state.get(owner.get("id", ""), {"ready": false, "used": false})

static func _has(ability: Dictionary, kind: String, status_id: String = "") -> bool:
	for effect in ability["effects"]:
		if effect["kind"] == kind and (status_id == "" or effect.get("status", "") == status_id): return true
	return false

static func _afflicted(actor: Dictionary) -> bool:
	for id in ["poison", "burn", "stun"]:
		if int(actor.get("statuses", {}).get(id, 0)) > 0: return true
	return false

static func prepare(battle, card: Dictionary, target_id: String) -> Dictionary:
	var owner: Dictionary = battle.get_actor(card.get("owner", ""))
	if owner.is_empty() or not battle._is_monster(owner["id"]) or int(owner["hp"]) <= 0: return {}
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var targets: Array = battle._targets(ability["target"], owner, target_id)
	var result: Dictionary = {"attack": _has(ability, "damage"), "protect": false, "burned": "", "afflicted": false, "poisoned": []}
	for actor in targets:
		if _has(ability, "block") and actor["id"] != owner["id"] and battle._is_monster(actor["id"]): result["protect"] = true
		if battle._is_monster(actor["id"]): continue
		if int(actor.get("statuses", {}).get("burn", 0)) > 0 and result["burned"] == "": result["burned"] = actor["id"]
		if _afflicted(actor): result["afflicted"] = true
		if _has(ability, "status", "stun") and int(actor.get("statuses", {}).get("poison", 0)) > 0 and int(actor.get("statuses", {}).get("stun", 0)) == 0 and int(actor.get("statuses", {}).get("resolve", 0)) == 0:
			result["poisoned"].append(actor["id"])
	return result

static func damage_bonus(battle, owner: Dictionary) -> int:
	if owner.get("form", "") not in ["green_ogre", "ancient_ogre"] or not _state(battle, owner).get("ready", false): return 0
	return 8 if owner["form"] == "ancient_ogre" else 6

static func played(battle, card: Dictionary, before: Dictionary) -> void:
	var owner: Dictionary = battle.get_actor(card.get("owner", ""))
	if before.is_empty() or owner.is_empty() or int(owner["hp"]) <= 0: return
	var state: Dictionary = _state(battle, owner).duplicate()
	var form: String = owner.get("form", "")
	if form in ["green_ogre", "ancient_ogre"]:
		if before["attack"] and state["ready"]:
			state["ready"] = false
			state["used"] = true
			battle._add_log("%s unleashes the readied Bulwark attack." % owner["name"])
		elif before["protect"] and not state["ready"] and not state["used"]:
			state["ready"] = true
			battle._add_log("%s protects an ally: next attack gains +%d damage this turn." % [owner["name"], 8 if form == "ancient_ogre" else 6])
	elif not state["used"]:
		if form in ["red_ogre", "oni"] and before["attack"] and before["burned"] != "":
			for foe in battle.enemies:
				if foe["id"] != before["burned"] and int(foe["hp"]) > 0: battle._status(foe, "burn", 2)
			state["used"] = true
			battle._add_log("%s spreads 2 Burn from the burning target to the other invaders." % owner["name"])
			if form == "oni":
				battle.energy += 1
				battle._add_log("Spirit chain returns 1 energy.")
		elif form in ["basilisk", "ember_basilisk"]:
			for id in before["poisoned"]:
				var foe: Dictionary = battle.get_actor(id)
				if int(foe.get("statuses", {}).get("stun", 0)) > 0:
					var count: int = 2 if form == "ember_basilisk" else 1
					state["used"] = true
					battle._draw(count)
					battle._add_log("%s traps a poisoned foe: draws %d card%s." % [owner["name"], count, "s" if count != 1 else ""])
					break
		elif form in ["shadow_stalker", "nightstalker"] and before["attack"] and before["afflicted"]:
			state["used"] = true
			battle.energy += 1
			if form == "nightstalker": battle._draw(1)
			battle._add_log("%s exploits an afflicted foe: +1 energy%s." % [owner["name"], " and draws 1 card" if form == "nightstalker" else ""])
	battle.form_state[owner["id"]] = state

static func status(battle, owner: Dictionary) -> String:
	var form: String = owner.get("form", "")
	if form == "goblin" or not Data.FORMS.has(form) or int(owner.get("hp", 0)) <= 0: return ""
	var state: Dictionary = _state(battle, owner)
	if state.get("ready", false): return "BULWARK READY · next owned attack +%d damage" % damage_bonus(battle, owner)
	if state.get("used", false): return "FORM COMBO USED · refreshes next turn"
	match form:
		"green_ogre", "ancient_ogre": return "COMBO · protect another ally, then attack"
		"red_ogre", "oni": return "COMBO · attack an already-burning foe"
		"basilisk", "ember_basilisk": return "COMBO · stun an already-poisoned foe"
		"shadow_stalker", "nightstalker": return "COMBO · attack an already-afflicted foe"
	return ""

static func _survives(battle, card: Dictionary, target_id: String) -> bool:
	var actor: Dictionary = battle.get_actor(target_id)
	if actor.is_empty(): return false
	var copy: Dictionary = actor.duplicate(true)
	var owner: Dictionary = battle.get_actor(card.get("owner", ""))
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self": continue
		if effect["kind"] == "break_block": copy["block"] = 0
		if effect["kind"] != "damage": continue
		if int(copy.get("statuses", {}).get("evasion", 0)) > 0:
			copy["statuses"]["evasion"] = int(copy["statuses"]["evasion"]) - 1
			continue
		var result: Dictionary = battle.damage_breakdown(copy, battle._amount(effect, ability, owner, copy))
		copy["block"] = int(copy.get("block", 0)) - int(result["block"])
		copy["hp"] = int(copy["hp"]) - int(result["hp"])
	return int(copy["hp"]) > 0

static func preview(battle, card: Dictionary, target_id: String) -> String:
	var owner: Dictionary = battle.get_actor(card.get("owner", ""))
	var before: Dictionary = prepare(battle, card, target_id)
	if before.is_empty(): return ""
	var state: Dictionary = _state(battle, owner)
	var form: String = owner.get("form", "")
	if state.get("ready", false) and before["attack"]: return "Bulwark: includes +%d damage; consumes the readied attack." % damage_bonus(battle, owner)
	if state.get("used", false): return ""
	if form in ["green_ogre", "ancient_ogre"] and before["protect"] and not state.get("ready", false): return "Bulwark: readies the next owned attack for +%d damage this turn." % (8 if form == "ancient_ogre" else 6)
	if form in ["red_ogre", "oni"] and before["attack"] and before["burned"] != "": return "Fire chain: spreads 2 Burn to other invaders%s." % (" and returns 1 energy" if form == "oni" else "")
	if form in ["basilisk", "ember_basilisk"]:
		for id in before["poisoned"]:
			if _survives(battle, card, id): return "Venom trap: successful stun draws %d card%s." % [2 if form == "ember_basilisk" else 1, "s" if form == "ember_basilisk" else ""]
	if form in ["shadow_stalker", "nightstalker"] and before["attack"] and before["afflicted"]: return "Ambush chain: returns 1 energy%s." % (" and draws 1 card" if form == "nightstalker" else "")
	return ""
