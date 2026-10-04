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

func _record(kind: String, actor_id: String, targets: Array, before: Dictionary, after: Dictionary, message: String) -> void:
	frames.append({"kind": kind, "actor_id": actor_id, "target_ids": targets.duplicate(),
		"before": before.duplicate(true), "after": after.duplicate(true), "message": message})

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
	_record("enemy", caster["id"], ids, before, to_dict(),
		"%s uses %s on %s." % [caster["name"], ability["name"], ", ".join(names)])

func _tick_statuses(faction: Array) -> void:
	var before = to_dict()
	var friendly: bool = faction == monsters
	var affected: Array = []
	for actor in faction:
		for status in ["poison", "burn", "regen", "stun"]:
			if status == "stun" and not friendly: continue
			if int(actor.get("statuses", {}).get(status, 0)) > 0 and not affected.has(actor["id"]): affected.append(actor["id"])
	super._tick_statuses(faction)
	if not _capturing: return
	_record("player_end" if friendly else "enemy_end", "", affected, before, to_dict(),
		"Your turn ends · discard unplayed cards; monster effects tick." if friendly else "Invaders finish · their poison, burn and regeneration tick.")

func _decrease_status(actor: Dictionary, status_id: String, amount: int) -> void:
	var skipped: bool = _capturing and status_id == "stun" and not _is_monster(actor["id"]) and int(actor.get("statuses", {}).get("stun", 0)) > 0
	var before: Dictionary = to_dict() if skipped else {}
	super._decrease_status(actor, status_id, amount)
	if skipped:
		_record("stun", actor["id"], [], before, to_dict(), "%s is stunned · announced action skipped." % actor["name"])

func _begin_turn() -> void:
	var before = to_dict()
	super._begin_turn()
	if _capturing:
		_record("draw", "", [], before, to_dict(), "Your turn · draw %d cards, refill %d energy." % [hand.size(), energy])
