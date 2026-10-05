extends RefCounted

# The recorder and uploader own persistence/network behavior; this is presentation only.
var ui
var status_label: Label
var copy_label: Label

func _init(owner) -> void:
	ui = owner

func open() -> void:
	if ui.resolving_turn: return
	var box: VBoxContainer = ui.open_modal()
	box.name = "ReportSettings"
	box.add_child(ui.label("Playtest reports", 23 if ui.is_compact() else 26, ui.EMBER, true))
	box.add_child(ui.label("Run decisions and battle results are recorded locally. Automatic collection sends the latest run snapshot to the project's private review dashboard. No player identity is collected.", 14, ui.PARCHMENT, true))
	var uploader = ui.report_uploader
	var collection := CheckButton.new()
	collection.name = "ReportCollection"
	collection.text = "Upload playtest reports"
	collection.custom_minimum_size.y = 44
	collection.button_pressed = uploader.enabled
	collection.toggled.connect(func(value): uploader.set_enabled(value))
	box.add_child(collection)
	box.add_child(ui.label("Turn this off to stop future uploads. Local reports and reports already sent remain available.", 13, ui.MUTED, true))
	status_label = ui.label(uploader.status_text, 14, ui.MOSS, true)
	status_label.name = "RunReportStatus"
	box.add_child(status_label)
	if uploader.has_signal("status_changed") and not uploader.status_changed.is_connected(_status_changed):
		uploader.status_changed.connect(_status_changed)
	var report: Dictionary = ui.state.current_report()
	var history: Array = ui.state.report_list()
	var summary: Label = ui.label(_summary(report, history.size()), 14, ui.PARCHMENT, true)
	summary.name = "RunReportSummary"
	box.add_child(summary)
	if report.get("coverage", "") == "partial":
		box.add_child(ui.label("Partial coverage: this older save is observed from when reporting began. Earlier decisions are not reconstructed.", 13, ui.EMBER, true))
	var dashboard: Button = ui.primary("Open review dashboard", func():
		var url: String = uploader.dashboard_url
		if url.begins_with("https://") or url.begins_with("http://"): OS.shell_open(url))
	dashboard.name = "RunReportDashboard"
	dashboard.disabled = str(uploader.dashboard_url).is_empty()
	box.add_child(dashboard)
	box.add_child(ui.label("The dashboard requires an approved reviewer account. Reports describe observed play; they are not verified win rates.", 13, ui.MUTED, true))
	var copy: Button = ui.button("Copy current report JSON", func():
		if report.is_empty(): return
		DisplayServer.clipboard_set(JSON.stringify(report, "\t"))
		if is_instance_valid(copy_label): copy_label.text = "Current report copied as JSON.")
	copy.name = "RunReportCopy"
	copy.disabled = report.is_empty()
	# Browser clipboard permissions vary; the authenticated dashboard has Copy and Download.
	if not OS.has_feature("web"): box.add_child(copy)
	else: copy.free()
	copy_label = ui.label("", 12, ui.MOSS, true)
	copy_label.name = "RunReportCopyStatus"
	box.add_child(copy_label)
	var close: Button = ui.button("Return to game", ui.close_modal)
	close.name = "RunReportClose"
	box.add_child(close)

func _status_changed() -> void:
	if is_instance_valid(status_label): status_label.text = ui.report_uploader.status_text

func _summary(report: Dictionary, count: int) -> String:
	if report.is_empty(): return "%d local reports retained. Start or continue a run to view its current report." % count
	var summary: Dictionary = report.get("summary", {})
	return "%s · %s coverage · Build %s\nSeed %s · Revision %d\n%d cards played · %d turns ended · %d unused energy\n%d raids won · %d breaches · %d meals · %d evolutions\n%d local reports retained." % [
		str(report.get("status", "active")).capitalize(), str(report.get("coverage", "partial")), report.get("build", "unknown"),
		report.get("seed", "unknown"), report.get("revision", 0), summary.get("cards_played", 0), summary.get("turns_ended", 0),
		summary.get("unused_energy", 0), summary.get("raids_won", 0), summary.get("breaches", 0), summary.get("bodies_claimed", 0),
		summary.get("evolutions", 0), count]
