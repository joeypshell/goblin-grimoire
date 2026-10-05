extends RefCounted

# Dungeon rules share Battle's authoritative state. These helpers never own RNG.
static func fresh_state() -> Dictionary:
	return {"owners": [], "pack_triggered": false, "venom_kos": [],
		"trigger_counts": {"venom_nest": 0, "spiteful_shields": 0, "pack_instinct": 0}}

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

static func played(battle, card: Dictionary) -> void:
	if not battle.traits.has("pack_instinct") or not battle._is_monster(card.get("owner", "")): return
	ensure_state(battle)
	var owners: Array = battle.trait_state["owners"]
	if not owners.has(card["owner"]): owners.append(card["owner"])
	if owners.size() < 3 or battle.trait_state["pack_triggered"]: return
	battle.trait_state["pack_triggered"] = true
	_trigger(battle, "pack_instinct")
	battle.energy += 1
	var before: int = battle.hand.size()
	battle._draw(1)
	battle._add_log("Pack Instinct: three monsters acted; gain 1 energy and draw %d card." % (battle.hand.size() - before))

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
