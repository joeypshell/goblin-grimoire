extends SceneTree

# Manual only: intentionally writes one clearly marked report to the new backend.
# Never add this script to CI or a normal player's profile.
const State = preload("res://scripts/run_state.gd")
const Uploader = preload("res://scripts/report_uploader.gd")
const Config = preload("res://scripts/report_config.gd")
const MainScene = preload("res://scenes/main.tscn")
const EXPECTED_ENDPOINT = "https://kuokxkgujawxvtfgefsw.supabase.co/functions/v1/gg-ingest-run"
var profile_root: String
var checks := 0
var failures: Array = []
var receipts: Array = []
var report_id := ""

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--live-report-test"):
		print("LIVE REPORT SKIP: explicit -- --live-report-test flag required; no profiles or HTTP requests created.")
		quit(0)
		return
	check(Config.ENDPOINT == EXPECTED_ENDPOINT, "Only the newly approved backend endpoint can be tested")
	if not failures.is_empty(): quit(1); return
	profile_root = "user://verification/report_live_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var game = State.new(profile_root)
	check(game._prefix.begins_with("user://verification/"), "Live smoke uses an explicit isolated profile")
	game.new_run(730204)
	game.run["report"]["build"] = "0.7.0-verification"
	game.run["report"]["platform"] = "Verification"
	game.save_game()
	report_id = game.current_report()["id"]
	game.start_raid()
	var played := false
	for index in range(game.battle.hand.size()):
		var targets: Array = game.battle.legal_targets(game.battle.hand[index])
		if not targets.is_empty() and game.play_card(index, targets[0]):
			played = true
			break
	check(played, "A real drawn card resolves through the authoritative state API")
	game.end_turn()
	var report: Dictionary = game.current_report()
	check(report["summary"]["cards_played"] == 1 and report["summary"]["turns_ended"] == 1 and report["summary"]["attempts_started"] == 1, "Verification payload contains actual New Run, raid, card and turn actions")
	check(report["build"] == "0.7.0-verification" and report["platform"] == "Verification", "Only explicitly marked verification data is eligible for this live test")
	var revision: int = report["revision"]
	var random_before: int = game.rng.state
	var immutable := JSON.stringify(report)
	var worker = Uploader.new()
	worker.setup(game, true)
	worker.set_process(false)
	root.add_child(worker)
	worker._http.request_completed.connect(_receipt)
	check(worker._live and worker.endpoint == EXPECTED_ENDPOINT, "The actual Godot HTTPRequest uploader is explicitly enabled only for this isolated profile")
	worker.flush()
	var acknowledged: bool = await wait_for_ack(worker, revision)
	check(acknowledged, "The new backend acknowledges the exact report ID and sent revision")
	check(game.rng.state == random_before and JSON.stringify(game.current_report()) == immutable, "Actual upload leaves report contents, gameplay and RNG unchanged")
	var saved: Dictionary = game._read_json(game._prefix + "upload_state.json")
	check(int(saved.get("acks", {}).get(report_id, 0)) == revision and saved.get("tokens", {}).has(report_id), "Acknowledgement and per-run writer credential persist locally without being printed")
	worker.free()
	if acknowledged:
		await verify_reload(game, revision)
	print("LIVE REPORT UUID: %s; revision %d; build 0.7.0-verification; platform Verification" % [report_id, revision])
	for receipt in receipts: print("LIVE RECEIPT: HTTP %d; Godot result %d%s" % [receipt["code"], receipt["result"], "; " + receipt["error"] if receipt["error"] != "" else ""])
	print("LIVE REPORT: %d checks; %d real HTTP completions; %d failures; isolated profile %s" % [checks, receipts.size(), failures.size(), profile_root])
	for failure in failures: print("LIVE FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func _receipt(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	# Never print headers, the write credential, or arbitrary response contents.
	var error: String = str(parsed.get("error", "")).left(100) if parsed is Dictionary else ""
	receipts.append({"result": result, "code": code, "error": error})

func wait_for_ack(worker, revision: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		if int(worker._settings.get("acks", {}).get(report_id, 0)) >= revision: return true
		if not worker._busy: return false
		await process_frame
	return false

func verify_reload(previous, revision: int) -> void:
	var game = State.new(profile_root)
	check(game.load_game() and game.current_report()["id"] == report_id, "Reload restores the same authoritative run and report")
	var worker = Uploader.new()
	worker.setup(game, true)
	worker.set_process(false)
	root.add_child(worker)
	check(int(worker._settings["acks"].get(report_id, 0)) == revision and worker.pending_reports().is_empty(), "Reloaded uploader restores the durable acknowledgement and has no pending duplicate")
	check(worker._settings["tokens"].has(report_id), "Reload restores the existing per-run writer credential")
	var receipt_count: int = receipts.size()
	worker._http.request_completed.connect(_receipt)
	worker.set_enabled(false)
	worker.flush()
	worker._process(60.0)
	check(not worker._busy and receipts.size() == receipt_count and not game._read_json(game._prefix + "upload_state.json")["enabled"], "Paused live uploader starts no request and persists opt-out")
	worker.free()
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 720)
	surface.gui_embed_subwindows = true
	root.add_child(surface)
	var ui = MainScene.instantiate()
	ui.state = game
	surface.add_child(ui)
	ui.report_ui.open()
	for frame in range(3): await process_frame
	var collection = find_named(ui, "ReportCollection")
	var status = find_named(ui, "RunReportStatus")
	var summary = find_named(ui, "RunReportSummary")
	check(not ui.report_uploader._live and not ui.report_uploader.enabled and not ui.report_uploader._busy, "Production UI reload preserves isolated-network guard and saved opt-out")
	check(collection is CheckButton and not collection.button_pressed and status is Label and status.text.contains("paused"), "Report UI displays durable collection preference accurately")
	check(summary is Label and summary.text.contains("0.7.0-verification") and int(ui.report_uploader._settings["acks"].get(report_id, 0)) == revision, "Report UI and its uploader retain the real acknowledged verification report")
	check(game.rng.state == previous.rng.state, "Uploader and report UI reload preserve gameplay RNG")
	surface.free()

func find_named(node: Node, id: String):
	if str(node.name) == id: return node
	for child in node.get_children():
		var found = find_named(child, id)
		if found != null: return found
	return null
