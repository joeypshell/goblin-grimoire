extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui
var compact_side: String = "enemies"
var compact_battle
var compact_selected_id: String = ""

func _init(owner) -> void:
	ui = owner

func render() -> void:
	if ui.is_compact():
		_render_compact()
		return
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
	pick.name = "Card_%d" % index
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
	box.custom_minimum_size.y = minf(420, ui.get_viewport_rect().size.y - 70)
	box.add_child(ui.label("The chamber's record", 21 if ui.is_compact() else 25, ui.EMBER))
	var history = ui.scroll(box)
	for entry in ui.state.battle.log:
		history.add_child(ui.label(entry, 14, ui.PARCHMENT, true))
	history.add_child(ui.label("Block expires at the start of its faction's turn. Poison, burning and regeneration tick at that faction's turn end, then decay by 1. A defeated frontline target redirects to the first living monster.", 13, ui.MUTED, true))
	box.add_child(ui.button("Return to battle", ui.close_modal))

func _render_compact() -> void:
	var battle = ui.state.battle
	if compact_battle != battle:
		compact_battle = battle
		compact_side = "enemies"
		compact_selected_id = ""
	if ui.card_index >= 0 and ui.card_index < battle.hand.size():
		var selected_card: Dictionary = battle.hand[ui.card_index]
		if compact_selected_id != selected_card["id"]:
			compact_selected_id = selected_card["id"]
			compact_side = "monsters" if Data.ABILITIES[selected_card["ability"]]["target"] in ["ally", "all_allies", "self"] else "enemies"
	else:
		compact_selected_id = ""
	var portrait: bool = ui.is_portrait()
	var short_landscape: bool = not portrait and ui.get_viewport_rect().size.y < 360
	ui.content.add_theme_constant_override("separation", 5)
	var layout: VBoxContainer = ui.content
	var body_scroll: ScrollContainer
	if short_landscape:
		body_scroll = ScrollContainer.new()
		body_scroll.name = "CombatBodyScroll"
		body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ui.content.add_child(body_scroll)
		layout = VBoxContainer.new()
		layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layout.add_theme_constant_override("separation", 5)
		body_scroll.add_child(layout)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	layout.add_child(top)
	top.add_child(ui.label("TURN %d" % battle.turn, 13, ui.MUTED))
	var energy = ui.label("ENERGY %d / %d" % [battle.energy, Data.BALANCE["energy"]], 16, ui.EMBER)
	energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(energy)
	top.add_child(ui.label("Draw %d · Discard %d" % [battle.draw_pile.size(), battle.discard.size()], 12, ui.MUTED))
	if portrait:
		var tabs = HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 5)
		layout.add_child(tabs)
		_side_tab(tabs, "monsters", battle.monsters)
		_side_tab(tabs, "enemies", battle.enemies)
		var active_group: Array = battle.monsters if compact_side == "monsters" else battle.enemies
		var actor_scroll = _actor_scroll(layout, 132)
		for actor in active_group:
			_compact_actor(actor, actor_scroll, compact_side == "enemies")
	else:
		var board = HBoxContainer.new()
		board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board.add_theme_constant_override("separation", 8)
		layout.add_child(board)
		for side in ["monsters", "enemies"]:
			var column = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_theme_constant_override("separation", 3)
			board.add_child(column)
			column.add_child(ui.label("MONSTERS · CARD OWNERS" if side == "monsters" else "INVADERS · LOCKED INTENTIONS", 12, ui.MOSS if side == "monsters" else ui.EMBER))
			var actors = _actor_scroll(column, 100 if short_landscape else 34)
			for actor in battle.monsters if side == "monsters" else battle.enemies:
				_compact_actor(actor, actors, side == "enemies")
	_compact_instruction(layout)
	var card_scroll = ScrollContainer.new()
	card_scroll.name = "HandScroll"
	card_scroll.custom_minimum_size.y = 110 if portrait else 88
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(card_scroll)
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	card_scroll.add_child(cards)
	for index in range(battle.hand.size()):
		_compact_card(index, cards, portrait)
	if battle.hand.is_empty():
		cards.add_child(ui.label("No cards remain. End turn to draw again.", 13, ui.MUTED))
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	ui.content.add_child(bottom)
	var log_button = ui.button("Log & rules", _show_log)
	log_button.custom_minimum_size.y = 44
	log_button.add_theme_font_size_override("font_size", 13)
	bottom.add_child(log_button)
	var end = ui.primary("End turn", func(): ui.act(ui.state.end_turn, "The adventurers resolve their announced actions."))
	end.name = "EndTurn"
	end.custom_minimum_size.y = 44
	end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end.tooltip_text = "Discard unused cards, resolve the locked intentions, then draw a new hand."
	bottom.add_child(end)
	if short_landscape and ui.card_index >= 0:
		call_deferred("_queue_short_focus", body_scroll)

func _queue_short_focus(body_scroll: ScrollContainer) -> void:
	# Root restores scroll offsets after render; this second deferred step runs afterward.
	call_deferred("_focus_short_targets", body_scroll)

func _focus_short_targets(body_scroll: ScrollContainer) -> void:
	if is_instance_valid(body_scroll) and body_scroll.is_inside_tree():
		body_scroll.scroll_vertical = 0

func _side_tab(parent: Node, side: String, actors: Array) -> void:
	var living: int = 0
	var hp: int = 0
	var max_hp: int = 0
	for actor in actors:
		if actor["hp"] > 0: living += 1
		hp += int(actor["hp"])
		max_hp += int(actor["max_hp"])
	var caption = ("Monsters" if side == "monsters" else "Invaders") + " %d · HP %d/%d" % [living, hp, max_hp]
	var tab = ui.button(caption, func():
		compact_side = side
		ui.refresh())
	tab.name = "Side_" + side
	tab.custom_minimum_size.y = 44
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_font_size_override("font_size", 12)
	if side == compact_side:
		tab.add_theme_stylebox_override("normal", ui.style(Color("454732"), ui.EMBER, 8))
	parent.add_child(tab)

func _actor_scroll(parent: Node, minimum_height: float) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.custom_minimum_size.y = minimum_height
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var actors = VBoxContainer.new()
	actors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actors.add_theme_constant_override("separation", 5)
	sc.add_child(actors)
	return actors

func _compact_instruction(parent: Node) -> void:
	var battle = ui.state.battle
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var sc = ScrollContainer.new()
	sc.custom_minimum_size.y = 44
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	var message: String = "Swipe the cards. Tap a card, then a highlighted target."
	if not ui.is_portrait() and ui.get_viewport_rect().size.y < 360:
		message = "Scroll down for cards. Tap one; its targets appear above."
	if ui.card_index >= 0 and ui.card_index < battle.hand.size():
		var card: Dictionary = battle.hand[ui.card_index]
		message = "%s · %d energy. %s Tap a highlighted target to play." % [battle.card_name(card), Data.ABILITIES[card["ability"]]["cost"], Data.ABILITIES[card["ability"]]["description"]]
	var explanation = ui.label(message, 13, ui.EMBER if ui.card_index >= 0 else ui.MUTED, true)
	explanation.name = "CardExplanation"
	sc.add_child(explanation)
	if ui.card_index >= 0:
		var cancel = ui.button("Cancel", func():
			ui.card_index = -1
			ui.refresh())
		cancel.custom_minimum_size.y = 44
		cancel.add_theme_font_size_override("font_size", 13)
		row.add_child(cancel)

func _compact_actor(actor: Dictionary, parent: Node, enemy: bool) -> void:
	var battle = ui.state.battle
	var legal: bool = false
	var owner: bool = false
	var preview: String = ""
	if ui.card_index >= 0 and ui.card_index < battle.hand.size():
		var card: Dictionary = battle.hand[ui.card_index]
		legal = actor["id"] in battle.legal_targets(card)
		owner = card["owner"] == actor["id"]
		if legal:
			var full_preview: String = battle.preview(card, actor["id"])
			for line in full_preview.split("\n"):
				if line.begins_with(actor["name"] + ":"):
					preview = line.trim_prefix(actor["name"] + ": ")
				elif line.begins_with("Kindling") or line.begins_with("Volatile venom"):
					preview += " · " + line
	var target = ui.button("", func():
		if legal:
			var name = battle.card_name(battle.hand[ui.card_index])
			ui.act(func(): ui.state.play_card(ui.card_index, actor["id"]), name + " on " + actor["name"]))
	target.name = "Actor_" + actor["id"]
	target.custom_minimum_size.y = 76 if legal else 66
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if legal else Control.CURSOR_ARROW
	var fill = Color("374331") if legal else (Color("393d2e") if owner else Color("242e26"))
	target.add_theme_stylebox_override("normal", ui.style(fill, ui.MOSS if legal else (ui.EMBER if owner else Color("46513f")), 8))
	parent.add_child(target)
	ui.actor_nodes[actor["id"]] = target
	if actor["hp"] <= 0: target.modulate = Color(0.6, 0.6, 0.6, 0.75)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 5)
	target.add_child(margin)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	row.add_child(ui.portrait(actor, 32))
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 4)
	text.add_child(heading)
	var name = ui.label(actor["name"], 15)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(name)
	var health_text: String = "%d/%d HP" % [actor["hp"], actor["max_hp"]]
	if actor.get("block", 0) > 0: health_text += " · %d block" % actor["block"]
	heading.add_child(ui.label(health_text, 12, ui.MOSS))
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 3
	bar.max_value = actor["max_hp"]
	bar.value = actor["hp"]
	bar.show_percentage = false
	text.add_child(bar)
	var status: String = _status(actor)
	var detail: String = ui.form_name(actor["form"]) if not enemy else actor["class_name"].capitalize()
	if actor["hp"] <= 0:
		detail += " · Defeated" if enemy else " · KO: owned cards removed"
	elif enemy:
		for intent in battle.intents:
			if intent["enemy_id"] == actor["id"]: detail += " · " + intent["text"]
	else:
		for ally in battle.monsters:
			if ally["hp"] > 0:
				if ally["id"] == actor["id"]: detail += " · Frontline"
				break
	if status != "": detail += "\n" + status
	if legal: detail += "\nPLAY: " + preview
	text.add_child(ui.label(detail, 12, ui.MOSS if legal else ui.MUTED, true))
	# Measure against the known faction width, avoiding a resize/minimum-size feedback loop.
	var faction_width: float = ui.content_width() if ui.is_portrait() else (ui.content_width() - 8) / 2.0
	var text_width: float = maxf(80, faction_width - 64)
	var font: Font = target.get_theme_font("font")
	var detail_height: float = font.get_multiline_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12).y
	target.custom_minimum_size.y = maxf(66, detail_height + 40)
	_ignore_mouse(margin)

func _compact_card(index: int, parent: Node, portrait: bool) -> void:
	var battle = ui.state.battle
	var card: Dictionary = battle.hand[index]
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var owner: String = "DUNGEON" if card["owner"] == "" else battle.get_actor(card["owner"])["name"].to_upper()
	var caption: String = "%s · %d ENERGY\n%s" % [owner, ability["cost"], ability["name"]]
	var pick = ui.button(caption, func():
		ui.card_index = index
		compact_side = "monsters" if ability["target"] in ["ally", "all_allies", "self"] else "enemies"
		ui.refresh())
	pick.name = "Card_%d" % index
	pick.custom_minimum_size = Vector2(154, 100 if portrait else 78)
	pick.add_theme_font_size_override("font_size", 14)
	pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick.disabled = ability["cost"] > battle.energy or battle.legal_targets(card).is_empty()
	if card["owner"] != "" and battle.get_actor(card["owner"]).get("statuses", {}).get("stun", 0) > 0:
		pick.text = "STUNNED\n" + caption
	pick.tooltip_text = "Owner: %s\n%s" % [owner, ability["description"]]
	pick.add_theme_stylebox_override("normal", ui.style(Color("554b32") if index == ui.card_index else Color("313b2e"), ui.EMBER if index == ui.card_index else Color("71805a"), 8))
	parent.add_child(pick)
