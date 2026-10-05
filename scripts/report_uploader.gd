extends Node

const Config = preload("res://scripts/report_config.gd")
signal status_changed

var enabled := true
var status_text := "Reports stay saved on this device until connected."
var dashboard_url: String = Config.DASHBOARD_URL
var state
var endpoint: String = Config.ENDPOINT
var interval := 15.0
var _http: HTTPRequest
var _settings: Dictionary = {}
var _remaining := 0.5
var _busy := false
var _sent: Dictionary = {}
var _failures := 0
var _live := false

func setup(owner_state, allow_isolated_profile: bool = false) -> void:
	state = owner_state
	_live = state._prefix == "user://" or allow_isolated_profile
	_settings = state._read_json(state._prefix + "upload_state.json")
	if not _settings.get("acks") is Dictionary: _settings["acks"] = {}
	if not _settings.get("tokens") is Dictionary: _settings["tokens"] = {}
	enabled = bool(_settings.get("enabled", true))
	state.report_changed.connect(_report_changed)

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.body_size_limit = 8192
	add_child(_http)
	_http.request_completed.connect(_completed)
	_refresh_status()

func _process(delta: float) -> void:
	if not _live or not enabled or endpoint.is_empty() or _busy or state == null: return
	_remaining -= delta
	if _remaining <= 0.0: flush()

func set_enabled(value: bool) -> void:
	enabled = value
	_settings["enabled"] = value
	_persist()
	if not value and _busy:
		_http.cancel_request()
		_busy = false
		_sent = {}
	_remaining = 0.2
	_failures = 0
	_refresh_status()

func _report_changed(_id: String) -> void:
	var current: Dictionary = state.current_report()
	if current.get("status", "active") != "active" or current.get("summary", {}).get("current", {}).get("phase", "") in ["feeding", "trait", "result"]:
		_remaining = minf(_remaining, 0.2)
	_refresh_status()

func pending_reports() -> Array:
	var pending: Array = []
	if state == null: return pending
	for report in state.report_list():
		if int(report.get("revision", 0)) > int(_settings.get("acks", {}).get(report["id"], 0)):
			pending.append(report)
	return pending

func flush() -> void:
	if not _live or not enabled or endpoint.is_empty() or _busy or not is_instance_valid(_http): return
	_remaining = interval
	var pending := pending_reports()
	if pending.is_empty():
		_refresh_status()
		return
	var report: Dictionary = pending[0].duplicate(true)
	var id: String = report["id"]
	if not _settings["tokens"].has(id):
		_settings["tokens"][id] = Crypto.new().generate_random_bytes(32).hex_encode()
		if not _persist():
			_settings["tokens"].erase(id)
			status_text = "Report saved locally; upload key could not be saved."
			status_changed.emit()
			return
	var body := JSON.stringify({"report": report})
	if body.to_utf8_buffer().size() > 393216 + 32:
		status_text = "Report saved locally; it exceeds the upload size limit."
		status_changed.emit()
		return
	_sent = {"id": id, "revision": int(report["revision"])}
	_busy = true
	var result := _http.request(endpoint, PackedStringArray([
		"Content-Type: application/json", "X-Run-Token: " + str(_settings["tokens"][id])
	]), HTTPClient.METHOD_POST, body)
	if result != OK:
		_busy = false
		_retry()
	else:
		status_text = "Sending saved gameplay report…"
		status_changed.emit()

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _busy: return
	_busy = false
	var receipt := JSON.new()
	var ack = receipt.data if receipt.parse(body.get_string_from_utf8()) == OK else null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ack is Dictionary and ack.get("id", "") == _sent.get("id", "") and int(ack.get("revision", 0)) >= int(_sent.get("revision", 1)):
		_settings["acks"][_sent["id"]] = int(_sent["revision"])
		if not _persist():
			_settings["acks"].erase(_sent["id"])
		_failures = 0
		_remaining = 0.2 if pending_reports().size() > 1 else interval
		_refresh_status()
	else:
		_retry()
	_sent = {}

func _retry() -> void:
	_failures += 1
	_remaining = minf(300.0, 5.0 * pow(2.0, min(_failures - 1, 6)))
	status_text = "Report saved on this device. Automatic upload will retry."
	status_changed.emit()

func _persist() -> bool:
	var retained: Array = []
	for report in state.report_list(): retained.append(report["id"])
	if not _sent.is_empty(): retained.append(_sent["id"])
	for category in ["tokens", "acks"]:
		for id in _settings[category].keys():
			if not retained.has(id): _settings[category].erase(id)
	return state._write_json(state._prefix + "upload_state.json", _settings)

func _refresh_status() -> void:
	if not enabled: status_text = "Automatic sharing is paused. Reports stay on this device."
	elif not _live: status_text = "Verification profile: automatic sharing is disabled."
	elif endpoint.is_empty(): status_text = "Reports stay on this device until the dashboard is connected."
	elif _busy: status_text = "Sending saved gameplay report…"
	else:
		var pending := pending_reports().size()
		status_text = "%d saved run report%s waiting to sync." % [pending, "s" if pending != 1 else ""] if pending > 0 else "Saved gameplay reports are synced."
	status_changed.emit()
