extends RefCounted

const State = preload("res://scripts/run_state.gd")
const Reports = preload("res://scripts/run_reports.gd")
const Data = preload("res://scripts/game_data.gd")
const Replay = preload("res://scripts/battle_replay.gd")

func run(t) -> void:
	t.group("local reports: authoritative actions, RNG neutrality, bounded timeline and lifecycle")
	test_actions(t)
	test_rewards(t)
	test_outcomes(t)
	test_partial_and_abandon(t)
	test_trait_counters(t)
	test_action_logs(t)
	test_bounds(t)

func kinds(report: Dictionary, kind: String) -> Array:
	return report["events"].filter(func(event): return event["kind"] == kind)

func test_actions(t) -> void:
	var game = t.state_at("reports_actions")
	var reference = t.state_at("reports_reference")
	var notifications: Array = []
	game.report_changed.connect(func(id): notifications.append(id))
	game.new_run(9223372036854775806)
	reference.new_run(9223372036854775806)
	var report: Dictionary = game.current_report()
	t.check(report["schema"] == 1 and report["build"] == "0.11.0" and report["coverage"] == "full", "New run receives a full versioned report")
	t.check(report["seed"] == "9223372036854775806" and report["seed"] is String, "Report seed preserves all 64 bits as decimal text")
	t.check(report["id"].length() == 36 and report["id"][14] == "4" and report["id"] != reference.current_report()["id"], "Cryptographic UUIDv4 identifies runs independently")
	t.check(game.rng.state == reference.rng.state and t.same_saved_value(game.run["party"], reference.run["party"]), "Report IDs and timestamps do not alter seeded party generation")
	var revision: int = report["revision"]
	t.check(not game.set_selected("missing", 0, "strike") and game.current_report()["revision"] == revision, "Rejected selection records nothing")
	t.check(game.set_selected("m1", 0, "patch_up") and game.current_report()["revision"] == revision + 1, "Changed selected skill records one actual choice")
	revision = game.current_report()["revision"]
	game.set_selected("m1", 0, "patch_up")
	t.check(game.current_report()["revision"] == revision, "Selecting the current skill is not another decision")
	reference.set_selected("m1", 0, "patch_up")
	game.start_raid()
	reference.start_raid()
	t.check(game.current_report()["summary"]["attempts"][0]["start"]["deck"].size() == 12 and game.current_report()["summary"]["current"]["deck"].size() == 12, "Report preserves actual initial and configured decks with historical names/costs")
	t.check(t.same_saved_value(game.battle.to_dict(), reference.battle.to_dict()), "Recording start leaves full combat and RNG identical")
	var before: Dictionary = game.battle.to_dict()
	revision = game.current_report()["revision"]
	t.check(not game.play_card(-1, "missing") and not game.play_card(500, "m1"), "Invalid card requests are rejected")
	t.check(game.current_report()["revision"] == revision and t.same_saved_value(before, game.battle.to_dict()), "Rejected plays preserve report, combat and RNG")
	var played: Dictionary = game.battle.hand[0].duplicate(true)
	var target: String = game.battle.legal_targets(played)[0]
	t.check(game.play_card(0, target) and reference.play_card(0, target), "Actual drawn card plays through both normal state APIs")
	var event: Dictionary = kinds(game.current_report(), "card_played").back()["data"]
	t.check(event["card"] == played and event["targets"].has(target) and event["cost"] == Data.ABILITIES[played["ability"]]["cost"], "Card event identifies its actual instance, owner, cost and target")
	t.check(event["before"]["intents"] == event["after"]["intents"] and event["before"]["hand"].has(played), "Card event retains locked intent and pre-play hand")
	t.check(t.same_saved_value(game.battle.to_dict(), reference.battle.to_dict()), "Card recording does not alter game resolution or RNG")
	var immutable := JSON.stringify(game.current_report())
	Replay.make(game.battle)
	t.check(JSON.stringify(game.current_report()) == immutable, "Cosmetic replay does not record another simulated turn")
	game.end_turn()
	reference.end_turn()
	t.check(t.same_saved_value(game.battle.to_dict(), reference.battle.to_dict()), "Recorded end turn preserves authoritative deterministic combat")
	t.check(game.current_report()["summary"]["cards_played"] == 1 and game.current_report()["summary"]["turns_ended"] == 1, "Cumulative successful card/turn counters increment once")
	t.check(game.current_report()["summary"]["attempts"][0]["unused_energy"] == 3 - int(Data.ABILITIES[played["ability"]]["cost"]), "Per-attempt energy tracks energy actually left at End Turn")
	var saved := JSON.stringify(game.current_report())
	var signal_count := notifications.size()
	game.save_game()
	game.save_game()
	t.check(JSON.stringify(game.current_report()) == saved and notifications.size() == signal_count, "Repeated saves append no events and emit no duplicate changed revision")
	var loaded = State.new(game._prefix)
	t.check(loaded.load_game() and JSON.stringify(loaded.current_report()) == saved, "Reload preserves report identity, revision and complete timeline")
	t.check(loaded.report_list().size() == 1 and loaded._read_json(loaded._prefix + "reports.json")["reports"][0]["id"] == report["id"], "Separate persistent outbox contains one report per run")
	var returned := loaded.current_report()
	returned["summary"]["cards_played"] = 99
	t.check(loaded.current_report()["summary"]["cards_played"] == 1, "Report accessors return deep copies")
	t.check(not notifications.is_empty() and notifications.all(func(id): return id == report["id"]), "Report changes notify with stable run ID after persistence")

func win_fixture(game) -> void:
	game.start_raid()
	for enemy in game.battle.enemies: enemy["hp"] = 0
	game.end_turn()

func finish_rewards(game) -> void:
	for index in range(game.run["rewards"].size()): game.skip_body(index)
	game.finish_feeding()
	while game.run["phase"] == "trait": game.choose_trait(game.trait_choices()[0])

func test_rewards(t) -> void:
	var game = t.state_at("reports_rewards")
	game.new_run(730204)
	win_fixture(game)
	var body: Dictionary = game.run["rewards"][0].duplicate(true)
	var outcomes: Array = game.inheritance_outcomes(0, "m1").duplicate(true)
	var rng_before: int = game.rng.state
	var revision: int = game.current_report()["revision"]
	t.check(not game.claim_body(0, "missing") and game.rng.state == rng_before and game.current_report()["revision"] == revision, "Invalid claim changes neither report nor random state")
	t.check(game.claim_body(0, "m1"), "Valid random body claim succeeds")
	var event: Dictionary = kinds(game.current_report(), "body_claimed").back()["data"]
	t.check(event["body"]["id"] == body["id"] and t.same_saved_value(event["outcomes"], outcomes) and event["taken"] == game.run["rewards"][0]["taken"], "Claim records real corpse pool, original weighted odds, recipient and actual random outcome")
	revision = game.current_report()["revision"]
	t.check(not game.claim_body(0, "m1") and game.current_report()["revision"] == revision, "Repeated claim records no second feeding")
	var monster: Dictionary = game.get_monster("m1")
	monster["consumed"] = ["heavy_blow", "firebolt"]
	monster["feeds"] = 2
	var recipe: String = game.eligible("m1")[0]["id"]
	t.check(game.evolve("m1", recipe) and game.current_report()["summary"]["evolutions"] == 1, "Real eligible evolution records result once")
	for index in range(1, game.run["rewards"].size()): game.skip_body(index)
	game.finish_feeding()
	t.check(game.current_report()["summary"]["bodies_claimed"] == 1 and game.current_report()["summary"]["bodies_skipped"] == 2, "Feeding summary distinguishes consumption from discarded bodies")
	t.check(game.current_report()["summary"]["recoveries"] == 1 and kinds(game.current_report(), "recovered").size() == 1, "Feeding recovery records exactly once")
	t.check(game.run["phase"] == "trait" and game.choose_trait("pack_instinct"), "Earned trait choice uses production reward state")
	t.check(game.current_report()["summary"]["traits_chosen"] == 1 and kinds(game.current_report(), "trait_chosen").back()["data"]["trait"] == "pack_instinct", "Trait decision appears in cumulative and event data")

func test_outcomes(t) -> void:
	var defeat = t.state_at("reports_defeat")
	defeat.new_run(84)
	for attempt in range(4):
		if defeat.run["phase"] == "result": defeat.continue_after_result()
		defeat.start_raid()
		for monster in defeat.run["monsters"]: monster["hp"] = 0
		defeat.end_turn()
		var event: Dictionary = kinds(defeat.current_report(), "raid_resolved").back()["data"]
		t.check(event["battle"]["monsters"].all(func(actor): return actor["hp"] == 0), "Raid outcome captures KO before breach recovery")
		t.check(defeat.run["monsters"].all(func(actor): return actor["hp"] == 5), "Report capture does not interfere with normal breach recovery")
	var report: Dictionary = defeat.current_report()
	t.check(report["status"] == "defeat" and report["summary"]["breaches"] == 4 and report["summary"]["attempts_started"] == 4, "Repeated same-raid breaches are distinct attempts and one terminal defeat")
	t.check(report["summary"]["attempts"].all(func(attempt): return attempt["raid"] == 0), "Attempt IDs do not confuse retries with cleared raids")
	var revision: int = report["revision"]
	defeat.end_turn()
	defeat.save_game()
	t.check(defeat.current_report()["revision"] == revision and kinds(defeat.current_report(), "run_ended").size() == 1, "Terminal result and repeated end-turn/save do not duplicate completion")
	test_terminal_metadata(t, defeat)
	var victory = t.state_at("reports_victory")
	victory.new_run(620)
	for index in range(6):
		win_fixture(victory)
		finish_rewards(victory)
		if index < 5: victory.continue_after_result()
	t.check(victory.current_report()["status"] == "victory" and victory.current_report()["summary"]["raids_won"] == 6, "Full campaign completion produces one victory report with six raid summaries")
	test_terminal_metadata(t, victory)
	var id: String = victory.current_report()["id"]
	victory.new_run(621)
	t.check(victory.report_list().any(func(item): return item["id"] == id and item["status"] == "victory"), "Restart preserves completed report without relabeling it abandoned")

func test_terminal_metadata(t, game) -> void:
	var frozen := JSON.stringify(game.current_report())
	var random_before: int = game.rng.state
	var notifications: Array = []
	game.report_changed.connect(func(id): notifications.append(id))
	# Simulate a future metadata/loadout migration without editing a saved report.
	game.run["monsters"][0]["name"] = "Future metadata label"
	game.run["monsters"][0]["selected"][0] = "guard"
	game.save_game()
	t.check(JSON.stringify(game.current_report()) == frozen and notifications.is_empty(), "Terminal save freezes report metadata, revision and events despite later roster/deck metadata changes")
	var loaded = State.new(game._prefix)
	t.check(loaded.load_game() and JSON.stringify(loaded.current_report()) == frozen, "Terminal reload retains the immutable historical report when current game metadata differs")
	t.check(loaded.run["monsters"][0]["name"] == "Future metadata label" and loaded.rng.state == random_before, "Terminal report freeze does not block unrelated save metadata or alter RNG")

func test_partial_and_abandon(t) -> void:
	var game = t.state_at("reports_legacy")
	game.new_run(713)
	game.start_raid()
	var legacy: Dictionary = game._read_json(game._prefix + "run.json")
	legacy.erase("report")
	game._write_json(game._prefix + "run.json", legacy)
	var loaded = State.new(game._prefix)
	t.check(loaded.load_game(), "Legacy active combat loads normally")
	var report: Dictionary = loaded.current_report()
	t.check(report["coverage"] == "partial" and report["summary"]["cards_played"] == 0 and report["events"][0]["kind"] == "collection_started", "Legacy report marks observed coverage without inventing prior card history")
	t.check(loaded.rng.state == game.rng.state and t.same_saved_value(loaded.battle.to_dict(), game.battle.to_dict()), "Legacy report migration preserves saved combat and RNG")
	var revision: int = report["revision"]
	loaded.load_game()
	t.check(loaded.current_report()["revision"] == revision, "Repeated legacy reload does not create duplicate collection/start events")
	var id: String = report["id"]
	loaded.new_run(714)
	var archived: Array = loaded.report_list().filter(func(item): return item["id"] == id)
	t.check(archived.size() == 1 and archived[0]["status"] == "abandoned", "Replacing active run persists one abandoned report")
	t.check(archived[0]["summary"]["attempts"][0]["result"] == "abandoned" and archived[0]["events"].back()["data"]["reason"] == "new_run", "Partial abandoned combat retains final observed attempt and explicit replacement reason")
	var from_title = State.new(loaded._prefix)
	var current_id: String = loaded.current_report()["id"]
	from_title.new_run(715)
	t.check(from_title.report_list().any(func(item): return item["id"] == current_id and item["status"] == "abandoned"), "New Run from title archives saved active run even without Continue")
	for index in range(12): from_title.new_run(800 + index)
	t.check(from_title.report_list().size() == 10 and from_title._read_json(from_title._prefix + "reports.json")["reports"].size() == 10, "Persistent report outbox retains at most ten recent runs")
	var recorder = Reports.new()
	var closed := {"seed": 123, "phase": "prep", "raid": 0, "core": 100, "monsters": [], "traits": []}
	recorder.begin(closed)
	recorder.finish(closed, true)
	var frozen := JSON.stringify(closed["report"])
	closed["core"] = 75
	recorder.sync_view(closed)
	t.check(JSON.stringify(closed["report"]) == frozen, "Abandoned report snapshot also remains immutable when later observed metadata differs")

func test_bounds(t) -> void:
	var recorder = Reports.new()
	var state := {"seed": 123, "phase": "prep", "raid": 0, "core": 100, "monsters": [], "traits": []}
	recorder.begin(state)
	for index in range(2100):
		recorder.count(state, "cards_played")
		recorder.record(state, "observed", {"index": index})
	var report: Dictionary = state["report"]
	t.check(report["events"].size() <= Reports.MAX_EVENTS and report["dropped_events"] > 0 and report["summary"]["cards_played"] == 2100, "Event cap truncates oldest history while retaining cumulative metrics")
	var expected: int = report["events"][0]["seq"]
	for event in report["events"]:
		t.check(event["seq"] == expected, "Remaining event IDs stay monotonic after truncation")
		expected += 1
	var large := "x".repeat(8000)
	for index in range(100): recorder.record(state, "long_context", {"text": large})
	t.check(JSON.stringify(report).to_utf8_buffer().size() <= Reports.MAX_BYTES and report["summary"]["cards_played"] == 2100, "UTF-8 byte budget trims long timelines without dropping aggregate metrics")
	var previous_count: int = report["dropped_events"]
	recorder.record(state, "oversized", {"text": "x".repeat(Reports.MAX_BYTES)})
	t.check(JSON.stringify(report).to_utf8_buffer().size() <= Reports.MAX_BYTES and report["dropped_events"] > previous_count, "One oversized event is safely omitted instead of exceeding upload budget")
	recorder.record(state, "unicode", {"text": "火".repeat(150000)})
	t.check(JSON.stringify(report).to_utf8_buffer().size() <= Reports.MAX_BYTES, "Report budget counts UTF-8 bytes instead of character length")

func test_trait_counters(t) -> void:
	var game = t.state_at("reports_trait_counts")
	game.new_run(872)
	game.run["traits"] = ["pack_instinct"]
	game.start_raid()
	var target: String = game.battle.enemies[0]["id"]
	game.battle.enemies[0]["hp"] = 100
	game.battle.enemies[0]["max_hp"] = 100
	game.battle.hand = [{"id": "probe1", "ability": "strike", "owner": "m1"}, {"id": "probe2", "ability": "strike", "owner": "m2"}, {"id": "probe3", "ability": "strike", "owner": "m3"}]
	for index in range(3): t.check(game.play_card(0, target), "Three-owner production card play resolves through recording wrapper")
	t.check(game.current_report()["summary"]["trait_triggers"].get("pack_instinct", 0) == 1 and game.current_report()["summary"]["attempts"][0]["trait_triggers"].get("pack_instinct", 0) == 1, "Trait activations are aggregated from authoritative counter differences once")
	game.save_game()
	var loaded = State.new(game._prefix)
	loaded.load_game()
	t.check(loaded.current_report()["summary"]["trait_triggers"].get("pack_instinct", 0) == 1, "Saved Pack activation does not repeat on reload")

func test_action_logs(t) -> void:
	var game = t.state_at("reports_complete_log")
	game.new_run(528)
	game.start_raid()
	for actor in game.battle.monsters + game.battle.enemies:
		actor["max_hp"] = 500
		actor["hp"] = 400
		for status in ["poison", "burn", "regen"]: game.battle._status(actor, status, 1)
	game.battle.intents = []
	for enemy in game.battle.enemies:
		game.battle.intents.append({"enemy_id": enemy["id"], "ability": "banner_volley", "target_id": "m1", "text": "Locked all-monster fixture"})
	for index in range(90): game.battle._add_log("Previous action context %d" % index)
	var before: Dictionary = game.battle.to_dict()
	var clone = Replay.make(game.battle)
	t.check(not before.has("action_log") and not clone.to_dict().has("action_log"), "Ephemeral complete action log is excluded from save and replay snapshot shape")
	t.check(game.battle.action_log.back() == "Previous action context 89", "Replay logging never replaces the authoritative action buffer")
	game.end_turn()
	var event: Dictionary = kinds(game.current_report(), "turn_ended").back()["data"]
	var canonical: Array = game.battle.action_log.duplicate()
	t.check(canonical.size() > 12 and event["recent_log"] == canonical, "Long multi-invader/status turn report retains every canonical action line beyond twelve")
	t.check(not canonical.any(func(line): return str(line).begins_with("Previous action context")), "Accepted End Turn clears prior action context")
	for enemy in game.battle.enemies:
		t.check(canonical.has("%s uses %s." % [enemy["name"], Data.ABILITIES["banner_volley"]["name"]]), "Complete action log contains every announced invader action")
	t.check(game.battle.log.size() == 80 and t.same_saved_value(game.battle.to_dict(), clone.to_dict()), "Canonical rolling log keeps its eighty-entry cap and replay stays deterministic")
	var report_before := JSON.stringify(game.current_report())
	t.check(not game.play_card(-1, "m1") and game.battle.action_log == canonical and JSON.stringify(game.current_report()) == report_before, "Rejected action clears neither action log nor report and records no duplicate")
	game.battle.hand = [{"id": "fresh_guard", "ability": "guard", "owner": "m1"}]
	t.check(game.play_card(0, "m1"), "Next valid card resolves normally")
	var next: Array = kinds(game.current_report(), "card_played").back()["data"]["recent_log"]
	t.check(next == game.battle.action_log and next.size() < canonical.size() and next[0] == "Grub plays Guard.", "Next card starts a fresh complete buffer with no earlier turn lines")
	t.check(event["recent_log"] == canonical, "Next action cannot mutate an already recorded complete log")
