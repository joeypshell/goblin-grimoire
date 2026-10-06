extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/run_state.gd")
const Uploader = preload("res://scripts/report_uploader.gd")
const SIZES = [Vector2i(1280, 720), Vector2i(375, 667), Vector2i(390, 844), Vector2i(844, 320)]

var ui
var game
var surface: SubViewport
var pixels: Vector2i
var profile_root: String
var checks := 0
var captured := 0
var failures: Array = []
var can_render := DisplayServer.get_name() != "headless"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/report_ui_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts/reports/")
	FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE).close()
	surface = SubViewport.new()
	surface.gui_embed_subwindows = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	for size_ in SIZES:
		pixels = size_
		surface.size = size_
		await exercise_size()
	print("REPORT UI: %d assertions; %d %s; %d issues" % [checks, captured, "screenshots" if can_render else "layouts", failures.size()])
	for failure in failures: print("REPORT UI FAIL: ", failure)
	surface.free()
	# AudioServer retires stopped music playback references on its next mix callback.
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%dx%d: %s" % [pixels.x, pixels.y, message])
		push_error(failures.back())

func settle() -> void:
	for frame in range(8): await process_frame
	if can_render: await RenderingServer.frame_post_draw

func named(node: Node, id: String):
	if node.is_queued_for_deletion(): return null
	if str(node.name) == id and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, id)
		if found != null: return found
	return null

func reachable(control: Control) -> void:
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await settle()
		ancestor = ancestor.get_parent()
	check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(control.get_global_rect()), "Intentional modal scrolling makes its action reachable")

func replace_uploader() -> void:
	ui.report_uploader.free()
	ui.report_uploader = Uploader.new()
	ui.report_uploader.endpoint = ""
	ui.report_uploader.setup(game, true)
	ui.add_child(ui.report_uploader)
	ui.report_uploader.set_process(false)
	check(ui.report_uploader.endpoint.is_empty() and game._prefix.begins_with(profile_root), "Report UI uses only an isolated, disconnected uploader")

func open_reports(from_title: bool = true) -> void:
	ui.close_modal()
	if from_title:
		ui.menu = "title"
		ui.refresh()
		await settle()
		var button = named(ui, "OpenRunReports")
		check(button is Button, "Production title offers the report settings action")
		if button != null: button.pressed.emit()
	else: ui.report_ui.open()
	await settle()
	check(named(ui, "ReportSettings") != null, "Report settings open through the integrated presentation")

func toggle(value: bool) -> void:
	var control: CheckButton = named(ui, "ReportCollection")
	await reachable(control)
	control.set_pressed_no_signal(value)
	control.toggled.emit(value)
	await settle()
	check(ui.report_uploader.enabled == value and game._read_json(game._prefix + "upload_state.json")["enabled"] == value, "Report toggle updates and saves the actual collection preference")

func exercise_size() -> void:
	game = State.new(profile_root + "%dx%d/" % [pixels.x, pixels.y])
	ui = MainScene.instantiate()
	ui.state = game
	surface.add_child(ui)
	check(not ui.report_uploader._live, "Scene bootstrap isolates upload before any test action")
	replace_uploader()
	await open_reports()
	check(named(ui, "RunReportSummary").text.contains("0 local reports") and named(ui, "RunReportCopy").disabled, "Empty profile explains reports without offering an empty copy")
	await capture("01_empty_report_settings")
	await toggle(false)
	check(named(ui, "RunReportStatus").text.contains("paused"), "Status signal updates the open modal after pausing")
	await capture("02_paused_collection")
	var reload = Uploader.new()
	reload.endpoint = ""
	reload.setup(game, true)
	check(not reload.enabled, "Saved opt-out survives uploader reconstruction")
	reload.free()
	await toggle(true)
	ui.close_modal()
	game.new_run(730204)
	game.start_raid()
	var played := false
	for index in range(game.battle.hand.size()):
		var targets: Array = game.battle.legal_targets(game.battle.hand[index])
		if not targets.is_empty(): played = game.play_card(index, targets[0]); break
	check(played, "UI summary fixture records an actual drawn card through production play")
	game.end_turn()
	var before_report := JSON.stringify(game.current_report())
	var random_before: int = game.rng.state
	await open_reports()
	var summary: Label = named(ui, "RunReportSummary")
	check(summary.text.contains("full coverage") and summary.text.contains("Seed 730204") and summary.text.contains("1 cards played") and summary.text.contains("1 turns ended"), "Report summary identifies actual coverage, seed and successful card/turn counters")
	check(named(ui, "RunReportStatus").text.contains("until the dashboard is connected"), "Disconnected settings promise local retention rather than a completed upload")
	check(not named(ui, "RunReportCopy").disabled and not named(ui, "RunReportDashboard").disabled, "Available report and configured review link expose their intended controls")
	await capture("03_active_recorded_run")
	check(JSON.stringify(game.current_report()) == before_report and game.rng.state == random_before, "Opening, rendering and scrolling report settings cannot record actions or consume RNG")
	var close = named(ui, "RunReportClose")
	await reachable(close)
	await capture("03a_reachable_report_actions")
	close.pressed.emit()
	await settle()
	check(ui.overlay == null or not is_instance_valid(ui.overlay), "Return to game closes report settings")
	# Explicit legacy-save presentation fixture; it sends no reports.
	var saved: Dictionary = game.run.duplicate(true)
	saved.erase("report")
	game._write_json(game._prefix + "run.json", saved)
	var legacy = State.new(game._prefix)
	check(legacy.load_game() and legacy.current_report()["coverage"] == "partial", "Actual legacy load marks reporting coverage as partial")
	game = legacy
	ui.state = game
	replace_uploader()
	await open_reports()
	check(named(ui, "RunReportSummary").text.contains("partial coverage"), "Legacy summary never claims complete earlier decisions")
	check(has_text(ui, "Earlier decisions are not reconstructed"), "Partial report explains missing history")
	await capture("04_legacy_partial_report")
	var collection = named(ui, "ReportCollection")
	var current_report := JSON.stringify(game.current_report())
	var original_size := pixels
	pixels = Vector2i(844, 320) if pixels.x < pixels.y else Vector2i(375, 667)
	surface.size = pixels
	await settle()
	check(is_instance_valid(collection) and collection.button_pressed == ui.report_uploader.enabled, "Rotating an open report modal retains the same saved collection choice")
	await capture("05_rotated_%dx%d_report_settings" % [original_size.x, original_size.y])
	check(JSON.stringify(game.current_report()) == current_report, "Report-modal rotation preserves the observed run without fabricated events")
	pixels = original_size
	surface.size = pixels
	await settle()
	ui.close_modal()
	game.run["phase"] = "defeat"
	game.run["core_hp"] = 0
	game.battle = null
	game.save_game()
	ui.menu = "game"
	ui.refresh()
	await settle()
	var result_button = named(ui, "OpenRunReports")
	check(result_button is Button, "Terminal result exposes the same production report action")
	if result_button != null: result_button.pressed.emit()
	await settle()
	check(named(ui, "RunReportSummary").text.to_lower().contains("defeat"), "Terminal report visibly identifies the actual saved result")
	await capture("06_terminal_report")
	ui.close_modal()
	ui.free()

func has_text(node: Node, fragment: String) -> bool:
	if node is Label and node.text.contains(fragment): return true
	for child in node.get_children():
		if has_text(child, fragment): return true
	return false

func capture(tag: String) -> void:
	await settle()
	inspect(ui)
	var path := "res://tests/artifacts/reports/%dx%d/" % [pixels.x, pixels.y]
	DirAccess.make_dir_recursive_absolute(path)
	if can_render: check(surface.get_texture().get_image().save_png(path + tag + ".png") == OK, "Native report screenshot saved")
	else: check(surface.size == pixels, "Headless report layout uses exact logical dimensions")
	captured += 1
	print("REPORT UI CAPTURE: %dx%d %s" % [pixels.x, pixels.y, tag])

func inspect(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is BaseButton):
		var scrolling := false
		var button
		var ancestor = node.get_parent()
		while ancestor != null:
			if ancestor is BaseButton and button == null: button = ancestor
			if ancestor is ScrollContainer: scrolling = true
			ancestor = ancestor.get_parent()
		var rect: Rect2 = node.get_global_rect()
		if not scrolling: check(Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(rect), "Unscrolled reports label/action stays within viewport: %s rect=%s text=%s" % [node.name, rect, str(node.text).left(140)])
		else: check(rect.position.x >= -1 and rect.end.x <= pixels.x + 1, "Report modal vertical scroll keeps all horizontal content visible: " + node.name)
		if button != null: check(button.get_global_rect().grow(1).encloses(rect), "Report control contains its child label: " + node.name)
		if node is BaseButton and str(node.name).begins_with("RunReport") or node is CheckButton and node.name == "ReportCollection":
			check(node.size.y >= 43.9, "Every report setting action has a forty-four-pixel logical tap target: " + node.name)
	for child in node.get_children(): inspect(child)
