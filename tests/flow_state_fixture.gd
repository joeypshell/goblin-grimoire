extends "res://scripts/run_state.gd"

# Observe the authoritative boundary, rather than inferring it from animation.
var end_calls := 0
var save_calls := 0

func _init(prefix: String) -> void:
	super(prefix)

func end_turn() -> void:
	end_calls += 1
	super.end_turn()

func save_game() -> void:
	save_calls += 1
	super.save_game()
