extends RefCounted

# Presentation-only queries. These never draw cards, resolve effects or use RNG.
const Data = preload("res://scripts/game_data.gd")
const BattleTraits = preload("res://scripts/battle_traits.gd")
const Forms = preload("res://scripts/battle_forms.gd")
const EncounterRules = preload("res://scripts/encounter_rules.gd")
const InvaderTactics = preload("res://scripts/invader_tactics.gd")

static func owner_name(battle, card: Dictionary) -> String:
	if card["owner"] == "": return "Dungeon shared"
	return battle.get_actor(card["owner"]).get("name", "Monster") + " acts"

static func target_prompt(target: String) -> String:
	return {"enemy": "Choose an invader", "ally": "Choose a monster", "self": "Choose its owner", "all_enemies": "Choose any invader · affects ALL invaders", "all_allies": "Choose any monster · affects ALL monsters"}.get(target, "Choose a target")

static func unavailable(battle, card: Dictionary, resolving: bool = false) -> String:
	if resolving: return "Wait for enemy turn"
	if not Data.ABILITIES.has(card.get("ability", "")): return "Unknown card"
	var owner: Dictionary = battle.get_actor(card["owner"])
	if card["owner"] != "" and int(owner.get("hp", 0)) <= 0: return "Owner knocked out"
	if int(owner.get("statuses", {}).get("stun", 0)) > 0: return "Owner stunned this turn"
	if Data.ABILITIES[card["ability"]].get("shared_only", false) and card.get("owner", "") != "": return "Dungeon shared spell only"
	if card["ability"] == "echo_rune" and battle.dungeon_state.get("echo_ready", false): return "Echo already armed"
	if card["ability"] == "echo_rune" and not battle.has_owned_attack(): return "No living owned attack in this deck"
	if card["ability"] == "plague_bloom" and battle.legal_targets(card).is_empty(): return "Needs a poisoned foe and another living foe"
	if card["ability"] == "renewal_wave" and battle.legal_targets(card).is_empty(): return "No missing HP or Poison/Burn to cleanse"
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
		var bonus: String = pack_bonus(battle, card)
		var protection_hint: String = protection_bonus(battle, card)
		if protection_hint != "": bonus += ("\n" if bonus != "" else "") + protection_hint
		var form_hint: String = Forms.status(battle, battle.get_actor(card["owner"]))
		if form_hint != "": bonus += ("\n" if bonus != "" else "") + form_hint
		var reason: String = unavailable(battle, card)
		if reason != "": tap = reason + "."
		if card["ability"] == "plague_bloom" and reason == "": tap = "Tap a highlighted poisoned invader · spreads to the OTHER invaders."
		return "%s uses %s · %d energy\n%s\n%s%s" % [actor, ability["name"], ability["cost"], tap, card_effect(battle, card), "\n" + bonus if bonus != "" else ""]
	var playable: bool = false
	for card in battle.hand:
		if unavailable(battle, card) == "": playable = true
	if battle.energy <= 0:
		return "No energy left. A card costing 0 can still be played." if playable else "No energy left. End your turn to let invaders act, then draw 5 new cards."
	if not playable: return "No playable cards remain. End your turn for fresh cards and energy."
	return "1 · Choose a card, then its target. Monsters act through their own cards."

static func dungeon_status(battle) -> String:
	return "ECHO ARMED · next monster-owned attack repeats direct hits once" if battle.dungeon_state.get("echo_ready", false) else ""

static func pack_bonus(battle, card: Dictionary) -> String:
	if not battle.traits.has("pack_instinct") or battle.trait_state.get("pack_triggered", false): return ""
	var owners: Array = battle.trait_state.get("owners", [])
	if card.get("owner", "") == "" or owners.has(card["owner"]) or owners.size() != 2: return ""
	return "Pack Instinct: this third owner grants +1 energy and draws 1 card."

static func protection_bonus(battle, card: Dictionary) -> String:
	# A target is still required: Guard on its owner never earns this reward.
	for id in battle.legal_targets(card):
		var hint: String = BattleTraits.card_preview(battle, card, Forms.prepare(battle, card, id))
		if hint != "": return hint
	return ""

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
			if key == "resolve": tags.append("Resolve · stun protected")
			elif key == "marked": tags.append("Hunter's Mark · next owned hit +%d" % actor["statuses"][key])
			else: tags.append("%s %d" % [_status_name(key), actor["statuses"][key]])
	return " · ".join(tags)

static func defenses(actor: Dictionary) -> String:
	return "Armor %d · Block %d" % [Data.armor(actor), maxi(0, int(actor.get("block", 0)))]

static func encounter_caption(actor: Dictionary) -> String:
	match actor.get("encounter_rule", ""):
		"ward_captain": return "WARD CAPTAIN · Survives HP damage from a card: weakest ally +4 Block"
		"ritual_priest": return "RENEWAL RITUAL · Rounds 2/5/8: wounded ally +9 HP. Stun interrupts"
	return ""

static func _status_name(id: String) -> String:
	return {"burn": "Burn", "poison": "Poison", "regen": "Regen", "stun": "Stun", "evasion": "Evade", "resolve": "Resolve", "marked": "Hunter's Mark"}.get(id, id.capitalize())

static func _effect_text(battle, ability: Dictionary, caster: Dictionary, target: Dictionary, detailed: bool) -> String:
	var parts: Array = []
	var hp: int = int(target.get("hp", 999))
	var block: int = int(target.get("block", 0))
	var evasion: int = int(target.get("statuses", {}).get("evasion", 0))
	var statuses: Dictionary = target.get("statuses", {}).duplicate()
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self" and target.get("id", "") != caster.get("id", ""): continue
		if hp <= 0: break
		var amount: int = battle._amount(effect, ability, caster, target) if effect.has("amount") else 0
		match effect["kind"]:
			"break_block":
				parts.append("Remove %d Block" % block if detailed else "Remove Block")
				block = 0
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
			"heal":
				var restored: int = mini(amount, maxi(0, int(target.get("max_hp", 999)) - hp))
				parts.append("+%d HP" % restored if detailed else "Heal %d" % amount)
				hp += restored
			"block": parts.append("+%d block" % amount)
			"status":
				var id: String = effect["status"]
				if id == "stun" and int(statuses.get("resolve", 0)) > 0:
					parts.append("Stun blocked: Resolve")
				elif id == "stun" and int(statuses.get("stun", 0)) > 0:
					parts.append("Already stunned; no extra skip")
				else:
					parts.append("+%d %s%s" % [amount, _status_name(id), " (decays separately)" if detailed and id in ["poison", "burn", "regen"] else ""])
					statuses[id] = int(statuses.get(id, 0)) + amount
			"cleanse":
				var cleared: Array = []
				for id in effect.get("statuses", []):
					if not detailed or int(statuses.get(id, 0)) > 0: cleared.append(_status_name(id))
					statuses.erase(id)
				parts.append("Cleanse " + "/".join(cleared) if not cleared.is_empty() else "No Poison/Burn to cleanse")
	if hp > 0:
		for effect in ability["effects"]:
			if effect["kind"] == "damage" and caster.get("form", "") == "red_ogre":
				parts.append("+1 Burn")
				break
			if effect.get("status", "") == "poison" and caster.get("form", "") == "ember_basilisk":
				parts.append("+2 Burn")
	elif detailed and battle.traits.has("venom_nest") and int(target.get("statuses", {}).get("poison", 0)) > 0 and not battle._is_monster(target.get("id", "")):
		parts.append("Venom Nest: KO spreads 2 Poison")
	return ", ".join(parts)

static func card_effect(battle, card: Dictionary) -> String:
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	if ability.get("shared_only", false): return ability["description"]
	var caster: Dictionary = battle.get_actor(card["owner"])
	var text: String = _effect_text(battle, ability, caster, {}, false)
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self" and not caster.is_empty():
			text += ", owner +%d %s" % [battle._amount(effect, ability, caster, caster), _status_name(effect.get("status", "block"))]
	if not caster.is_empty() and battle.dungeon_state.get("echo_ready", false) and battle._is_attack(ability): text += " · Echo repeats direct hits once; status riders and tactics once"
	return text

static func preview(battle, card: Dictionary, actor: Dictionary) -> String:
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	# The authoritative read-only forecast also covers global effects and repeated hits.
	if ability.get("shared_only", false) or battle.dungeon_state.get("echo_ready", false) or int(actor.get("statuses", {}).get("marked", 0)) > 0 or battle.traits.has("blood_cauldron") or battle.traits.has("wildfire") or battle.traits.has("spellweaver"):
		return battle.preview(card, actor.get("id", ""))
	var caster: Dictionary = battle.get_actor(card["owner"])
	var text: String = _effect_text(battle, ability, caster, actor, true)
	for effect in ability["effects"]:
		if effect.get("to", "target") == "self" and actor.get("id", "") != caster.get("id", ""):
			text += " · owner +%d %s" % [battle._amount(effect, ability, caster, caster), _status_name(effect.get("status", "block"))]
	if battle.traits.has("spiteful_shields") and battle._is_monster(actor.get("id", "")):
		for effect in ability["effects"]:
			if effect["kind"] == "block":
				text += " · Spiteful Shields: blocking a hit retaliates 3"
				break
	var form_hint: String = Forms.preview(battle, card, actor.get("id", ""))
	if form_hint != "": text += " · " + form_hint
	var trait_hint: String = BattleTraits.card_preview(battle, card, Forms.prepare(battle, card, actor.get("id", "")))
	if trait_hint != "": text += " · " + trait_hint
	var encounter_hint: String = EncounterRules.card_preview(battle, card, actor.get("id", ""))
	if encounter_hint != "": text += " · " + encounter_hint
	return text

static func intent(battle, actor: Dictionary) -> Dictionary:
	if int(actor["hp"]) <= 0: return {"line": "DEFEATED · will not act", "targets": [], "damage": 0}
	if battle.outcome != "active": return {"line": "Raid ended · no further actions", "targets": [], "damage": 0}
	if int(actor.get("statuses", {}).get("stun", 0)) > 0:
		var skipped: String = "STUNNED · next action skipped"
		for locked in battle.intents:
			if locked["enemy_id"] == actor["id"] and locked["ability"] == "banner_volley": skipped = "STUNNED · Banner Volley cancelled"
			if locked["enemy_id"] == actor["id"] and locked["ability"] == "renewal_ritual": skipped = "STUNNED · Renewal Ritual cancelled"
		return {"line": skipped, "targets": [], "damage": 0}
	for locked in battle.intents:
		if locked["enemy_id"] != actor["id"]: continue
		var ability: Dictionary = Data.ABILITIES[locked["ability"]]
		var id: String = locked["target_id"]
		var target: Dictionary = battle.get_actor(id)
		if int(target.get("hp", 0)) <= 0:
			if actor.get("encounter_rule", "") == "ritual_priest" and locked["ability"] == "renewal_ritual":
				var replacement: Dictionary = InvaderTactics.choose_target(battle, actor, ability, battle._targets(ability["target"], actor, ""))
				if replacement.is_empty(): return {"line": "Renewal Ritual · no wounded ally left to heal", "targets": [], "damage": 0}
				id = replacement["id"]
			else:
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
		var line: String = "%s · %s to %s" % [ability["name"], effects, destination]
		var retaliation: int = 0
		var breaks_block: bool = false
		for effect in ability["effects"]:
			if effect["kind"] == "break_block": breaks_block = true
		if not breaks_block:
			for receiver in targets:
				if BattleTraits.retaliation_preview(battle, receiver, actor, damage) != "": retaliation += 1
		if retaliation > 0: line += "\nBlock forecast: %d retaliation%s of 3 damage" % [retaliation, "s" if retaliation != 1 else ""]
		if locked["ability"] == "banner_volley":
			line += "\nResolve prevents Stun: defeat the captain or protect all monsters." if int(actor.get("statuses", {}).get("resolve", 0)) > 0 else "\nCOUNTERPLAY: Stun or defeat the captain."
		elif actor.get("champion", "") == "cinder_banner":
			var rounds: int = 3 - battle.turn % 3
			line += "\nBanner Volley in %d round%s" % [rounds, "s" if rounds != 1 else ""]
		if locked["ability"] == "breach_order":
			line += "\nCOUNTERPLAY: Stun or defeat the marshal; Block is removed before the hit."
		elif actor.get("champion", "") == "iron_marshal":
			var rounds: int = (2 - battle.turn % 3 + 3) % 3
			line += "\nBreach Order in %d round%s" % [rounds, "s" if rounds != 1 else ""]
		if locked["ability"] == "renewal_ritual":
			line += "\nCOUNTERPLAY: Resolve prevents Stun; defeat the priest." if int(actor.get("statuses", {}).get("resolve", 0)) > 0 else "\nCOUNTERPLAY: Stun or defeat the priest to stop the heal."
		return {"line": line, "targets": ids, "damage": damage}
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

static func champion_milestone(battle) -> String:
	# Read the shown battle, including its locked actions. Playback callers hide
	# this line because after-snapshots retain actions that already happened.
	if battle.outcome != "active": return ""
	for captain in battle.enemies:
		if captain.get("champion", "") != "cinder_banner" or int(captain.get("hp", 0)) <= 0: continue
		for locked in battle.intents:
			if locked["enemy_id"] != captain["id"]: continue
			if locked["ability"] == "banner_volley":
				if int(captain.get("statuses", {}).get("stun", 0)) > 0:
					return "BANNER VOLLEY · cancelled this enemy turn\nCaptain stunned · no Volley damage or Burn"
				var counter: String = "Stun or defeat captain"
				if int(captain.get("statuses", {}).get("resolve", 0)) > 0: counter = "Resolve blocks Stun · defeat captain or protect all"
				return "BANNER VOLLEY · THIS ENEMY TURN\n5 damage +1 Burn to ALL monsters · " + counter
			var away: int = 3 - battle.turn % 3
			return "BANNER VOLLEY · round %d · %s" % [battle.turn + away, "next round" if away == 1 else "%d rounds away" % away]
	return ""

static func banner_guidance(battle) -> String:
	if battle.outcome != "active": return ""
	for captain in battle.enemies:
		if captain.get("champion", "") == "iron_marshal" and int(captain["hp"]) > 0:
			for locked in battle.intents:
				if locked["enemy_id"] != captain["id"] or locked["ability"] != "breach_order": continue
				if int(captain.get("statuses", {}).get("stun", 0)) > 0: return "Marshal: Breach Order cancelled"
				if int(captain.get("statuses", {}).get("resolve", 0)) > 0: return "Breach Order: Resolve blocks Stun; defeat the marshal or use Evade. Block will be removed"
				return "COUNTERPLAY: Stun or defeat the marshal to cancel Breach Order. Block will be removed"
			var rounds: int = (2 - battle.turn % 3 + 3) % 3
			return "Marshal: Breach Order in %d round%s / removes Block before hitting the pack" % [rounds, "s" if rounds != 1 else ""]
		if captain.get("champion", "") != "cinder_banner" or int(captain["hp"]) <= 0: continue
		for locked in battle.intents:
			if locked["enemy_id"] != captain["id"] or locked["ability"] != "banner_volley": continue
			if int(captain.get("statuses", {}).get("stun", 0)) > 0: return "Captain: Banner Volley cancelled"
			if int(captain.get("statuses", {}).get("resolve", 0)) > 0: return "Banner Volley: Resolve blocks Stun; defeat the captain or protect all monsters"
			return "COUNTERPLAY: Stun or defeat the captain to cancel Banner Volley"
		var rounds: int = 3 - battle.turn % 3
		return "Captain: Banner Volley in %d round%s" % [rounds, "s" if rounds != 1 else ""]
	for actor in battle.enemies:
		if int(actor.get("hp", 0)) <= 0: continue
		if actor.get("encounter_rule", "") == "ward_captain":
			return "WARD CAPTAIN: Surviving HP damage protects the weakest ally (+4 Block). Defeat the captain or strike their allies"
		if actor.get("encounter_rule", "") != "ritual_priest": continue
		for locked in battle.intents:
			if locked["enemy_id"] != actor["id"] or locked["ability"] != "renewal_ritual": continue
			if int(actor.get("statuses", {}).get("stun", 0)) > 0: return "Priest: Renewal Ritual cancelled"
			if intent(battle, actor)["targets"].is_empty(): return "Priest: no wounded ally left to heal"
			if int(actor.get("statuses", {}).get("resolve", 0)) > 0: return "Renewal Ritual heals 9 HP: Resolve blocks Stun; defeat the priest to stop it"
			return "Renewal Ritual heals 9 HP: Stun or defeat the priest to stop it"
		return encounter_caption(actor)
	return ""
