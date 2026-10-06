extends RefCounted

# Authoritative observations only: no RNG, log parsing or simulated damage.
# Bonus totals count advertised charge sizes spent per card, not HP damage and
# not a sum across recipients/hits. Legacy battles retain explicitly partial
# coverage rather than inventing actions that occurred before these counters.
static func fresh_state(complete: bool = true) -> Dictionary:
	return {"complete": complete, "cards_played": 0, "bulwark": {}}

static func restore_state(saved) -> Dictionary:
	if not saved is Dictionary: return fresh_state(false)
	var state: Dictionary = saved.duplicate(true)
	if not state.has("complete"): state["complete"] = false
	if not state.has("cards_played"):
		state["cards_played"] = 0
		state["complete"] = false
	if not state.get("bulwark") is Dictionary:
		state["bulwark"] = {}
		state["complete"] = false
	return state

static func card_played(battle) -> void:
	battle.recap_state["cards_played"] = int(battle.recap_state["cards_played"]) + 1

static func bulwark_spent(battle, owner: Dictionary, amount: int) -> void:
	if amount <= 0 or owner.get("id", "") == "": return
	var rows: Dictionary = battle.recap_state["bulwark"]
	var id: String = str(owner["id"])
	if not rows.has(id): rows[id] = {"name": owner.get("name", id), "activations": 0, "bonus_total": 0}
	rows[id]["activations"] = int(rows[id]["activations"]) + 1
	rows[id]["bonus_total"] = int(rows[id]["bonus_total"]) + amount

# raid_index is RunState's zero-based index; displayed recap raids are one-based.
static func capture(battle, raid_index: int) -> Dictionary:
	if battle == null or battle.outcome != "won": return {}
	var survivors: int = 0
	var hp_remaining: int = 0
	var max_hp: int = 0
	for monster in battle.monsters:
		if int(monster["hp"]) > 0: survivors += 1
		hp_remaining += maxi(0, int(monster["hp"]))
		max_hp += maxi(0, int(monster["max_hp"]))
	var bulwark: Array = []
	for owner_id in battle.recap_state["bulwark"]:
		var row: Dictionary = battle.recap_state["bulwark"][owner_id]
		if int(row.get("activations", 0)) <= 0: continue
		bulwark.append({"owner": str(owner_id), "name": row.get("name", str(owner_id)), "activations": int(row["activations"]), "bonus_total": int(row.get("bonus_total", 0))})
	var traits: Array = []
	var triggers: Dictionary = battle.trait_state.get("trigger_counts", {})
	for id in battle.traits:
		var count: int = int(triggers.get(id, 0))
		if count > 0: traits.append({"id": str(id), "count": count})
	return {"raid": raid_index + 1, "rounds": int(battle.turn), "complete": bool(battle.recap_state["complete"]),
		"cards_played": int(battle.recap_state["cards_played"]), "survivors": survivors, "party_size": battle.monsters.size(),
		"hp_remaining": hp_remaining, "max_hp": max_hp, "bulwark": bulwark, "traits": traits}
