class_name Battle
extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Preview = preload("res://scripts/battle_preview.gd")
const Traits = preload("res://scripts/battle_traits.gd")
const LAYERED_STATUSES = ["poison", "burn", "regen"]
signal changed
signal finished(outcome: String)

var monsters: Array = []
var enemies: Array = []
var hand: Array = []
var draw_pile: Array = []
var discard: Array = []
var energy: int = 0
var turn: int = 0
var outcome: String = "active"
var log: Array = []
var action_log: Array = [] # Ephemeral complete log of one accepted action; never serialized.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var intents: Array = []
var traits: Array = []
var trait_state: Dictionary = {}
var _ticking_statuses: bool = false
var _venom_queue: Array = []

func setup(roster: Array, party: Array, random: RandomNumberGenerator, active_traits: Array = []) -> void:
	monsters = roster
	enemies = party.duplicate(true)
	rng = random
	traits = active_traits.duplicate()
	trait_state = Traits.fresh_state()
	_ticking_statuses = false
	_venom_queue.clear()
	hand.clear()
	draw_pile.clear()
	discard.clear()
	intents.clear()
	log.clear()
	action_log.clear()
	turn = 0
	outcome = "active"
	for actor in monsters + enemies:
		actor["block"] = 0
		actor["statuses"] = {}
		actor["status_layers"] = {}
	for monster in monsters:
		var abilities: Array = [Data.FORMS[monster["form"]]["signature"]] + monster["selected"]
		for slot in range(abilities.size()):
			draw_pile.append({"id": "%s_%d" % [monster["id"], slot], "ability": abilities[slot], "owner": monster["id"]})
	for ability_id in ["rally", "core_pulse", "snare_dungeon"]:
		draw_pile.append({"id": "dungeon_" + ability_id, "ability": ability_id, "owner": ""})
	_remove_ko_cards()
	_shuffle(draw_pile)
	if not _check_outcome():
		_begin_turn()
	changed.emit()

func get_actor(id: String) -> Dictionary:
	for actor in monsters + enemies:
		if actor["id"] == id:
			return actor
	return {}

func card_name(card: Dictionary) -> String:
	return Data.ABILITIES.get(card.get("ability", ""), {"name": "Unknown card"})["name"]

func legal_targets(card: Dictionary) -> Array:
	if outcome != "active" or not Data.ABILITIES.has(card.get("ability", "")):
		return []
	var owner: Dictionary = get_actor(card.get("owner", ""))
	if card.get("owner", "") != "" and (owner.is_empty() or int(owner["hp"]) <= 0):
		return []
	if not owner.is_empty() and int(owner.get("statuses", {}).get("stun", 0)) > 0:
		return []
	var definition: Dictionary = Data.ABILITIES[card["ability"]]
	var target_type: String = definition["target"]
	if target_type == "self":
		return [owner["id"]] if not owner.is_empty() else []
	var targets: Array = monsters if target_type in ["ally", "all_allies"] else enemies
	var result: Array = []
	for actor in targets:
		if int(actor["hp"]) > 0:
			result.append(actor["id"])
	return result

func preview(card: Dictionary, target_id: String) -> String:
	return Preview.describe(self, card, target_id)

func play_card(index: int, target_id: String) -> bool:
	if outcome != "active" or index < 0 or index >= hand.size():
		return false
	var card: Dictionary = hand[index]
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var targets: Array = legal_targets(card)
	if targets.is_empty() or int(ability["cost"]) > energy:
		return false
	if target_id == "" and ability["target"] in ["self", "all_allies", "all_enemies"]:
		target_id = targets[0]
	if not targets.has(target_id):
		return false
	action_log.clear()
	energy -= int(ability["cost"])
	hand.remove_at(index)
	discard.append(card)
	var owner: Dictionary = get_actor(card["owner"])
	_add_log("%s plays %s." % [owner.get("name", "Dungeon"), ability["name"]])
	_resolve(ability, owner, target_id)
	_remove_ko_cards()
	Traits.played(self, card)
	_check_outcome()
	changed.emit()
	return true

func end_turn() -> void:
	if outcome != "active":
		return
	action_log.clear()
	discard.append_array(hand)
	hand.clear()
	# A faction's poison, burning and regeneration tick when that faction ends its turn.
	_tick_statuses(monsters)
	if _check_outcome():
		changed.emit()
		return
	for enemy in enemies:
		enemy["block"] = 0
	for intent in intents:
		var enemy: Dictionary = get_actor(intent["enemy_id"])
		if enemy.is_empty() or int(enemy["hp"]) <= 0:
			continue
		if int(enemy["statuses"].get("stun", 0)) > 0:
			_add_log("%s is stunned and loses the announced action." % enemy["name"])
			_consume_stun(enemy)
			continue
		var ability: Dictionary = Data.ABILITIES[intent["ability"]]
		var target_id: String = intent["target_id"]
		var target: Dictionary = get_actor(target_id)
		if not target.is_empty() and int(target["hp"]) <= 0:
			var candidates: Array = _targets(ability["target"], enemy, "")
			if candidates.is_empty():
				continue
			target_id = candidates[0]["id"]
		_add_log("%s uses %s." % [enemy["name"], ability["name"]])
		_resolve(ability, enemy, target_id)
		if _check_outcome():
			changed.emit()
			return
	_tick_statuses(enemies)
	if not _check_outcome():
		_begin_turn()
	changed.emit()

func _begin_turn() -> void:
	turn += 1
	Traits.begin_turn(self)
	energy = int(Data.BALANCE["energy"])
	for monster in monsters:
		monster["block"] = 0
	_remove_ko_cards()
	_draw(int(Data.BALANCE["hand"]))
	intents.clear()
	for enemy in enemies:
		if int(enemy["hp"]) <= 0:
			continue
		var choices: Array = enemy["abilities"].duplicate()
		var banner_captain: bool = enemy.get("champion", "") == "cinder_banner"
		if banner_captain: choices.erase("banner_volley")
		# Avoid pure healing choices when all adventurers are already healthy.
		var wounded: bool = false
		for ally in enemies:
			if int(ally["hp"]) > 0 and int(ally["hp"]) < int(ally["max_hp"]):
				wounded = true
		if not wounded:
			choices.erase("mend")
			choices.erase("regrowth")
		if choices.is_empty():
			choices = enemy["abilities"].duplicate()
			if banner_captain: choices.erase("banner_volley")
		var ability_id: String = "banner_volley" if banner_captain and turn % 3 == 0 else ""
		if ability_id == "":
			if choices.is_empty(): continue
			ability_id = choices[rng.randi_range(0, choices.size() - 1)]
		var ability: Dictionary = Data.ABILITIES[ability_id]
		var candidates: Array = _targets(ability["target"], enemy, "")
		if candidates.is_empty():
			continue
		var target: Dictionary = candidates[0]
		if ability["target"] == "enemy":
			target = candidates[rng.randi_range(0, candidates.size() - 1)]
		elif ability["target"] == "ally":
			for candidate in candidates:
				if float(candidate["hp"]) / float(candidate["max_hp"]) < float(target["hp"]) / float(target["max_hp"]):
					target = candidate
		var destination: String = target["name"]
		if ability["target"] == "all_allies": destination = "all adventurers"
		if ability["target"] == "all_enemies": destination = "all monsters"
		var intent_text: String = "%s to %s" % [ability["name"], destination]
		if int(enemy["statuses"].get("stun", 0)) > 0:
			intent_text += " · stunned: skips action"
		intents.append({"enemy_id": enemy["id"], "ability": ability_id, "target_id": target["id"], "text": intent_text})
	_add_log("Turn %d. Intentions are locked." % turn)

func _targets(target_type: String, caster: Dictionary, target_id: String) -> Array:
	var friendly: bool = caster.is_empty() or _is_monster(caster["id"])
	var allies: Array = monsters if friendly else enemies
	var foes: Array = enemies if friendly else monsters
	if target_type == "self":
		return [caster] if not caster.is_empty() and int(caster["hp"]) > 0 else []
	var group: Array = allies if target_type in ["ally", "all_allies"] else foes
	var result: Array = []
	for actor in group:
		if int(actor["hp"]) > 0 and (target_type.begins_with("all_") or target_id == "" or actor["id"] == target_id):
			result.append(actor)
	return result

func _resolve(ability: Dictionary, caster: Dictionary, target_id: String) -> void:
	var default_targets: Array = _targets(ability["target"], caster, target_id)
	var kindling: Array = []
	var retaliators: Array = []
	for effect in ability["effects"]:
		var targets: Array = [caster] if effect.get("to", "target") == "self" else default_targets
		for actor in targets:
			if actor.is_empty() or int(actor["hp"]) <= 0:
				continue
			var amount: int = _amount(effect, ability, caster, actor)
			match effect["kind"]:
				"damage":
					var blocked: int = _damage(actor, amount)
					Traits.collect_retaliation(self, caster, actor, blocked, retaliators)
					if caster.get("form", "") == "red_ogre" and not kindling.has(actor["id"]):
						kindling.append(actor["id"])
				"block": actor["block"] = int(actor.get("block", 0)) + amount
				"heal":
					var healed: int = mini(amount, int(actor["max_hp"]) - int(actor["hp"]))
					actor["hp"] = int(actor["hp"]) + healed
					_add_log("%s recovers %d HP." % [actor["name"], healed])
				"status":
					_status(actor, effect["status"], amount)
					if effect["status"] == "poison" and caster.get("form", "") == "ember_basilisk":
						_status(actor, "burn", 2)
				"cleanse":
					for status_id in effect.get("statuses", []):
						var had_status: bool = int(actor.get("statuses", {}).get(status_id, 0)) > 0
						_clear_status(actor, status_id)
						if had_status: _add_log("%s is cleansed of %s." % [actor["name"], _status_name(status_id)])
			_remove_ko_cards()
	for actor_id in kindling:
		var actor: Dictionary = get_actor(actor_id)
		if int(actor["hp"]) > 0:
			_status(actor, "burn", 1)
	Traits.retaliate(self, caster, retaliators)
	if not caster.is_empty() and not _is_monster(caster["id"]):
		_clear_status(caster, "resolve")

func _amount(effect: Dictionary, ability: Dictionary, caster: Dictionary, target: Dictionary) -> int:
	var amount: int = int(effect.get("amount", 0))
	var form: String = caster.get("form", "")
	if effect["kind"] == "block" and form in ["green_ogre", "ancient_ogre"]:
		amount += 3 if form == "ancient_ogre" else 2
	if effect.get("status", "") == "poison" and form == "basilisk":
		amount += 1
	if effect["kind"] == "damage":
		if form == "oni" and ability["affinity"] in ["Mystic", "Flame"]:
			amount += 2
		if form in ["shadow_stalker", "nightstalker"]:
			for status_id in ["poison", "burn", "stun"]:
				if int(target.get("statuses", {}).get(status_id, 0)) > 0:
					amount += 3 if form == "nightstalker" else 2
					break
	return amount

func damage_breakdown(actor: Dictionary, amount: int, piercing: bool = false) -> Dictionary:
	# Armor prevents part of every direct hit; only Block is spent. Damage over time bypasses both.
	var hit: int = maxi(0, amount)
	var armored: int = 0 if piercing else mini(Data.armor(actor), hit)
	var blocked: int = 0 if piercing else mini(maxi(0, int(actor.get("block", 0))), hit - armored)
	return {"armor": armored, "block": blocked, "hp": mini(maxi(0, int(actor.get("hp", 0))), hit - armored - blocked)}

func _damage(actor: Dictionary, amount: int, piercing: bool = false) -> int:
	if int(actor["hp"]) <= 0:
		return 0
	if not piercing and int(actor["statuses"].get("evasion", 0)) > 0:
		_decrease_status(actor, "evasion", 1)
		_add_log("%s evades the hit." % actor["name"])
		return 0
	var prevented: Dictionary = damage_breakdown(actor, amount, piercing)
	actor["block"] = int(actor.get("block", 0)) - int(prevented["block"])
	var lost: int = int(prevented["hp"])
	actor["hp"] = int(actor["hp"]) - lost
	var defenses: Array = []
	if int(prevented["armor"]) > 0: defenses.append("%d armor" % prevented["armor"])
	if int(prevented["block"]) > 0: defenses.append("%d blocked" % prevented["block"])
	_add_log("%s takes %d damage%s." % [actor["name"], lost, " (" + ", ".join(defenses) + ")" if not defenses.is_empty() else ""])
	if int(actor["hp"]) <= 0:
		var poisoned: bool = int(actor["statuses"].get("poison", 0)) > 0
		actor["block"] = 0
		actor["statuses"] = {}
		actor["status_layers"] = {}
		_add_log("%s is knocked out." % actor["name"])
		_remove_ko_cards()
		Traits.knocked_out(self, actor, poisoned)
	return int(prevented["block"])

func _status(actor: Dictionary, status_id: String, amount: int) -> void:
	if int(actor["hp"]) <= 0 or amount <= 0: return
	_normalize_layers(actor)
	if status_id == "stun":
		if int(actor["statuses"].get("resolve", 0)) > 0:
			_add_log("%s resists stun with Resolve." % actor["name"])
			return
		if int(actor["statuses"].get("stun", 0)) > 0:
			_add_log("%s is already stunned; stun does not stack." % actor["name"])
			return
		amount = 1
	if status_id in LAYERED_STATUSES:
		if not actor["status_layers"].has(status_id): actor["status_layers"][status_id] = []
		actor["status_layers"][status_id].append(amount)
	actor["statuses"][status_id] = int(actor["statuses"].get(status_id, 0)) + amount

func _normalize_layers(actor: Dictionary) -> void:
	if not actor.has("statuses"): actor["statuses"] = {}
	if int(actor["statuses"].get("stun", 0)) > 0: actor["statuses"]["stun"] = 1
	if not actor.has("status_layers"): actor["status_layers"] = {}
	for status_id in LAYERED_STATUSES:
		var layers: Array = actor["status_layers"].get(status_id, [])
		# Old saves and aggregate-only fixtures represent one existing application.
		if not actor["status_layers"].has(status_id) and int(actor["statuses"].get(status_id, 0)) > 0:
			layers = [int(actor["statuses"][status_id])]
		var valid: Array = []
		var total: int = 0
		for layer in layers:
			if int(layer) > 0:
				valid.append(int(layer))
				total += int(layer)
		if total > 0:
			actor["status_layers"][status_id] = valid
			actor["statuses"][status_id] = total
		else:
			_clear_status(actor, status_id)

func _clear_status(actor: Dictionary, status_id: String) -> void:
	actor["statuses"].erase(status_id)
	actor.get("status_layers", {}).erase(status_id)

func _consume_stun(actor: Dictionary) -> void:
	_clear_status(actor, "stun")
	actor["statuses"]["resolve"] = 1
	_add_log("%s gains Resolve until its next normal %s." % [actor["name"], "turn" if _is_monster(actor["id"]) else "action"])

func _decrease_status(actor: Dictionary, status_id: String, amount: int) -> void:
	if status_id in LAYERED_STATUSES:
		_normalize_layers(actor)
		for index in range(actor.get("status_layers", {}).get(status_id, []).size()):
			actor["status_layers"][status_id][index] = int(actor["status_layers"][status_id][index]) - amount
		_normalize_layers(actor)
		return
	var left: int = int(actor["statuses"].get(status_id, 0)) - amount
	if left <= 0:
		actor["statuses"].erase(status_id)
	else:
		actor["statuses"][status_id] = left

func _tick_statuses(faction: Array) -> void:
	_ticking_statuses = true
	for actor in faction:
		if int(actor["hp"]) <= 0:
			continue
		_normalize_layers(actor)
		for status_id in ["poison", "burn"]:
			var strength: int = int(actor["statuses"].get(status_id, 0))
			if strength > 0:
				_damage(actor, strength, true)
				_decrease_status(actor, status_id, int(Data.BALANCE["dot_decay"]))
			if int(actor["hp"]) <= 0:
				break
		if int(actor["hp"]) <= 0:
			continue
		var regen: int = int(actor["statuses"].get("regen", 0))
		if regen > 0:
			var healed: int = mini(regen, int(actor["max_hp"]) - int(actor["hp"]))
			actor["hp"] = int(actor["hp"]) + healed
			_decrease_status(actor, "regen", int(Data.BALANCE["dot_decay"]))
			_add_log("%s regenerates %d HP." % [actor["name"], healed])
		if _is_monster(actor["id"]):
			_clear_status(actor, "resolve")
			if int(actor["statuses"].get("stun", 0)) > 0: _consume_stun(actor)
	_ticking_statuses = false
	Traits.flush_venom(self)

func _is_monster(id: String) -> bool:
	for monster in monsters:
		if monster["id"] == id:
			return true
	return false

func _remove_ko_cards() -> void:
	for pile in [hand, draw_pile, discard]:
		for index in range(pile.size() - 1, -1, -1):
			var owner_id: String = pile[index].get("owner", "")
			if owner_id != "" and int(get_actor(owner_id).get("hp", 0)) <= 0:
				pile.remove_at(index)

func _draw(count: int) -> void:
	for _slot in range(count):
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile.append_array(discard)
			discard.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())

func _shuffle(cards: Array) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var card = cards[index]
		cards[index] = cards[other]
		cards[other] = card

func _check_outcome() -> bool:
	if outcome != "active":
		return true
	var allies_alive: bool = false
	var foes_alive: bool = false
	for monster in monsters:
		allies_alive = allies_alive or int(monster["hp"]) > 0
	for enemy in enemies:
		foes_alive = foes_alive or int(enemy["hp"]) > 0
	if not allies_alive: outcome = "breach"
	elif not foes_alive: outcome = "won"
	if outcome != "active":
		_add_log("Raid cleared." if outcome == "won" else "The dungeon has been breached.")
		finished.emit(outcome)
		return true
	return false

func _status_name(status_id: String) -> String:
	return {"burn": "burning", "regen": "regeneration", "evasion": "evasion", "stun": "stun", "poison": "poison", "resolve": "Resolve"}.get(status_id, status_id)

func _add_log(message: String) -> void:
	log.append(message)
	action_log.append(message)
	if log.size() > 80:
		log.pop_front()

func to_dict() -> Dictionary:
	return {"enemies": enemies.duplicate(true), "monster_combat": monsters.duplicate(true), "hand": hand.duplicate(true),
		"draw_pile": draw_pile.duplicate(true), "discard": discard.duplicate(true), "energy": energy,
		"turn": turn, "outcome": outcome, "log": log.duplicate(), "intents": intents.duplicate(true), "rng_state": str(rng.state),
		"traits": traits.duplicate(), "trait_state": trait_state.duplicate(true)}

func restore(saved: Dictionary, roster: Array, random: RandomNumberGenerator) -> void:
	monsters = roster
	rng = random
	traits = saved.get("traits", []).duplicate()
	trait_state = saved.get("trait_state", {}).duplicate(true)
	Traits.ensure_state(self)
	_ticking_statuses = false
	_venom_queue.clear()
	if saved.has("rng_state"):
		rng.state = int(saved["rng_state"])
	enemies = saved.get("enemies", []).duplicate(true)
	for snapshot in saved.get("monster_combat", []):
		var monster: Dictionary = get_actor(snapshot["id"])
		if not monster.is_empty():
			monster["hp"] = int(snapshot["hp"])
			monster["block"] = int(snapshot.get("block", 0))
			monster["statuses"] = snapshot.get("statuses", {}).duplicate(true)
			monster["status_layers"] = snapshot.get("status_layers", {}).duplicate(true)
	for actor in monsters + enemies:
		_normalize_layers(actor)
	hand = saved.get("hand", []).duplicate(true)
	draw_pile = saved.get("draw_pile", []).duplicate(true)
	discard = saved.get("discard", []).duplicate(true)
	energy = int(saved.get("energy", 0))
	turn = int(saved.get("turn", 1))
	outcome = saved.get("outcome", "active")
	log = saved.get("log", []).duplicate()
	intents = saved.get("intents", []).duplicate(true)
	_remove_ko_cards()
	changed.emit()
