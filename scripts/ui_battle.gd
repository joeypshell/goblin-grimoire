extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui

func _init(owner) -> void:
	ui = owner

func render() -> void:
	var battle = ui.state.battle
	ui.content.add_theme_constant_override("separation", 10)
	var top = HBoxContainer.new()
	ui.content.add_child(top)
	var heading = ui.label("Defend the core", 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(ui.label("TURN " + str(battle.turn), 16, ui.MUTED))
	top.add_child(ui.label("   ENERGY  " + str(battle.energy) + " / " + str(Data.BALANCE["energy"]), 21, ui.EMBER))
	top.add_child(ui.label("   DRAW " + str(battle.draw_pile.size()) + "   DISCARD " + str(battle.discard.size()), 13, ui.MUTED))
	var board = HBoxContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 18)
	ui.content.add_child(board)
	var monsters = VBoxContainer.new()
	monsters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	monsters.add_theme_constant_override("separation", 6)
	board.add_child(monsters)
	monsters.add_child(ui.label("YOUR MONSTERS  /  CARD OWNERS", 14, ui.MOSS))
	for actor in battle.monsters:
		_actor(actor, monsters, false)
	var enemies = VBoxContainer.new()
	enemies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemies.add_theme_constant_override("separation", 6)
	board.add_child(enemies)
	enemies.add_child(ui.label("ADVENTURERS  /  LOCKED INTENTIONS", 14, ui.EMBER))
	for actor in battle.enemies:
		_actor(actor, enemies, true)
	var selection = HBoxContainer.new()
	ui.content.add_child(selection)
	var message = "Choose a card below. Enemy intentions stay fixed for this turn."
	if ui.card_index >= 0 and ui.card_index < battle.hand.size():
		var card = battle.hand[ui.card_index]
		message = battle.card_name(card) + "  ·  Select a highlighted target. " + Data.ABILITIES[card["ability"]]["description"]
	var instruction = ui.label(message, 15, ui.EMBER if ui.card_index >= 0 else ui.MUTED, true)
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.add_child(instruction)
	if ui.card_index >= 0:
		selection.add_child(ui.button("Cancel", func():
			ui.card_index = -1
			ui.refresh()))
	var hand = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 10)
	ui.content.add_child(hand)
	for index in range(battle.hand.size()):
		_card(index, hand)
	if battle.hand.is_empty():
		hand.add_child(ui.label("No cards remain in hand. End the turn to draw again.", 17, ui.MUTED))
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	ui.content.add_child(bottom)
	var summary = VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(summary)
	var recent = ""
	if not battle.log.is_empty(): recent = battle.log[-1]
	summary.add_child(ui.label(recent, 13, ui.MOSS, true))
	summary.add_child(ui.label("Block clears at your faction's next turn. Poison, burn and regeneration tick at the end of the affected faction's turn, then decay by 1.", 11, ui.MUTED, true))
	var log_button = ui.button("Battle log", _show_log)
	bottom.add_child(log_button)
	var end = ui.primary("End turn  [Space]", func(): ui.act(ui.state.end_turn, "The adventurers resolve their announced actions."), 190)
	end.tooltip_text = "Resolve surviving enemies' locked intentions, then draw a new hand. A dead frontline target redirects to the first living monster."
	bottom.add_child(end)

func _actor(actor: Dictionary, parent: Node, enemy: bool) -> void:
	var battle = ui.state.battle
	var legal = false
	var selected_owner = false
	var preview = ""
	if ui.card_index >= 0 and ui.card_index < battle.hand.size():
		var card = battle.hand[ui.card_index]
		legal = actor["id"] in battle.legal_targets(card)
		selected_owner = card["owner"] == actor["id"]
		if legal: preview = battle.preview(card, actor["id"])
	var target = ui.button("", func():
		if legal:
			var card_name = battle.card_name(battle.hand[ui.card_index])
			ui.act(func(): ui.state.play_card(ui.card_index, actor["id"]), card_name + " on " + actor["name"]))
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target.custom_minimum_size.y = 76
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if legal else Control.CURSOR_ARROW
	if legal:
		target.add_theme_stylebox_override("normal", ui.style(Color("374331"), ui.MOSS, 10))
	elif selected_owner:
		target.add_theme_stylebox_override("normal", ui.style(Color("393d2e"), ui.EMBER, 10))
	else:
		target.add_theme_stylebox_override("normal", ui.style(Color("242e26"), Color("46513f"), 10))
	if actor["hp"] <= 0:
		target.modulate = Color(0.6, 0.6, 0.6, 0.75)
	parent.add_child(target)
	ui.actor_nodes[actor["id"]] = target
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(margin)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	row.add_child(ui.portrait(actor, 56))
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var heading = HBoxContainer.new()
	text.add_child(heading)
	heading.add_child(ui.label(actor["name"], 17, ui.PARCHMENT))
	var form = ui.label("  " + (actor["class_name"] if enemy else ui.form_name(actor["form"])), 12, ui.MUTED)
	heading.add_child(form)
	var status_tags = _status(actor)
	if status_tags != "":
		var tags = ui.label("  " + status_tags, 11, ui.EMBER)
		tags.tooltip_text = status_tags
		heading.add_child(tags)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var health_text = str(actor["hp"]) + " / " + str(actor["max_hp"]) + " HP"
	if actor.get("block", 0) > 0: health_text += "  " + str(actor["block"]) + " block"
	heading.add_child(ui.label(health_text, 13, ui.MOSS))
	var health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 5
	health_bar.max_value = actor["max_hp"]
	health_bar.value = actor["hp"]
	health_bar.show_percentage = false
	text.add_child(health_bar)
	var status = _status(actor)
	if actor["hp"] <= 0:
		status = "DEFEATED" if enemy else "KNOCKED OUT · owned cards removed"
	elif enemy:
		for intent in battle.intents:
			if intent["enemy_id"] == actor["id"]:
				status = intent["text"] + ("  /  " + status if status != "" else "")
	else:
		if status == "": status = "Frontline" if actor == battle.monsters[0] else "Ready"
	var short_preview = preview
	if legal:
		for preview_line in preview.split("\n"):
			if preview_line.begins_with(actor["name"] + ":"):
				short_preview = preview_line.trim_prefix(actor["name"] + ": ")
				break
	var detail = ui.label(short_preview if legal else status, 12, ui.MOSS if legal else ui.MUTED, true)
	detail.max_lines_visible = 1
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(detail)
	target.tooltip_text = preview if legal else (status + "\nIf an announced frontline target falls, the action redirects to the first living monster.")
	_ignore_mouse(margin)

func _ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)

func _status(actor: Dictionary) -> String:
	var tags: Array = []
	for key in actor.get("statuses", {}):
		if actor["statuses"][key] > 0:
			tags.append(key.capitalize() + " " + str(actor["statuses"][key]))
	return " · ".join(tags)

func _card(index: int, parent: Node) -> void:
	var battle = ui.state.battle
	var card = battle.hand[index]
	var ability = Data.ABILITIES[card["ability"]]
	var owner = "DUNGEON"
	if card["owner"] != "": owner = battle.get_actor(card["owner"])["name"].to_upper()
	var content = owner + "  ·  " + str(ability["cost"]) + " ENERGY\n\n" + ability["name"] + "\n" + ability["description"]
	var pick = ui.button(content, func():
		ui.card_index = index
		ui.refresh())
	pick.custom_minimum_size = Vector2(0, 148)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_theme_font_size_override("font_size", 14)
	pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick.disabled = ability["cost"] > battle.energy or battle.legal_targets(card).is_empty()
	pick.tooltip_text = "Owner: " + owner + "\n" + ability["description"] + "\nTarget: " + ability["target"].replace("_", " ")
	if card["owner"] != "" and battle.get_actor(card["owner"]).get("statuses", {}).get("stun", 0) > 0:
		pick.text = "STUNNED  ·  " + content
		pick.tooltip_text = "This owner is stunned and cannot play owned cards this turn."
	if index == ui.card_index:
		pick.add_theme_stylebox_override("normal", ui.style(Color("554b32"), ui.EMBER, 10))
	else:
		pick.add_theme_stylebox_override("normal", ui.style(Color("313b2e"), Color("71805a"), 10))
	parent.add_child(pick)

func _show_log() -> void:
	var box = ui.open_modal()
	box.custom_minimum_size.y = 420
	box.add_child(ui.label("The chamber's record", 25, ui.EMBER))
	var history = ui.scroll(box)
	for entry in ui.state.battle.log:
		history.add_child(ui.label(entry, 14, ui.PARCHMENT, true))
	box.add_child(ui.button("Return to battle", ui.close_modal))
