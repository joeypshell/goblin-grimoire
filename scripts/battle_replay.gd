extends "res://scripts/battle.gd"

# Capture the existing deterministic simulation on an isolated copy. Rendering
# never runs effects against the live run, including when a sequence is skipped.
var frames: Array = []
var _capturing := false

static func make(source):
	var replay = load("res://scripts/battle_replay.gd").new()
	var snapshot: Dictionary = source.to_dict()
	replay.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())
	replay.end_turn()
	return replay

func end_turn() -> void:
	_capturing = true
	super.end_turn()
	_capturing = false
	if outcome != "active":
		var snapshot = to_dict()
		_record("finish", "", [], snapshot, snapshot,
			"Raid cleared · next: feed your monsters." if outcome == "won" else "Dungeon breached · recovery applied; next: regroup and retry.")

func _record(kind: String, actor_id: String, targets: Array, before: Dictionary, after: Dictionary, message: String, ability_id: String = "") -> void:
	frames.append({"kind": kind, "actor_id": actor_id, "target_ids": targets.duplicate(),
		"before": before.duplicate(true), "after": after.duplicate(true), "message": message, "ability_id": ability_id})

func _changed_receivers(before: Dictionary, after: Dictionary, targets: Array) -> void:
	var previous: Dictionary = {}
	for actor in before["monster_combat"] + before["enemies"]: previous[actor["id"]] = actor
	for actor in after["monster_combat"] + after["enemies"]:
		var old: Dictionary = previous.get(actor["id"], {})
		if old.is_empty() or targets.has(actor["id"]): continue
		if actor["hp"] != old["hp"] or actor.get("block", 0) != old.get("block", 0) or actor.get("statuses", {}) != old.get("statuses", {}):
			targets.append(actor["id"])

func _resolve(ability: Dictionary, caster: Dictionary, target_id: String) -> void:
	if not _capturing:
		super._resolve(ability, caster, target_id)
		return
	var before = to_dict()
	var targets: Array = _targets(ability["target"], caster, target_id)
	var ids: Array = []
	var names: Array = []
	for target in targets:
		ids.append(target["id"])
		names.append(target["name"])
	super._resolve(ability, caster, target_id)
	var after: Dictionary = to_dict()
	_changed_receivers(before, after, ids)
	var ability_id: String = ""
	for id in Data.ABILITIES:
		if Data.ABILITIES[id] == ability:
			ability_id = id
			break
	_record("enemy", caster["id"], ids, before, after,
		"%s uses %s on %s." % [caster["name"], ability["name"], ", ".join(names)], ability_id)

func _tick_statuses(faction: Array) -> void:
	var before = to_dict()
	var friendly: bool = faction == monsters
	var affected: Array = []
	for actor in faction:
		for status in ["poison", "burn", "regen", "stun", "resolve"]:
			if status == "stun" and not friendly: continue
			if int(actor.get("statuses", {}).get(status, 0)) > 0 and not affected.has(actor["id"]): affected.append(actor["id"])
	super._tick_statuses(faction)
	if not _capturing: return
	var after: Dictionary = to_dict()
	_changed_receivers(before, after, affected)
	_record("player_end" if friendly else "enemy_end", "", affected, before, after,
		"Your turn ends · discard unplayed cards; monster effects tick." if friendly else "Invaders finish · their poison, burn and regeneration tick.")

func _consume_stun(actor: Dictionary) -> void:
	var skipped: bool = _capturing and not _is_monster(actor["id"]) and int(actor.get("statuses", {}).get("stun", 0)) > 0
	var before: Dictionary = to_dict() if skipped else {}
	super._consume_stun(actor)
	if skipped:
		_record("stun", actor["id"], [], before, to_dict(), "%s skips the stunned action · Resolve protects its next action." % actor["name"])

func _begin_turn() -> void:
	var before = to_dict()
	super._begin_turn()
	if _capturing:
		_record("draw", "", [], before, to_dict(), "Your turn · draw %d cards, refill %d energy." % [hand.size(), energy])
