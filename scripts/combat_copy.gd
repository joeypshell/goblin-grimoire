extends RefCounted

# Presentation-only queries. These never draw cards, resolve effects or use RNG.
const Data = preload("res://scripts/game_data.gd")

static func owner_name(battle, card: Dictionary) -> String:
	if card["owner"] == "": return "Dungeon shared"
	return battle.get_actor(card["owner"]).get("name", "Monster") + " acts"

static func target_prompt(target: String) -> String:
	return {"enemy": "Choose an invader", "ally": "Choose a monster", "self": "Choose its owner", "all_enemies": "Choose any invader · affects ALL invaders", "all_allies": "Choose any monster · affects ALL monsters"}.get(target, "Choose a target")

static func unavailable(battle, card: Dictionary, resolving: bool = false) -> String:
	if resolving: return "Wait for enemy turn"
	var owner: Dictionary = battle.get_actor(card["owner"])
	if card["owner"] != "" and int(owner.get("hp", 0)) <= 0: return "Owner knocked out"
	if int(owner.get("statuses", {}).get("stun", 0)) > 0: return "Owner stunned this turn"
	if int(Data.ABILITIES[card["ability"]]["cost"]) > battle.energy: return "Not enough energy"
	if battle.legal_targets(card).is_empty(): return "No living legal target"
	return ""

static func guidance(battle, selected: int, resolving: bool, turn_message: String = "") -> String:
	if resolving:
		return turn_message if turn_message != "" else "Invaders resolve their announced actions. Your cards are paused."
	if selected >= 0 and selected < battle.hand.size():
		var card: Dictionary = battle.hand[selected]
		var ability: Dictionary = Data.ABILITIES[card["ability"]]
		var actor: String = battle.get_actor(card["owner"]).get("name", "Dungeon")
		var tap: String = {"enemy": "Tap a highlighted invader to play.", "ally": "Tap a highlighted monster to play.", "self": "Tap its highlighted owner to play.", "all_enemies": "Tap any invader · hits ALL invaders.", "all_allies": "Tap any monster · affects ALL monsters."}[ability["target"]]
		return "%s uses %s · %d energy\n%s\n%s" % [actor, ability["name"], ability["cost"], tap, card_effect(battle, card)]
	if battle.energy <= 0: return "No energy left. End your turn to let invaders act, then draw 5 new cards."
	var playable: bool = false
	for card in battle.hand:
		if unavailable(battle, card) == "": playable = true
	if not playable: return "No playable cards remain. End your turn for fresh cards and energy."
	return "1 · Choose a card, then its target. Monsters act through their own cards."

static func next_step(battle, resolving: bool) -> String:
	if resolving: return "Invaders act, effects tick, then your next hand."
	var count: int = 0
	for intent in battle.intents:
		var actor: Dictionary = battle.get_actor(intent["enemy_id"])
		if int(actor.get("hp", 0)) > 0 and int(actor.get("statuses", {}).get("stun", 0)) <= 0: count += 1
	return "End turn: %d invaders act, then draw %d cards and gain %d energy." % [count, Data.BALANCE["hand"], Data.BALANCE["energy"]]

static func status(actor: Dictionary) -> String:
	var tags: Array = []
	for key in actor.get("statuses", {}):
		if int(actor["statuses"][key]) > 0:
			tags.append("%s %d" % [_status_name(key), actor["statuses"][key]])
	return " · ".join(tags)

static func defenses(actor: Dictionary) -> String:
	return "Armor %d · Block %d" % [Data.armor(actor), maxi(0, int(actor.get("block", 0)))]

static func _status_name(id: String) -> String:
	return {"burn": "Burn", "poison": "Poison", "regen": "Regen", "stun": "Stun", "evasion": "Evade"}.get(id, id.capitalize())

static func _effect_text(battle, ability: Dictionary, caster: Dictionary, target: Dictionary, detailed: bool) -> String:
	var parts: Array = []
	var hp: int = int(target.get("hp", 999))
	var block: int = int(target.get("block", 0))
	var evasion: int = int(target.get("statuses", {}).get("evasion", 0))
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self" and target.get("id", "") != caster.get("id", ""): continue
		if hp <= 0: break
		var amount: int = battle._amount(effect, ability, caster, target)
		match effect["kind"]:
			"damage":
				var prevented: Dictionary = battle.damage_breakdown({"hp": hp, "block": block, "armor": Data.armor(target)}, amount)
				var lost: int = int(prevented["hp"])
				if evasion > 0:
					parts.append("Evades %d damage" % amount)
					evasion -= 1
				else:
					var defenses: Array = []
					if int(prevented["armor"]) > 0: defenses.append("%d armor" % prevented["armor"])
					if int(prevented["block"]) > 0: defenses.append("%d blocked" % prevented["block"])
					parts.append("%d damage: %d HP lost%s" % [amount, lost, " (" + ", ".join(defenses) + ")" if not defenses.is_empty() else ""] if detailed else "%d damage" % amount)
					hp -= lost
					block -= int(prevented["block"])
			"heal": parts.append("+%d HP" % mini(amount, int(target.get("max_hp", 999)) - hp) if detailed else "Heal %d" % amount)
			"block": parts.append("+%d block" % amount)
			"status": parts.append("+%d %s" % [amount, _status_name(effect["status"])])
	if hp > 0:
		for effect in ability["effects"]:
			if effect["kind"] == "damage" and caster.get("form", "") == "red_ogre":
				parts.append("+1 Burn")
				break
			if effect.get("status", "") == "poison" and caster.get("form", "") == "ember_basilisk":
				parts.append("+2 Burn")
	return ", ".join(parts)

static func card_effect(battle, card: Dictionary) -> String:
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	return _effect_text(battle, ability, battle.get_actor(card["owner"]), {}, false)

static func preview(battle, card: Dictionary, actor: Dictionary) -> String:
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var caster: Dictionary = battle.get_actor(card["owner"])
	var text: String = _effect_text(battle, ability, caster, actor, true)
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self" and actor.get("id", "") != caster.get("id", ""):
			text += " · owner +%d %s" % [effect["amount"], _status_name(effect.get("status", "block"))]
	return text

static func intent(battle, actor: Dictionary) -> Dictionary:
	if int(actor["hp"]) <= 0: return {"line": "DEFEATED · will not act", "targets": [], "damage": 0}
	if battle.outcome != "active": return {"line": "Raid ended · no further actions", "targets": [], "damage": 0}
	if int(actor.get("statuses", {}).get("stun", 0)) > 0: return {"line": "STUNNED · next action skipped", "targets": [], "damage": 0}
	for locked in battle.intents:
		if locked["enemy_id"] != actor["id"]: continue
		var ability: Dictionary = Data.ABILITIES[locked["ability"]]
		var id: String = locked["target_id"]
		var target: Dictionary = battle.get_actor(id)
		if int(target.get("hp", 0)) <= 0:
			var alive: Array = battle._targets(ability["target"], actor, "")
			if not alive.is_empty(): id = alive[0]["id"]
		var targets: Array = battle._targets(ability["target"], actor, id)
		var destination: String = "No living target"
		if not targets.is_empty(): destination = targets[0]["name"]
		if ability["target"] == "all_allies": destination = "ALL invaders"
		if ability["target"] == "all_enemies": destination = "ALL monsters"
		var example: Dictionary = targets[0] if not targets.is_empty() else {}
		var effects: String = _effect_text(battle, ability, actor, example, false)
		var damage: int = 0
		for effect in ability["effects"]:
			if effect["kind"] == "damage": damage += int(effect["amount"])
		var ids: Array = []
		for receiver in targets: ids.append(receiver["id"])
		return {"line": "%s · %s to %s" % [ability["name"], effects, destination], "targets": ids, "damage": damage}
	return {"line": "No pending action", "targets": [], "damage": 0}

static func threats(battle, actor_id: String, acted_ids: Array = []) -> String:
	var names: Array = []
	var damage: int = 0
	for enemy in battle.enemies:
		if enemy["id"] in acted_ids: continue
		var action: Dictionary = intent(battle, enemy)
		if actor_id in action["targets"] and action["damage"] > 0:
			names.append(enemy["name"])
			damage += int(action["damage"])
	return "%d announced damage · %s" % [damage, ", ".join(names)] if damage > 0 else "No direct attack aimed here"
