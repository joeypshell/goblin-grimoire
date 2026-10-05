extends SceneTree

const Uploader = preload("res://scripts/report_uploader.gd")

class JournalState:
	extends "res://scripts/run_state.gd"
	var items: Array = []
	var fail_writes := false
	var write_attempts := 0
	func _init(prefix: String) -> void: super(prefix)
	func report_list() -> Array: return items.duplicate(true)
	func current_report() -> Dictionary: return items.back().duplicate(true) if not items.is_empty() else {}
	func _write_json(path: String, value: Dictionary) -> bool:
		write_attempts += 1
		return false if fail_writes else super._write_json(path, value)

var profile_root: String
var checks := 0
var failures: Array = []
var server := TCPServer.new()
var peer: StreamPeerTCP
var incoming := PackedByteArray()
var requests: Array = []
var address := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/report_upload_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	print("Uploader verification; isolated profile: ", profile_root)
	for offset in range(20):
		var port: int = 24000 + int(Time.get_ticks_usec() % 15000) + offset
		if server.listen(port, "127.0.0.1") == OK:
			address = "http://127.0.0.1:%d/collect" % port
			break
	check(not address.is_empty(), "A self-contained loopback stub is available; no remote endpoint is used")
	test_guards_and_preferences()
	test_callbacks()
	if address != "":
		await test_real_requests()
		await test_failed_persistence()
	server.stop()
	if peer != null: peer.disconnect_from_host()
	print("REPORT UPLOAD: %d checks; %d local HTTP requests; %d failures" % [checks, requests.size(), failures.size()])
	for failure in failures: print("UPLOAD FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func report(id: String, revision: int = 1) -> Dictionary:
	return {"id": id, "revision": revision, "status": "active", "summary": {"current": {"phase": "combat"}}, "events": []}

func fixture(tag: String, allowed: bool = true) -> Array:
	var journal = JournalState.new(profile_root + tag + "/")
	journal.rng.seed = 773102
	journal.items = [report("alpha")]
	var worker = Uploader.new()
	worker.endpoint = ""
	worker.setup(journal, allowed)
	root.add_child(worker)
	worker.set_process(false)
	return [journal, worker]

func complete(worker, result: int, code: int, response) -> void:
	var text: String = response if response is String else JSON.stringify(response)
	worker._completed(result, code, PackedStringArray(), text.to_utf8_buffer())

func test_guards_and_preferences() -> void:
	var pair = fixture("guards", false)
	var journal = pair[0]
	var worker = pair[1]
	worker.endpoint = address
	worker.flush()
	worker._process(1000)
	check(not worker._live and not worker._busy and worker._settings["tokens"].is_empty(), "Ordinary verification profiles cannot upload even with a configured endpoint")
	check(worker.status_text.contains("Verification profile"), "Disabled isolated sharing is explained")
	worker.free()
	pair = fixture("preferences")
	journal = pair[0]
	worker = pair[1]
	var random_before: int = journal.rng.state
	worker.flush()
	check(not worker._busy and worker.pending_reports().size() == 1 and journal.write_attempts == 0, "Blank endpoint preserves the outbox without generating keys or requests")
	check(worker.status_text.contains("until the dashboard is connected"), "Unconnected automatic sharing remains local")
	worker.set_enabled(false)
	check(not worker.enabled and worker.status_text.contains("paused"), "Off pauses uploads while retaining reports")
	check(journal._read_json(journal._prefix + "upload_state.json")["enabled"] == false, "Off preference is really saved in the isolated profile")
	var reloaded = Uploader.new()
	reloaded.endpoint = ""
	reloaded.setup(journal, true)
	root.add_child(reloaded)
	reloaded.set_process(false)
	check(not reloaded.enabled and reloaded.pending_reports().size() == 1, "Reload restores paused collection without deleting pending reports")
	reloaded.set_enabled(true)
	check(reloaded.enabled and journal._read_json(journal._prefix + "upload_state.json")["enabled"], "On preference survives actual persistence")
	check(journal.rng.state == random_before, "Upload settings do not advance gameplay RNG")
	reloaded._remaining = 15.0
	journal.items[0]["summary"]["current"]["phase"] = "feeding"
	journal.report_changed.emit("alpha")
	check(reloaded._remaining <= 0.2, "A real reward-phase report change expedites the next sync")
	reloaded._settings["tokens"]["expired"] = "stale"
	reloaded._settings["acks"]["expired"] = 9
	reloaded._sent = {"id": "inflight", "revision": 1}
	reloaded._settings["tokens"]["inflight"] = "keep"
	reloaded.set_enabled(true)
	check(not reloaded._settings["tokens"].has("expired") and not reloaded._settings["acks"].has("expired") and reloaded._settings["tokens"].has("inflight"), "Credentials are bounded to retained reports plus an in-flight report")
	reloaded.free()
	worker.free()

func test_callbacks() -> void:
	var cases: Array = [
		[HTTPRequest.RESULT_CANT_CONNECT, 0, {}],
		[HTTPRequest.RESULT_TIMEOUT, 0, {}],
		[HTTPRequest.RESULT_SUCCESS, 500, {"id": "alpha", "revision": 3}],
		[HTTPRequest.RESULT_SUCCESS, 200, "not JSON"],
		[HTTPRequest.RESULT_SUCCESS, 200, []],
		[HTTPRequest.RESULT_SUCCESS, 200, {"id": "different", "revision": 3}],
		[HTTPRequest.RESULT_SUCCESS, 200, {"id": "alpha", "revision": 2}]
	]
	for index in range(cases.size()):
		var pair = fixture("bad_ack_%d" % index)
		var journal = pair[0]
		var worker = pair[1]
		journal.items[0]["revision"] = 3
		worker._busy = true
		worker._sent = {"id": "alpha", "revision": 3}
		var before := JSON.stringify(journal.items)
		var random_before: int = journal.rng.state
		complete(worker, cases[index][0], cases[index][1], cases[index][2])
		check(not worker._busy and worker.pending_reports().size() == 1 and worker._settings["acks"].is_empty(), "Failed/invalid receipt never acknowledges the saved report: %d" % index)
		check(worker._failures == 1 and worker._remaining == 5.0 and worker.status_text.contains("retry"), "Retry starts with a bounded five-second delay: %d" % index)
		check(JSON.stringify(journal.items) == before and journal.rng.state == random_before and journal.write_attempts == 0, "Response handling cannot mutate local reports or gameplay RNG: %d" % index)
		worker.free()
	var pair = fixture("valid_ack")
	var journal = pair[0]
	var worker = pair[1]
	journal.items[0]["revision"] = 4
	worker._busy = true
	worker._sent = {"id": "alpha", "revision": 3}
	complete(worker, HTTPRequest.RESULT_SUCCESS, 200, {"id": "alpha", "revision": 99})
	check(worker._settings["acks"]["alpha"] == 3 and worker.pending_reports()[0]["revision"] == 4, "Server receipt only acknowledges the snapshot sent; a concurrent newer revision stays pending")
	check(journal._read_json(journal._prefix + "upload_state.json")["acks"]["alpha"] == 3, "Acknowledged revision is saved to disk")
	var writes: int = journal.write_attempts
	complete(worker, HTTPRequest.RESULT_SUCCESS, 200, {"id": "alpha", "revision": 4})
	check(journal.write_attempts == writes and worker._settings["acks"]["alpha"] == 3, "Duplicate or late completion outside an active request is ignored")
	for delay in [5.0, 10.0, 20.0, 40.0, 80.0, 160.0, 300.0, 300.0]:
		worker._retry()
		check(worker._remaining == delay, "Exponential retry is capped at five minutes")
	worker.free()
	pair = fixture("ack_write_failure")
	journal = pair[0]
	worker = pair[1]
	journal.fail_writes = true
	worker._busy = true
	worker._sent = {"id": "alpha", "revision": 1}
	complete(worker, HTTPRequest.RESULT_SUCCESS, 200, {"id": "alpha", "revision": 1})
	check(worker.pending_reports().size() == 1 and worker._settings["acks"].is_empty(), "Receipt persistence failure preserves the report for a safe retry")
	journal.fail_writes = false
	worker._busy = true
	worker._sent = {"id": "alpha", "revision": 1}
	complete(worker, HTTPRequest.RESULT_SUCCESS, 200, {"id": "alpha", "revision": 1})
	check(worker.pending_reports().is_empty(), "Repeating the acknowledged snapshot recovers after disk failure")
	worker.free()

func receive_request(worker) -> Dictionary:
	if peer != null: peer.disconnect_from_host()
	peer = null
	incoming = PackedByteArray()
	for frame in range(600):
		if peer == null and server.is_connection_available(): peer = server.take_connection()
		if peer != null:
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				peer = null
				incoming = PackedByteArray()
				await process_frame
				continue
			var available := peer.get_available_bytes()
			if available > 0: incoming.append_array(peer.get_data(available)[1])
			var raw := incoming.get_string_from_utf8()
			var end := raw.find("\r\n\r\n")
			if end >= 0:
				var headers: Dictionary = {}
				for line in raw.substr(0, end).split("\r\n"):
					if line.contains(":"): headers[line.get_slice(":", 0).to_lower()] = line.substr(line.find(":") + 1).strip_edges()
				if incoming.size() >= end + 4 + int(headers.get("content-length", 0)):
					var received := {"headers": headers, "body": JSON.parse_string(raw.substr(end + 4)), "method": raw.get_slice("\r\n", 0)}
					requests.append(received)
					return received
		await process_frame
	check(false, "Loopback HTTP request arrives within a bounded wait")
	worker._http.cancel_request()
	return {}

func respond(worker, receipt: Dictionary) -> void:
	var body := JSON.stringify(receipt)
	var response := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()
	for frame in range(600):
		if not worker._busy: return
		await process_frame
	check(false, "Loopback HTTP acknowledgement completes within a bounded wait")
	worker._http.cancel_request()

func send(worker) -> Dictionary:
	worker.flush()
	var received := await receive_request(worker)
	if not received.is_empty(): await respond(worker, {"id": received["body"]["report"]["id"], "revision": received["body"]["report"]["revision"]})
	return received

func test_real_requests() -> void:
	var pair = fixture("network")
	var journal = pair[0]
	var worker = pair[1]
	worker.endpoint = address
	var random_before: int = journal.rng.state
	var before := JSON.stringify(journal.items)
	var received := await send(worker)
	if received.is_empty(): worker.free(); return
	var token: String = received["headers"].get("x-run-token", "")
	check(received["method"].begins_with("POST /collect") and received["headers"]["content-type"] == "application/json", "Real HTTP uses the intended JSON POST contract")
	check(received["body"]["report"] == JSON.parse_string(before)[0], "Request sends an immutable saved report snapshot")
	check(token.length() == 64 and token.is_valid_hex_number(), "A cryptographic per-run write key is sent in the header")
	check(journal._read_json(journal._prefix + "upload_state.json")["tokens"]["alpha"] == token and worker.pending_reports().is_empty(), "Key persists before upload and the receipt drains the outbox")
	journal.items.append(report("beta", 2))
	journal.items.append(report("gamma", 3))
	for id in ["beta", "gamma"]:
		received = await send(worker)
		check(received.get("body", {}).get("report", {}).get("id", "") == id, "Multiple pending reports are each uploaded rather than overwritten: " + id)
	check(worker.pending_reports().is_empty() and worker._settings["tokens"].values().size() == 3 and worker._settings["tokens"]["beta"] != token, "Distinct retained runs keep independent credentials and acknowledgements")
	journal.items[0]["revision"] = 2
	worker.flush()
	received = await receive_request(worker)
	journal.items[0]["revision"] = 3
	await respond(worker, {"id": "alpha", "revision": 2})
	check(worker.pending_reports().size() == 1 and worker._settings["acks"]["alpha"] == 2, "A newer local report remains pending while an earlier HTTP request completes")
	received = await send(worker)
	check(received["headers"]["x-run-token"] == token and worker._settings["acks"]["alpha"] == 3, "Report revisions reuse the persisted run key and advance only after receipt")
	journal.items[0]["revision"] = 4
	worker.flush()
	await receive_request(worker)
	worker.set_enabled(false)
	check(not worker._busy and worker._sent.is_empty() and worker.pending_reports().size() == 1, "Off cancels an in-flight request without losing its report")
	complete(worker, HTTPRequest.RESULT_SUCCESS, 200, {"id": "alpha", "revision": 4})
	worker._process(1000)
	check(worker._settings["acks"]["alpha"] == 3 and not worker._busy, "Paused uploader ignores stale completion and never automatically restarts")
	worker.set_enabled(true)
	await send(worker)
	check(worker.pending_reports().is_empty() and journal.rng.state == random_before, "Resuming retries the saved report without consuming gameplay RNG")
	var loaded = Uploader.new()
	loaded.endpoint = ""
	loaded.setup(journal, true)
	check(loaded._settings["tokens"]["alpha"] == token and loaded.pending_reports().is_empty(), "Uploader reload preserves tokens and acknowledged revisions")
	loaded.free()
	worker.free()

func test_failed_persistence() -> void:
	var pair = fixture("key_write_failure")
	var journal = pair[0]
	var worker = pair[1]
	worker.endpoint = address
	journal.fail_writes = true
	worker.flush()
	check(not worker._busy and worker.status_text.contains("key could not be saved"), "First key persistence failure sends no request")
	worker.flush()
	check(not worker._busy and worker.pending_reports().size() == 1, "Repeated disk failure must never send an unpersisted run write key")
	if worker._busy: worker._http.cancel_request(); worker._busy = false
	journal.fail_writes = false
	await send(worker)
	check(worker.pending_reports().is_empty(), "Upload resumes after its write key can be persisted")
	worker.free()
	pair = fixture("oversized")
	journal = pair[0]
	worker = pair[1]
	worker.endpoint = address
	journal.items[0]["large"] = "x".repeat(450000)
	worker.flush()
	check(not worker._busy and worker.pending_reports().size() == 1 and worker.status_text.contains("size limit"), "Oversized reports remain local without network or acknowledgement")
	worker.free()
