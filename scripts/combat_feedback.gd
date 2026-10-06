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
			if gain > 0: parts.append("Resolve · stun protected" if status == "resolve" else "+%d %s" % [gain, status.capitalize()])
		for status in ["poison", "burn"]:
			if int(actor["hp"]) > 0 and int(old.get("statuses", {}).get(status, 0)) > 0 and int(actor.get("statuses", {}).get(status, 0)) == 0:
				parts.append(status.capitalize() + " cleared")
		if int(actor["hp"]) > 0:
			if int(old.get("statuses", {}).get("resolve", 0)) > 0 and int(actor.get("statuses", {}).get("resolve", 0)) == 0:
				parts.append("Resolve expired")
			var regen: int = int(actor.get("statuses", {}).get("regen", 0))
			if regen < int(old.get("statuses", {}).get("regen", 0)):
				parts.append("Regen now %d" % regen if regen > 0 else "Regen ended")
		if int(old.get("statuses", {}).get("evasion", 0)) > int(actor.get("statuses", {}).get("evasion", 0)) and hp == 0: parts.append("Evaded")
		if int(old["hp"]) > 0 and int(actor["hp"]) <= 0: parts.append("KO")
		if not parts.is_empty(): result[id] = {"name": actor["name"], "text": ", ".join(parts), "hp": hp}
	return result

static func describe(before: Dictionary, after: Dictionary) -> String:
	var lines: Array = []
	# The stored charge is an attack bonus, before Armor, Block and Evade.
	# Lead with its payoff so compact action receipts keep the build visible.
	for payoff in bulwark_payoffs(before, after):
		lines.append("%s: BULWARK +%d attack bonus per hit" % [payoff["name"], payoff["bonus"]])
	var delta = changes(before, after)
	for id in delta: lines.append("%s: %s" % [delta[id]["name"], delta[id]["text"]])
	var old_counts: Dictionary = before.get("trait_state", {}).get("trigger_counts", {})
	var new_counts: Dictionary = after.get("trait_state", {}).get("trigger_counts", {})
	var activations = {"venom_nest": "Venom Nest spreads poison", "spiteful_shields": "Spiteful Shields retaliates", "pack_instinct": "Pack Instinct: +1 energy, draw 1", "war_drums": "War Drums: +1 energy, draw 1"}
	for id in activations:
		var count: int = int(new_counts.get(id, 0)) - int(old_counts.get(id, 0))
		if count > 0: lines.append(activations[id] + (" x%d" % count if count > 1 else ""))
	var old_forms: Dictionary = before.get("form_state", {})
	var new_forms: Dictionary = after.get("form_state", {})
	for id in new_forms:
		var actor: Dictionary = actors(after).get(id, {})
		if actor.get("form", "") not in ["green_ogre", "ancient_ogre"] or int(actor.get("hp", 0)) <= 0: continue
		var was_ready: bool = old_forms.get(id, {}).get("ready", false)
		var now_ready: bool = new_forms[id].get("ready", false)
		if now_ready and not was_ready:
			lines.append("%s protected an ally: Bulwark stored, next attack +%d damage" % [actor.get("name", "Your ogre"), 14 if actor["form"] == "ancient_ogre" else 10])
	return " · ".join(lines) if not lines.is_empty() else "No HP, block or status changed."

static func bulwark_payoffs(before: Dictionary, after: Dictionary) -> Array:
	var result: Array = []
	var old_counts: Dictionary = before.get("recap_state", {}).get("bulwark", {})
	var new_counts: Dictionary = after.get("recap_state", {}).get("bulwark", {})
	for id in new_counts:
		var count: int = int(new_counts[id].get("activations", 0)) - int(old_counts.get(id, {}).get("activations", 0))
		if count <= 0: continue
		var bonus: int = int(new_counts[id].get("bonus_total", 0)) - int(old_counts.get(id, {}).get("bonus_total", 0))
		result.append({"owner": id, "name": new_counts[id].get("name", "Your ogre"), "bonus": int(float(bonus) / float(count))})
	return result

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
		# Floating numbers belong over creature art. Compact actor rows keep
		# their names/HP unobscured and already show written numeric results.
		if not is_instance_valid(ui.battlefield) or not ui.battlefield.creature_nodes.has(id): continue
		var body: Control = ui.battlefield.creature_nodes[id]
		if not is_instance_valid(body): continue
		var area: Rect2 = body.get_global_rect().intersection(Rect2(Vector2.ZERO, ui.size))
		var ancestor: Node = body.get_parent()
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
