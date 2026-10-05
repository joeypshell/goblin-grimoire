extends RefCounted

const CardFace = preload("res://scripts/ui_card.gd")

static func find(node: Node, node_name: String):
	if node.name == node_name: return node
	for child in node.get_children():
		var found = find(child, node_name)
		if found != null: return found
	return null

static func source(ui, index: int) -> Rect2:
	var card = find(ui.root_box, "Card_%d" % index)
	if not is_instance_valid(card): return Rect2()
	var bounds: Rect2 = card.get_global_rect()
	var viewport: Rect2 = ui.get_viewport_rect()
	return bounds.intersection(viewport)

static func discard(ui, ability_id: String, origin: Rect2) -> void:
	if not ui.animations_enabled() or not origin.has_area(): return
	var texture: Texture2D = CardFace.texture_for(ability_id)
	if texture == null: return
	var destination = find(ui.root_box, "DeckCounter")
	if not is_instance_valid(destination): return
	var art = TextureRect.new()
	art.name = "PlayedCard"
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_to_group("combat_callout")
	ui.add_child(art)
	art.size = Vector2(48, 64)
	art.position = origin.get_center() - art.size / 2
	art.pivot_offset = art.size / 2
	var endpoint: Vector2 = destination.get_global_rect().get_center() - art.size / 2
	var tween = art.create_tween().set_parallel(true)
	tween.tween_property(art, "position", endpoint, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(art, "scale", Vector2(0.25, 0.25), 0.35)
	tween.tween_property(art, "modulate:a", 0.0, 0.2).set_delay(0.15)
	tween.chain().tween_callback(art.queue_free)
