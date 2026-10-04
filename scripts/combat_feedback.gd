extends RefCounted

static func actors(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for actor in snapshot.get("monster_combat", []) + snapshot.get("enemies", []): result[actor["id"]] = actor
	return result

static func changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var previous = actors(before)
	var current = actors(after)
	var result: Dictionary = {}
	for id in current:
		var actor: Dictionary = current[id]
		if not previous.has(id): continue
		var old: Dictionary = previous[id]
		var parts: Array = []
		var hp: int = int(actor["hp"]) - int(old["hp"])
		var block: int = int(actor.get("block", 0)) - int(old.get("block", 0))
		if hp != 0: parts.append("%+d HP" % hp)
		if block != 0: parts.append("%+d block" % block)
		for status in actor.get("statuses", {}):
			var gain: int = int(actor["statuses"][status]) - int(old.get("statuses", {}).get(status, 0))
			if gain > 0: parts.append("+%d %s" % [gain, status.capitalize()])
		if int(old.get("statuses", {}).get("evasion", 0)) > int(actor.get("statuses", {}).get("evasion", 0)) and hp == 0: parts.append("Evaded")
		if int(old["hp"]) > 0 and int(actor["hp"]) <= 0: parts.append("KO")
		if not parts.is_empty(): result[id] = {"name": actor["name"], "text": ", ".join(parts), "hp": hp}
	return result

static func describe(before: Dictionary, after: Dictionary) -> String:
	var lines: Array = []
	var delta = changes(before, after)
	for id in delta: lines.append("%s: %s" % [delta[id]["name"], delta[id]["text"]])
	return " · ".join(lines) if not lines.is_empty() else "No HP or block changed."

static func clear(ui) -> void:
	for child in ui.get_children():
		if child.is_in_group("combat_callout"):
			ui.remove_child(child)
			child.queue_free()

static func flash(ui, before: Dictionary, after: Dictionary) -> void:
	var delta = changes(before, after)
	for id in delta:
		if not ui.actor_nodes.has(id): continue
		var actor_node: Control = ui.actor_nodes[id]
		var color: Color = ui.RED if int(delta[id]["hp"]) < 0 else ui.MOSS
		actor_node.modulate = color
		actor_node.create_tween().tween_property(actor_node, "modulate", Color.WHITE, 0.5)
		var area: Rect2 = actor_node.get_global_rect().intersection(Rect2(Vector2.ZERO, ui.size))
		var ancestor: Node = actor_node.get_parent()
		while ancestor != null and ancestor != ui:
			if ancestor is ScrollContainer: area = area.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if area.size.x < 80 or area.size.y < 32: continue
		var width: float = minf(240, area.size.x - 12)
		var height: float = ui.theme.default_font.get_multiline_string_size(delta[id]["text"], HORIZONTAL_ALIGNMENT_LEFT, width, 18).y
		if height + 12 > area.size.y: continue
		var callout: Label = ui.label(delta[id]["text"], 18, color, true)
		callout.size = Vector2(width, height)
		callout.add_to_group("combat_callout")
		callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		callout.add_theme_color_override("font_shadow_color", Color.BLACK)
		callout.add_theme_constant_override("shadow_offset_x", 1)
		callout.add_theme_constant_override("shadow_offset_y", 1)
		ui.add_child(callout)
		callout.position = Vector2(area.end.x - width - 6, area.position.y + 6)
		var tween = callout.create_tween()
		tween.tween_interval(0.45)
		tween.tween_property(callout, "modulate:a", 0.0, 0.3)
		tween.tween_callback(callout.queue_free)
