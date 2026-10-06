extends Control

const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Forms = preload("res://scripts/battle_forms.gd")
const Creature = preload("res://scripts/battle_creature.gd")
var ui
var battle
var creature_nodes: Dictionary = {}
var intent_nodes: Dictionary = {}
var target_nodes: Dictionary = {}
var _effects: Array = []
var _effect_layer: Control
var _columns: Array = []
var _minimum_pending := false

func setup(owner, combat) -> void:
	ui = owner
	battle = combat
	name = "Battlefield"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 6)
	add_child(margin)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var defenders: Array = battle.monsters.duplicate()
	defenders.reverse() # Frontline stands closest to the invaders.
	for index in range(defenders.size()): _unit(defenders[index], row, false, index)
	var gap = Control.new()
	gap.custom_minimum_size.x = 32
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	for index in range(battle.enemies.size()): _unit(battle.enemies[index], row, true, index + 3)
	_effect_layer = Control.new()
	_effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.draw.connect(_draw_effects)
	add_child(_effect_layer)
	resized.connect(func():
		queue_redraw()
		_queue_minimum_fit())
	_queue_minimum_fit()

func _queue_minimum_fit() -> void:
	if _minimum_pending: return
	_minimum_pending = true
	call_deferred("_fit_minimum")

func _fit_minimum() -> void:
	_minimum_pending = false
	if not is_inside_tree(): return
	var height: float = 140
	for column in _columns:
		# Intrinsic text and the creature's 60 px minimum, never its allocation.
		height = maxf(height, column.get_combined_minimum_size().y + 20)
	if not is_equal_approx(custom_minimum_size.y, height): custom_minimum_size.y = height

func _unit(actor: Dictionary, parent: Node, enemy: bool, index: int) -> void:
	var selected: Dictionary = battle.hand[ui.card_index] if ui.card_index >= 0 and ui.card_index < battle.hand.size() else {}
	var legal: bool = not ui.resolving_turn and not selected.is_empty() and actor["id"] in battle.legal_targets(selected)
	var owner: bool = not selected.is_empty() and selected["owner"] == actor["id"]
	var acting: bool = actor["id"] == ui.acting_actor_id
	var receiver: bool = actor["id"] in ui.acting_target_ids
	var button = ui.button("", func():
		if legal and not ui.resolving_turn: ui.play_selected_card(actor["id"]))
	button.name = "Actor_" + actor["id"]
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if legal else Control.CURSOR_ARROW
	var line: Color = ui.RED if receiver else (ui.EMBER if owner or acting else (ui.MOSS if legal else Color("465743")))
	var fill: Color = Color(0.13, 0.18, 0.11, 0.55) if legal else Color(0.05, 0.1, 0.07, 0.08)
	button.add_theme_stylebox_override("normal", ui.style(fill, line, 9))
	button.add_theme_stylebox_override("hover", ui.style(Color(0.2, 0.25, 0.14, 0.45), line, 9))
	parent.add_child(button)
	ui.actor_nodes[actor["id"]] = button
	target_nodes[actor["id"]] = button
	var inset = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 4)
	button.add_child(inset)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	inset.add_child(column)
	_columns.append(column)
	var role: String = ""
	if acting: role = "ACTING"
	elif receiver: role = "TARGET"
	elif owner: role = "OWNER"
	elif legal: role = "PLAY HERE"
	var name_label = ui.label(actor["name"] + (" · " + role if role != "" else ""), 14, ui.EMBER if acting or owner else (ui.MOSS if legal else ui.PARCHMENT))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	var hp_text: String = "%d/%d HP" % [actor["hp"], actor["max_hp"]]
	var full_preview: String = Copy.preview(battle, selected, actor) if legal else ""
	if legal: hp_text += " · " + _short_preview(full_preview)
	var hp = ui.label(hp_text, 11, ui.MOSS)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(hp)
	var health = ProgressBar.new()
	health.custom_minimum_size.y = 4
	health.max_value = actor["max_hp"]
	health.value = actor["hp"]
	health.show_percentage = false
	column.add_child(health)
	var defenses = ui.label(Copy.defenses(actor), 11, ui.PARCHMENT)
	defenses.name = "Defense_" + actor["id"]
	defenses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(defenses)
	var body = Creature.new()
	body.name = "Creature_" + actor["id"]
	body.ui = ui
	body.actor_id = actor["id"]
	body.form = actor["form"]
	body.dead = int(actor["hp"]) <= 0
	body.facing = -1.0 if enemy else 1.0
	body.idle_phase = float(index) * 0.9
	body.custom_minimum_size = Vector2(0, 60)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	creature_nodes[actor["id"]] = body
	if body.dead: body.modulate = Color(0.58, 0.62, 0.59, 0.75)
	var text: String = ui.form_name(actor["form"])
	if body.dead: text = "DEFEATED" if enemy else "KNOCKED OUT"
	elif enemy:
		text = Copy.intent(battle, actor)["line"]
		if acting and ui.turn_kind == "stun": text = "STUNNED · action skipped"
		elif actor["id"] in ui.acted_actor_ids: text = "DONE · " + text
	# Keep the actor's numeric action readable; the full-width battle counter
	# carries the Captain's countdown/counterplay without shrinking its creature.
	var caption: String = text.split("\n")[0]
	var intent = ui.label(caption, 11, ui.EMBER if enemy else ui.MUTED, true)
	intent.name = "Intent_" + actor["id"]
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(intent)
	intent_nodes[actor["id"]] = intent
	var form_hint: String = Forms.status(battle, actor) if not enemy else ""
	if form_hint != "":
		var combo = ui.label(form_hint, 10, ui.MOSS, true)
		combo.name = "FormCombo_" + actor["id"]
		combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(combo)
	var statuses: String = Copy.status(actor)
	if statuses != "":
		var status = ui.label(statuses, 10, ui.PARCHMENT, true)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(status)
	if legal:
		button.tooltip_text = "Play %s on %s\n%s\n%s" % [Data.ABILITIES[selected["ability"]]["name"], actor["name"], full_preview, text]
	else: button.tooltip_text = text + ("\n" + statuses if statuses != "" else "")
	if form_hint != "": button.tooltip_text += "\n" + form_hint
	_ignore_mouse(inset)

func _short_preview(full: String) -> String:
	var first: String = full.split(", ")[0]
	if first.contains("HP lost"):
		return "-%s HP" % first.split(": ")[1].split(" HP lost")[0]
	if first.begins_with("Evades"): return "Evades hit"
	return first

func _ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)

func _draw() -> void:
	var floor_y: float = size.y * 0.68
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.12, 0.09, 0.38))
	draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color("48583e"), 1)
	for index in range(9):
		var x: float = size.x * float(index) / 8.0
		draw_line(Vector2(size.x / 2, floor_y), Vector2(x, size.y), Color(0.26, 0.32, 0.22, 0.27), 1)
	for value in [0.78, 0.94]: draw_line(Vector2(0, size.y * value), Vector2(size.x, size.y * value), Color(0.28, 0.33, 0.23, 0.25), 1)
	var center: Vector2 = Vector2(size.x / 2, floor_y - 8)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -15), center + Vector2(10, 0), center + Vector2(0, 16), center + Vector2(-10, 0)]), Color("bd9860"))
	draw_arc(center, 22, 0, TAU, 32, Color("7d805a"), 1.0, true)

func present_action(actor_id: String, target_ids: Array, ability_id: String, before: Dictionary, after: Dictionary) -> void:
	if ui == null or not ui.animations_enabled(): return
	var ability: Dictionary = Data.ABILITIES.get(ability_id, {})
	var affinity: String = ability.get("affinity", "Neutral")
	var ranged: bool = affinity in ["Flame", "Mystic", "Control", "Venom"]
	if creature_nodes.has(actor_id): creature_nodes[actor_id].attack(ranged)
	var origin: Vector2 = _body_center(actor_id) if creature_nodes.has(actor_id) else Vector2(size.x / 2, size.y * 0.5)
	var color: Color = {"Flame": Color("ed9656"), "Mystic": Color("b6a7e8"), "Venom": Color("b8cf73"), "Control": Color("b4c9df"), "Vitality": Color("b9db8d"), "Guard": Color("a6c9d8")}.get(affinity, Color("ecd4a3"))
	for id in target_ids:
		if not creature_nodes.has(id): continue
		var old: Dictionary = _snapshot_actor(before, id)
		var current: Dictionary = _snapshot_actor(after, id)
		var kind: String = "status"
		if int(current.get("hp", 0)) < int(old.get("hp", 0)): kind = "hit"
		elif int(current.get("hp", 0)) > int(old.get("hp", 0)): kind = "heal"
		elif int(current.get("block", 0)) != int(old.get("block", 0)): kind = "shield"
		creature_nodes[id].react(kind)
		var destination: Vector2 = _body_center(id)
		if ranged and id != actor_id: _effects.append({"kind": "projectile", "from": origin, "to": destination, "color": color, "age": 0.0, "duration": 0.38})
		_effects.append({"kind": kind, "from": destination, "to": destination, "color": color, "age": -0.12 if ranged else 0.0, "duration": 0.55})
	_effect_layer.queue_redraw()

func _snapshot_actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor in snapshot.get("monster_combat", []) + snapshot.get("enemies", []):
		if actor["id"] == id: return actor
	return {}

func _body_center(id: String) -> Vector2:
	var body = creature_nodes[id]
	return body.global_position + body.size * Vector2(0.5, 0.55) - global_position

func _process(delta: float) -> void:
	if ui == null or not ui.animations_enabled():
		_effects.clear()
	else:
		for effect in _effects: effect["age"] += delta
		for index in range(_effects.size() - 1, -1, -1):
			if _effects[index]["age"] > _effects[index]["duration"]: _effects.remove_at(index)
	if _effect_layer != null: _effect_layer.queue_redraw()

func _draw_effects() -> void:
	for effect in _effects:
		if effect["age"] < 0: continue
		var progress: float = clampf(effect["age"] / effect["duration"], 0, 1)
		var color: Color = effect["color"]
		color.a = 1.0 - progress
		if effect["kind"] == "projectile":
			var point: Vector2 = effect["from"].lerp(effect["to"], progress)
			_effect_layer.draw_line(point, point.lerp(effect["from"], 0.08), color, 3, true)
			_effect_layer.draw_circle(point, 5, color)
		elif effect["kind"] == "hit":
			for index in range(7):
				var angle: float = float(index) * TAU / 7.0
				var ray: Vector2 = Vector2(cos(angle), sin(angle))
				_effect_layer.draw_line(effect["to"] + ray * (8 + 16 * progress), effect["to"] + ray * (16 + 22 * progress), color, 2, true)
		else:
			_effect_layer.draw_arc(effect["to"], 13 + progress * 20, 0, TAU, 28, color, 2.0, true)
			if effect["kind"] == "heal":
				var point: Vector2 = effect["to"] + Vector2(0, -progress * 18)
				_effect_layer.draw_line(point - Vector2(5, 0), point + Vector2(5, 0), color, 2)
				_effect_layer.draw_line(point - Vector2(0, 5), point + Vector2(0, 5), color, 2)
