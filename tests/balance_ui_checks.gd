extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")

func exercise(t, pixels: Vector2i) -> void:
	var ui = t.ui
	var game = t.game
	# Catalog-only presentation fixture. Real input and campaign checks use their
	# ordinary generated actors, actual draws and random inheritance separately.
	var owner: Dictionary = game.run["monsters"][0]
	var guardian: Dictionary = game.run["monsters"][1]
	owner["form"] = "nightstalker"
	owner["hp"] = 38
	owner["max_hp"] = 38
	guardian["form"] = "ancient_ogre"
	guardian["hp"] = 30
	guardian["max_hp"] = 46
	owner["statuses"] = {}
	owner["status_layers"] = {}
	game.battle._status(owner, "poison", 3)
	game.battle._status(owner, "burn", 2)
	var victim: Dictionary = game.battle.enemies[0]
	victim["statuses"]["resolve"] = 1
	game.battle.hand = [t.fixture_card("snare", owner["id"]), t.fixture_card("mend", owner["id"]), t.fixture_card("nightfall", owner["id"]), t.fixture_card("renewing_aegis", guardian["id"]), t.fixture_card("heavy_blow", owner["id"])]
	game.battle.energy = 3
	ui.card_index = 0
	ui.refresh()
	var before: Dictionary = game.battle.to_dict()
	await t.capture("08_resolve_target")
	t.inspect_cards()
	t.check(Copy.status(victim).contains("stun protected") and Copy.preview(game.battle, game.battle.hand[0], victim).contains("Stun blocked: Resolve"), "Protected target copy names its immunity rather than promising a skipped action")
	t.check(labels(ui).any(func(label_): return label_.text.contains("Resolve")), "Rendered combat exposes Resolve protection")
	ui.card_index = 1
	ui.refresh()
	await t.capture("09_full_hp_mend_cleanse")
	t.inspect_cards()
	var effect = named(ui, "Card_1").find_child("CardEffect", true, false)
	t.check(effect != null and effect.text.contains("Cleanse"), "Illustrated Mend face keeps cleansing utility visible at full HP")
	t.check(Copy.preview(game.battle, game.battle.hand[1], owner).contains("+0 HP") and Copy.preview(game.battle, game.battle.hand[1], owner).contains("Cleanse Poison/Burn"), "Selected full-HP ally still previews removing both harmful applications")
	var night = named(ui, "Card_2")
	var self_effect = night.find_child("CardEffect", true, false)
	t.check(self_effect != null and self_effect.text.contains("Evade"), "Nightfall face exposes its owner's self-benefit along with area damage")
	t.check(t.equal(before, game.battle.to_dict()), "Rendering protected targets, cleanse and evolved cards preserves every combat field/RNG")
	ui.card_index = 2
	ui.refresh()
	await t.settle()
	night = named(ui, "Card_2")
	night.pressed.emit()
	await t.capture("10_nightfall_details")
	t.check(is_instance_valid(ui.overlay), "Second tap opens the actual illustrated card details modal")
	if is_instance_valid(ui.overlay):
		var close = return_button(ui.overlay)
		t.check(close != null, "Card details offer a return-to-targets control")
		if close != null:
			var ancestor = close.get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer:
					ancestor.ensure_control_visible(close)
					await t.settle()
				ancestor = ancestor.get_parent()
			t.check(close.size.y >= 43.9 and Rect2(Vector2.ZERO, Vector2(pixels)).grow(1).encloses(close.get_global_rect()), "Long card details keep a reachable forty-four-pixel return control")
			for label_ in labels(ui.overlay):
				t.check(label_.get_global_rect().position.x >= -1 and label_.get_global_rect().end.x <= pixels.x + 1, "Wrapped card details stay within the logical viewport width")
			close.pressed.emit()
	t.check(not is_instance_valid(ui.overlay) or ui.overlay.is_queued_for_deletion(), "Returning closes card details through the production action")
	t.check(ui.card_index == 2 and t.equal(before, game.battle.to_dict()), "Card details preserve the selected action, complete combat snapshot and RNG")
	ui.card_index = -1
	ui.close_modal()

func named(node: Node, id: String):
	if node.name == id and not node.is_queued_for_deletion(): return node
	for child in node.get_children():
		var found = named(child, id)
		if found != null: return found
	return null

func labels(node: Node) -> Array:
	var result: Array = []
	if node is Label and node.is_visible_in_tree() and not node.is_queued_for_deletion(): result.append(node)
	for child in node.get_children(): result.append_array(labels(child))
	return result

func return_button(node: Node):
	if node is Button and node.text == "Return to targets" and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found = return_button(child)
		if found != null: return found
	return null
