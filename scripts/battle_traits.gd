extends RefCounted

# Dungeon rules share Battle's authoritative state. These helpers never own RNG.
static func fresh_state() -> Dictionary:
	return {"owners": [], "pack_triggered": false, "war_drums_triggered": false, "venom_kos": [],
		"blood_cauldron_triggered": false, "wildfire_triggered": false, "spellweaver_triggered": false,
		"trigger_counts": {"venom_nest": 0, "spiteful_shields": 0, "pack_instinct": 0, "war_drums": 0, "blood_cauldron": 0, "wildfire": 0, "lingering_wards": 0, "spellweaver": 0}}

static func ensure_state(battle) -> void:
	var defaults: Dictionary = fresh_state()
	for key in defaults:
		if not battle.trait_state.has(key): battle.trait_state[key] = defaults[key]
	for id in defaults["trigger_counts"]:
		if not battle.trait_state["trigger_counts"].has(id): battle.trait_state["trigger_counts"][id] = 0

static func _trigger(battle, id: String) -> void:
	ensure_state(battle)
	battle.trait_state["trigger_counts"][id] = int(battle.trait_state["trigger_counts"][id]) + 1

static func begin_turn(battle) -> void:
	ensure_state(battle)
	battle.trait_state["owners"] = []
	battle.trait_state["pack_triggered"] = false
	battle.trait_state["war_drums_triggered"] = false
	for id in ["blood_cauldron", "wildfire", "spellweaver"]: battle.trait_state[id + "_triggered"] = false

static func _war_drums_ready(battle, card: Dictionary, before: Dictionary) -> bool:
	if not battle.traits.has("war_drums") or battle.trait_state.get("war_drums_triggered", false) or not before.get("protect", false): return false
	var owner: Dictionary = battle.get_actor(card.get("owner", ""))
	return not owner.is_empty() and battle._is_monster(owner["id"]) and int(owner.get("hp", 0)) > 0

static func card_preview(battle, card: Dictionary, before: Dictionary = {}) -> String:
	var parts: Array = []
	if _war_drums_ready(battle, card, before): parts.append("War Drums: protect another monster to gain 1 energy and draw 1 card (first protection this turn).")
	if battle.traits.has("blood_cauldron") and not battle.trait_state.get("blood_cauldron_triggered", false) and int(before.get("healed", 0)) > 0: parts.append("Blood Cauldron: this healing draws 1 card (first healing card this turn).")
	if battle.traits.has("wildfire") and not battle.trait_state.get("wildfire_triggered", false) and card.get("owner", "") == "" and not before.get("damaged", []).is_empty(): parts.append("Wildfire: +1 Burn to the damaged survivors (first shared area attack this turn).")
	var ability: Dictionary = preload("res://scripts/game_data.gd").ABILITIES.get(card.get("ability", ""), {})
	if battle.traits.has("spellweaver") and not battle.trait_state.get("spellweaver_triggered", false) and card.get("owner", "") == "" and int(ability.get("cost", 0)) >= 2: parts.append("Spellweaver: return 1 energy after playing (first costly shared spell this turn).")
	return "\n".join(parts)

static func played(battle, card: Dictionary, before: Dictionary = {}) -> void:
	ensure_state(battle)
	if battle.traits.has("blood_cauldron") and not battle.trait_state["blood_cauldron_triggered"] and int(before.get("healed", 0)) > 0:
		battle.trait_state["blood_cauldron_triggered"] = true
		_trigger(battle, "blood_cauldron")
		var hand_before: int = battle.hand.size()
		battle._draw(1)
		battle._add_log("Blood Cauldron: restoring HP draws %d card." % (battle.hand.size() - hand_before))
	var ability: Dictionary = preload("res://scripts/game_data.gd").ABILITIES[card["ability"]]
	if card.get("owner", "") == "":
		if battle.traits.has("spellweaver") and not battle.trait_state["spellweaver_triggered"] and int(ability["cost"]) >= 2:
			battle.trait_state["spellweaver_triggered"] = true
			_trigger(battle, "spellweaver")
			battle.energy += 1
			battle._add_log("Spellweaver: costly shared spell returns 1 energy.")
		if battle.traits.has("wildfire") and not battle.trait_state["wildfire_triggered"] and ability["target"] == "all_enemies" and battle._is_attack(ability):
			var recipients: Array = []
			for id in before.get("damaged", []):
				var foe: Dictionary = battle.get_actor(id)
				if int(foe.get("hp", 0)) > 0:
					battle._status(foe, "burn", 1)
					recipients.append(foe["name"])
			if not recipients.is_empty():
				battle.trait_state["wildfire_triggered"] = true
				_trigger(battle, "wildfire")
				battle._add_log("Wildfire: +1 Burn to %s." % ", ".join(recipients))
	if not battle._is_monster(card.get("owner", "")): return
	if _war_drums_ready(battle, card, before):
		battle.trait_state["war_drums_triggered"] = true
		_trigger(battle, "war_drums")
		battle.energy += 1
		var hand_before: int = battle.hand.size()
		battle._draw(1)
		battle._add_log("War Drums: protecting another monster grants 1 energy and draws %d card." % (battle.hand.size() - hand_before))
	if battle.traits.has("pack_instinct"):
		var owners: Array = battle.trait_state["owners"]
		if not owners.has(card["owner"]): owners.append(card["owner"])
		if owners.size() >= 3 and not battle.trait_state["pack_triggered"]:
			battle.trait_state["pack_triggered"] = true
			_trigger(battle, "pack_instinct")
			battle.energy += 1
			var hand_before: int = battle.hand.size()
			battle._draw(1)
			battle._add_log("Pack Instinct: three monsters acted; gain 1 energy and draw %d card." % (battle.hand.size() - hand_before))

static func knocked_out(battle, actor: Dictionary, poisoned: bool) -> void:
	if not poisoned or not battle.traits.has("venom_nest") or battle._is_monster(actor["id"]): return
	ensure_state(battle)
	if battle.trait_state["venom_kos"].has(actor["id"]): return
	# Mark before spreading so chained KOs can never reenter the same death.
	battle.trait_state["venom_kos"].append(actor["id"])
	if battle._ticking_statuses: battle._venom_queue.append(actor["id"])
	else: _spread(battle, actor["id"])

static func _spread(battle, source_id: String) -> void:
	var recipients: Array = []
	for enemy in battle.enemies:
		if enemy["id"] == source_id or int(enemy["hp"]) <= 0: continue
		battle._status(enemy, "poison", 2)
		recipients.append(enemy["name"])
	if not recipients.is_empty(): _trigger(battle, "venom_nest")
	battle._add_log("Venom Nest: %s's poisoned death spreads 2 Poison to %s." % [battle.get_actor(source_id).get("name", "An invader"), ", ".join(recipients) if not recipients.is_empty() else "no remaining invaders"])

static func flush_venom(battle) -> void:
	var pending: Array = battle._venom_queue.duplicate()
	battle._venom_queue.clear()
	for source_id in pending: _spread(battle, source_id)

static func collect_retaliation(battle, caster: Dictionary, defender: Dictionary, blocked: int, recipients: Array) -> void:
	if blocked <= 0 or not battle.traits.has("spiteful_shields") or caster.is_empty(): return
	if battle._is_monster(caster["id"]) or not battle._is_monster(defender["id"]) or int(defender["hp"]) <= 0: return
	if not recipients.has(defender["id"]): recipients.append(defender["id"])

static func retaliate(battle, attacker: Dictionary, recipients: Array) -> void:
	for id in recipients:
		if int(attacker.get("hp", 0)) <= 0: break
		var defender: Dictionary = battle.get_actor(id)
		if int(defender.get("hp", 0)) <= 0: continue
		_trigger(battle, "spiteful_shields")
		battle._add_log("Spiteful Shields: %s retaliates for 3 damage against %s." % [defender["name"], attacker["name"]])
		# A direct hit, without another enemy attack context: no recursive backlash.
		battle._damage(attacker, 3)

static func retaliation_preview(battle, defender: Dictionary, attacker: Dictionary, amount: int) -> String:
	if not battle.traits.has("spiteful_shields") or defender.is_empty() or attacker.is_empty(): return ""
	if not battle._is_monster(defender.get("id", "")) or battle._is_monster(attacker.get("id", "")): return ""
	if int(attacker.get("hp", 0)) <= 0 or int(defender.get("statuses", {}).get("evasion", 0)) > 0: return ""
	var hit: Dictionary = battle.damage_breakdown(defender, amount)
	if int(hit["block"]) <= 0 or int(defender.get("hp", 0)) <= int(hit["hp"]): return ""
	if int(attacker.get("statuses", {}).get("evasion", 0)) > 0: return "retaliates 3 damage (evaded)"
	var reply: Dictionary = battle.damage_breakdown(attacker, 3)
	return "retaliates 3 damage (%d HP)" % reply["hp"]
