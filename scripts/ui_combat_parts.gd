extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")
var ui

func _init(owner, _combat_screen) -> void:
	ui = owner

func actor(actor: Dictionary, parent: Node, enemy: bool, compact: bool) -> void:
	var battle = ui.combat_battle()
	var selected: Dictionary = battle.hand[ui.card_index] if ui.card_index >= 0 and ui.card_index < battle.hand.size() else {}
	var legal: bool = not ui.resolving_turn and not selected.is_empty() and actor["id"] in battle.legal_targets(selected)
	var owner: bool = not selected.is_empty() and selected["owner"] == actor["id"]
	var acting: bool = actor["id"] == ui.acting_actor_id
	var receiving: bool = actor["id"] in ui.acting_target_ids
	var target = ui.button("", func():
		if legal and not ui.resolving_turn: ui.play_selected_card(actor["id"]))
	target.name = "Actor_" + actor["id"]
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if legal else Control.CURSOR_ARROW
	var fill = Color("374331") if legal else (Color("45432c") if owner or acting else Color("242e26"))
	var border = ui.RED if receiving else (ui.EMBER if acting or owner else (ui.MOSS if legal else Color("46513f")))
	target.add_theme_stylebox_override("normal", ui.style(fill, border, 8))
	parent.add_child(target)
	ui.actor_nodes[actor["id"]] = target
	if int(actor["hp"]) <= 0: target.modulate = Color(0.6, 0.6, 0.6, 0.75)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 5)
	target.add_child(margin)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7 if compact else 10)
	margin.add_child(row)
	row.add_child(ui.portrait(actor, 32 if compact else 52))
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 4)
	text.add_child(heading)
	var name = ui.label(actor["name"], 15 if compact else 17)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(name)
	var health_text: String = "%d/%d HP" % [actor["hp"], actor["max_hp"]]
	if int(actor.get("block", 0)) > 0: health_text += " · %d block" % actor["block"]
	heading.add_child(ui.label(health_text, 12 if compact else 14, ui.MOSS))
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 4
	bar.max_value = actor["max_hp"]
	bar.value = actor["hp"]
	bar.show_percentage = false
	text.add_child(bar)
	var lines: Array = []
	if acting: lines.append("ACTING NOW")
	elif receiving: lines.append("CURRENT TARGET")
	elif owner: lines.append("CARD OWNER · this monster acts")
	if int(actor["hp"]) <= 0:
		lines.append("DEFEATED · cannot act" if enemy else "KNOCKED OUT · its cards are removed")
	elif enemy:
		var action: Dictionary = Copy.intent(battle, actor)
		if acting and ui.turn_kind == "stun": action["line"] = "STUNNED · announced action skipped"
		var prefix: String = "NOW · " if acting else ("DONE · " if actor["id"] in ui.acted_actor_ids else "NEXT · ")
		lines.append(prefix + action["line"])
	else:
		var excluded: Array = ui.acted_actor_ids.duplicate()
		if ui.resolving_turn and ui.turn_kind == "stun": excluded.append(ui.acting_actor_id)
		lines.append("Your " + ui.form_name(actor["form"]) + " · " + Copy.threats(battle, actor["id"], excluded))
	var statuses: String = Copy.status(actor)
	if statuses != "": lines.append(statuses)
	if legal: lines.append("PLAY HERE: " + Copy.preview(battle, selected, actor))
	var detail_text: String = "\n".join(lines)
	var detail = ui.label(detail_text, 12 if compact else 13, ui.MOSS if legal else (ui.EMBER if enemy or acting else ui.MUTED), true)
	text.add_child(detail)
	var width: float = ui.content_width()
	if not compact or not ui.is_portrait(): width = (width - (8 if compact else 18)) / 2.0
	var text_width: float = maxf(80, width - (64 if compact else 84))
	var font: Font = target.get_theme_font("font")
	target.custom_minimum_size.y = maxf(68, font.get_multiline_string_size(detail_text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12 if compact else 13).y + 36)
	target.tooltip_text = detail_text
	_ignore_mouse(margin)
	call_deferred("_queue_actor_fit", target, detail)

func _queue_actor_fit(target, detail) -> void:
	# Check the actual wrapped label once, after nested containers settle.
	if not is_instance_valid(target) or not is_instance_valid(detail) or not target.is_inside_tree(): return
	call_deferred("_fit_actor", target, detail)

func _fit_actor(target, detail) -> void:
	if not is_instance_valid(target) or not is_instance_valid(detail) or not target.is_inside_tree(): return
	var required: float = detail.global_position.y - target.global_position.y + detail.size.y + 5
	target.custom_minimum_size.y = maxf(target.custom_minimum_size.y, ceilf(required))

func card(index: int, parent: Node, compact: bool, portrait: bool = false) -> void:
	var battle = ui.combat_battle()
	var card: Dictionary = battle.hand[index]
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var reason: String = Copy.unavailable(battle, card, ui.resolving_turn)
	var caption: String = "%s\n%s\n%s" % [Copy.owner_name(battle, card), ability["name"], reason]
	if not compact: caption += "\n%d ENERGY · %s\n%s" % [ability["cost"], Copy.target_prompt(ability["target"]), ability["description"]]
	var pick = ui.button(caption, func():
		if ui.resolving_turn: return
		if ui.card_index == index:
			ui.combat_screen.show_card_details(index)
			return
		ui.card_index = index
		ui.combat_screen.compact_side = "monsters" if ability["target"] in ["ally", "all_allies", "self"] else "enemies"
		ui.refresh())
	pick.name = "Card_%d" % index
	pick.custom_minimum_size = Vector2(164, 100 if portrait else 78) if compact else Vector2(0, 140)
	if not compact: pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_theme_font_size_override("font_size", 12 if compact else 14)
	pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick.disabled = reason != ""
	pick.tooltip_text = "%s · %d energy\n%s\n%s" % [Copy.owner_name(battle, card), ability["cost"], ability["description"], reason]
	pick.add_theme_stylebox_override("normal", ui.style(Color("554b32") if index == ui.card_index else Color("313b2e"), ui.EMBER if index == ui.card_index else Color("71805a"), 8))
	parent.add_child(pick)
	if compact:
		# Fixed three-line face: owner, cost/action, effect or disabled reason.
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			pick.add_theme_color_override(state, Color.TRANSPARENT)
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 8)
		pick.add_child(margin)
		var box = VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 3)
		margin.add_child(box)
		var owner_row = HBoxContainer.new()
		box.add_child(owner_row)
		var owner_label = ui.label("Shared dungeon" if card["owner"] == "" else Copy.owner_name(battle, card), 11, ui.MUTED)
		owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		owner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		owner_row.add_child(owner_label)
		owner_row.add_child(ui.label("%d energy" % ability["cost"], 11, ui.EMBER))
		var title = ui.label(ability["name"], 14, ui.PARCHMENT if reason == "" else ui.MUTED)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(title)
		var effect = ui.label(reason if reason != "" else ("Tap again for details" if index == ui.card_index else Copy.card_effect(battle, card)), 11, ui.RED if reason != "" else ui.MOSS)
		effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(effect)
		_ignore_mouse(margin)

func _ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)
