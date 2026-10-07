extends RefCounted

# Local, bounded observations of authoritative actions. Never uses gameplay RNG.
const Data = preload("res://scripts/game_data.gd")
const MAX_EVENTS = 2000
const MAX_REPORTS = 10
const MAX_BYTES = 384 * 1024
const MAX_ATTEMPTS = 100
const BUILD = "0.15.0"
var reports: Array = []

static func utc_now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

static func uuid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0, 8), value.substr(8, 4), value.substr(12, 4), value.substr(16, 4), value.substr(20, 12)]

func load_journal(saved: Dictionary) -> void:
	reports = saved.get("reports", []).duplicate(true) if saved.get("reports") is Array else []
	while reports.size() > MAX_REPORTS: reports.pop_front()

func journal() -> Dictionary:
	return {"schema": 1, "reports": reports.duplicate(true)}

func upsert(report: Dictionary) -> void:
	if report.is_empty(): return
	for index in range(reports.size()):
		if reports[index].get("id", "") == report["id"]:
			if int(reports[index].get("revision", 0)) > int(report["revision"]): return
			reports.remove_at(index)
			break
	reports.append(report.duplicate(true))
	while reports.size() > MAX_REPORTS: reports.pop_front()

func begin(run: Dictionary, partial: bool = false) -> void:
	var now := utc_now()
	run["report"] = {"schema": 1, "id": uuid(), "revision": 0, "build": BUILD,
		"started_at": now, "updated_at": now, "status": "active", "coverage": "partial" if partial else "full",
		"seed": str(run.get("seed", 0)), "platform": OS.get_name(), "dropped_events": 0, "dropped_attempts": 0, "events": [],
		"summary": {"attempts_started": 0, "raids_won": 0, "breaches": 0, "cards_played": 0,
			"turns_ended": 0, "energy_spent": 0, "unused_energy": 0, "bodies_claimed": 0,
			"bodies_skipped": 0, "evolutions": 0, "traits_chosen": 0, "recoveries": 0,
			"monsters_knocked_out": 0, "invaders_knocked_out": 0,
			"cards_by_ability": {}, "cards_by_owner": {}, "trait_triggers": {}, "attempts": []}}
	record(run, "collection_started" if partial else "run_started", {"observed_from": view(run)})
	if partial and run.get("phase", "") == "combat" and run.get("battle") is Dictionary:
		start_attempt(run, compact_battle(run["battle"], true), true)
	finish(run)

func ensure(run: Dictionary) -> bool:
	if run.get("report") is Dictionary and run["report"].get("schema", 0) == 1:
		return false
	begin(run, true)
	return true

func sync_view(run: Dictionary) -> void:
	# Record load-time safe-boundary migrations once; ordinary reloads are silent.
	if run["report"]["status"] != "active": return
	if run["report"]["summary"].get("current", {}) != view(run):
		record(run, "state_observed", {"reason": "persistent_state_changed"})

static func roster(actors: Array) -> Array:
	var result: Array = []
	for actor in actors:
		var entry: Dictionary = {}
		for key in ["id", "name", "form", "class_name", "hp", "max_hp", "armor", "block", "statuses", "status_layers", "selected", "learned", "consumed", "feeds", "abilities", "champion"]:
			if actor.has(key): entry[key] = actor[key].duplicate(true) if actor[key] is Array or actor[key] is Dictionary else actor[key]
		result.append(entry)
	return result

static func view(run: Dictionary) -> Dictionary:
	var result := {"phase": run.get("phase", ""), "raid": run.get("raid", 0),
		"resolved_id": run.get("resolved_id", 0), "recovered_id": run.get("recovered_id", 0),
		"traits": run.get("traits", []).duplicate(), "monsters": roster(run.get("monsters", [])), "deck": configured_deck(run)}
	# Historical fixtures and reports can retain the old metric; new runs omit it.
	if run.has("core"): result["core"] = run["core"]
	if run.has("loss_rule"): result["loss_rule"] = run["loss_rule"]
	if run.get("first_trait_offer") is Array: result["first_trait_offer"] = run["first_trait_offer"].duplicate()
	return result

static func deck_entry(ability: String, owner: String) -> Dictionary:
	var definition: Dictionary = Data.ABILITIES.get(ability, {})
	return {"ability": ability, "owner": owner, "name": definition.get("name", ability), "cost": definition.get("cost", 0)}

static func configured_deck(run: Dictionary) -> Array:
	var result: Array = []
	for actor in run.get("monsters", []):
		var signature: String = Data.FORMS.get(actor.get("form", ""), {}).get("signature", "")
		for ability in [signature] + actor.get("selected", []):
			if not str(ability).is_empty(): result.append(deck_entry(ability, actor["id"]))
	for ability in ["rally", "core_pulse", "snare_dungeon"]: result.append(deck_entry(ability, ""))
	return result

static func compact_battle(snapshot: Dictionary, include_deck: bool = false) -> Dictionary:
	if snapshot.is_empty(): return {}
	var result := {"turn": snapshot.get("turn", 0), "energy": snapshot.get("energy", 0), "outcome": snapshot.get("outcome", "active"),
		"monsters": roster(snapshot.get("monster_combat", [])), "enemies": roster(snapshot.get("enemies", [])),
		"hand": snapshot.get("hand", []).duplicate(true), "draw_count": snapshot.get("draw_pile", []).size(),
		"discard_count": snapshot.get("discard", []).size(), "intents": snapshot.get("intents", []).duplicate(true),
		"traits": snapshot.get("traits", []).duplicate(), "trait_state": snapshot.get("trait_state", {}).duplicate(true)}
	if include_deck:
		result["deck"] = []
		for card in snapshot.get("hand", []) + snapshot.get("draw_pile", []) + snapshot.get("discard", []):
			result["deck"].append(deck_entry(card["ability"], card.get("owner", "")))
	return result

static func capture(battle, include_deck: bool = false) -> Dictionary:
	return {} if battle == null else compact_battle(battle.to_dict(), include_deck)

static func recent_log(battle) -> Array:
	return [] if battle == null else battle.action_log.duplicate()

func record(run: Dictionary, kind: String, data: Dictionary = {}) -> void:
	if not run.get("report") is Dictionary: return
	var report: Dictionary = run["report"]
	report["revision"] = int(report["revision"]) + 1
	report["updated_at"] = utc_now()
	report["summary"]["current"] = view(run)
	report["events"].append({"seq": report["revision"], "at": report["updated_at"], "kind": kind,
		"raid": run.get("raid", 0), "phase": run.get("phase", ""), "data": data.duplicate(true)})
	while report["events"].size() > MAX_EVENTS:
		report["events"].pop_front()
		report["dropped_events"] = int(report.get("dropped_events", 0)) + 1
	_bound(report)

func _bound(report: Dictionary) -> void:
	while JSON.stringify(report).to_utf8_buffer().size() > MAX_BYTES:
		if not report["events"].is_empty():
			report["events"].pop_front()
			report["dropped_events"] += 1
		elif report["summary"]["attempts"].size() > 1:
			report["summary"]["attempts"].pop_front()
			report["dropped_attempts"] += 1
		else:
			# Normal game summaries are bounded by six raids and one terminal wipe.
			break

func count(run: Dictionary, key: String, amount: int = 1) -> void:
	var summary: Dictionary = run["report"]["summary"]
	summary[key] = int(summary.get(key, 0)) + amount

func _attempt(run: Dictionary) -> Dictionary:
	var attempts: Array = run["report"]["summary"]["attempts"]
	return attempts.back() if not attempts.is_empty() else {}

func start_attempt(run: Dictionary, after: Dictionary, partial: bool = false) -> void:
	count(run, "attempts_started")
	var summary: Dictionary = run["report"]["summary"]
	var attempt := {"id": summary["attempts_started"], "raid": run["raid"], "coverage": "partial" if partial else "full",
		"result": "active", "cards_played": 0, "turns_ended": 0, "energy_spent": 0, "unused_energy": 0,
		"start": after.duplicate(true), "trait_triggers": {}}
	summary["attempts"].append(attempt)
	while summary["attempts"].size() > MAX_ATTEMPTS:
		summary["attempts"].pop_front()
		run["report"]["dropped_attempts"] += 1
	record(run, "raid_started", {"attempt": attempt["id"], "partial_start": partial, "battle": after})

func _triggers(run: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var old: Dictionary = before.get("trait_state", {}).get("trigger_counts", {})
	var summary: Dictionary = run["report"]["summary"]
	var attempt := _attempt(run)
	for id in after.get("trait_state", {}).get("trigger_counts", {}):
		var difference := int(after["trait_state"]["trigger_counts"][id]) - int(old.get(id, 0))
		if difference <= 0: continue
		summary["trait_triggers"][id] = int(summary["trait_triggers"].get(id, 0)) + difference
		if not attempt.is_empty(): attempt["trait_triggers"][id] = int(attempt["trait_triggers"].get(id, 0)) + difference
	for faction in ["monsters", "enemies"]:
		var previous := {}
		for actor in before.get(faction, []): previous[actor["id"]] = int(actor["hp"])
		for actor in after.get(faction, []):
			if int(previous.get(actor["id"], 0)) > 0 and int(actor["hp"]) == 0:
				count(run, "monsters_knocked_out" if faction == "monsters" else "invaders_knocked_out")

func played(run: Dictionary, card: Dictionary, targets: Array, before: Dictionary, after: Dictionary, logs: Array) -> void:
	var cost := int(Data.ABILITIES[card["ability"]]["cost"])
	count(run, "cards_played")
	count(run, "energy_spent", cost)
	var summary: Dictionary = run["report"]["summary"]
	for pair in [["cards_by_ability", card["ability"]], ["cards_by_owner", card.get("owner", "")]]:
		summary[pair[0]][pair[1]] = int(summary[pair[0]].get(pair[1], 0)) + 1
	var attempt := _attempt(run)
	if not attempt.is_empty():
		attempt["cards_played"] += 1
		attempt["energy_spent"] += cost
	_triggers(run, before, after)
	record(run, "card_played", {"attempt": attempt.get("id", 0), "card": card, "owner_name": _actor_name(before, card.get("owner", "")),
		"cost": cost, "targets": targets, "before": before, "after": after, "recent_log": logs})

static func _actor_name(snapshot: Dictionary, id: String) -> String:
	for actor in snapshot.get("monsters", []) + snapshot.get("enemies", []):
		if actor["id"] == id: return actor.get("name", id)
	return "Dungeon" if id.is_empty() else id

func ended_turn(run: Dictionary, before: Dictionary, after: Dictionary, logs: Array) -> void:
	count(run, "turns_ended")
	count(run, "unused_energy", int(before.get("energy", 0)))
	var attempt := _attempt(run)
	if not attempt.is_empty():
		attempt["turns_ended"] += 1
		attempt["unused_energy"] += int(before.get("energy", 0))
	_triggers(run, before, after)
	record(run, "turn_ended", {"attempt": attempt.get("id", 0), "before": before, "after": after, "recent_log": logs})

func resolved(run: Dictionary, battle) -> void:
	var after := capture(battle)
	var attempt := _attempt(run)
	if not attempt.is_empty():
		attempt["result"] = battle.outcome
		attempt["end"] = after.duplicate(true)
	count(run, "raids_won" if battle.outcome == "won" else "breaches")
	record(run, "raid_resolved", {"attempt": attempt.get("id", 0), "resolved_id": run["resolved_id"],
		"outcome": battle.outcome, "battle": after})

func finish(run: Dictionary, abandoned: bool = false) -> void:
	if not run.get("report") is Dictionary: return
	var report: Dictionary = run["report"]
	if report["status"] != "active": return
	var phase: String = run.get("phase", "")
	if not abandoned and phase not in ["victory", "defeat"]: return
	report["status"] = "abandoned" if abandoned else phase
	var attempt := _attempt(run)
	if abandoned and not attempt.is_empty() and attempt["result"] == "active":
		attempt["result"] = "abandoned"
		if run.get("battle") is Dictionary: attempt["end"] = compact_battle(run["battle"])
	record(run, "run_ended", {"status": report["status"], "reason": "new_run" if abandoned else "campaign_outcome", "state": view(run)})
