extends SceneTree

const State = preload("res://scripts/run_state.gd")
const Tests = preload("res://tests/test_reports.gd")
var profile_root: String
var checks := 0
var groups := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	profile_root = "user://verification/reports_%d_%d/" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(profile_root)
	print("Report verification; isolated profile: ", profile_root)
	Tests.new().run(self)
	print("REPORT CORE: %d checks; %d groups; %d failures" % [checks, groups, failures.size()])
	for failure in failures: print("REPORT FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func state_at(tag: String):
	return State.new(profile_root + tag + "/")

func group(label: String) -> void:
	groups += 1
	print("REPORT GROUP: ", label)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func same_saved_value(left, right) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
