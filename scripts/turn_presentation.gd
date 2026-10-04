extends RefCounted

const Replay = preload("res://scripts/battle_replay.gd")
const BattleModel = preload("res://scripts/battle.gd")
const Feedback = preload("res://scripts/combat_feedback.gd")
const Data = preload("res://scripts/game_data.gd")

var ui
var active := false
var view
var actor_id := ""
var target_ids: Array = []
var acted_ids: Array = []
var stage := "player"
var kind := ""
var message := ""
var detail := ""
var delay_scale := 1.0
var _generation := 0

func _init(owner) -> void:
	ui = owner

func _show(snapshot: Dictionary) -> void:
	view = BattleModel.new()
	view.restore(snapshot, snapshot["monster_combat"].duplicate(true), RandomNumberGenerator.new())

func end_turn() -> void:
	if active or ui.menu != "game" or ui.state.run.get("phase", "") != "combat" or is_instance_valid(ui.overlay): return
	if ui.state.battle == null or ui.state.battle.outcome != "active": return
	active = true
	_generation += 1
	var generation = _generation
	ui.card_index = -1
	ui.last_action = ""
	acted_ids.clear()
	var replay = Replay.make(ui.state.battle)
	# Commit and save once before presentation. Reloading or skipping is safe.
	ui.state.end_turn()
	for frame in replay.frames:
		if not active or generation != _generation or not is_instance_valid(ui): return
		stage = "enemy" if frame["kind"] in ["enemy", "stun"] else frame["kind"]
		kind = frame["kind"]
		actor_id = frame["actor_id"]
		target_ids = frame["target_ids"].duplicate()
		message = frame["message"]
		detail = ""
		_show(frame["before"])
		ui.refresh()
		await ui.get_tree().create_timer((0.45 if stage == "enemy" else 0.3) * delay_scale).timeout
		if not active or generation != _generation or not is_instance_valid(ui): return
		_show(frame["after"])
		detail = Feedback.describe(frame["before"], frame["after"])
		if stage == "draw": detail = "New intentions are shown below. Choose a card to act."
		ui.refresh()
		await ui.get_tree().process_frame
		if not active or generation != _generation or not is_instance_valid(ui): return
		Feedback.flash(ui, frame["before"], frame["after"])
		await ui.get_tree().create_timer((0.55 if stage == "enemy" else 0.3) * delay_scale).timeout
		if not active or generation != _generation or not is_instance_valid(ui): return
		if actor_id != "": acted_ids.append(actor_id)
	_finish()

func _finish() -> void:
	active = false
	view = null
	stage = "player"
	kind = ""
	actor_id = ""
	target_ids.clear()
	acted_ids.clear()
	message = ""
	detail = ""
	if is_instance_valid(ui): ui.refresh()

func skip() -> void:
	if not active: return
	_generation += 1
	_finish()

func clear_feedback() -> void:
	Feedback.clear(ui)

func play(target_id: String) -> void:
	if active or ui.menu != "game" or ui.state.run.get("phase", "") != "combat" or is_instance_valid(ui.overlay): return
	var battle = ui.state.battle
	if battle == null or ui.card_index < 0 or ui.card_index >= battle.hand.size(): return
	var card: Dictionary = battle.hand[ui.card_index].duplicate(true)
	var before: Dictionary = battle.to_dict()
	var owner: String = battle.get_actor(card["owner"]).get("name", "Dungeon")
	var ability: String = Data.ABILITIES[card["ability"]]["name"]
	if not ui.state.play_card(ui.card_index, target_id): return
	_generation += 1
	var generation = _generation
	# The battle snapshot, rather than run recovery, supplies actual combat damage.
	var after: Dictionary = battle.to_dict()
	ui.last_action = "%s played %s. %s" % [owner, ability, Feedback.describe(before, after)]
	ui.card_index = -1
	ui.refresh()
	await ui.get_tree().process_frame
	if is_instance_valid(ui) and generation == _generation and ui.menu == "game" and ui.state.battle == battle and not is_instance_valid(ui.overlay):
		Feedback.flash(ui, before, after)
