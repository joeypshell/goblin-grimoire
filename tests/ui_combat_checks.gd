extends RefCounted

const Data = preload("res://scripts/game_data.gd")

static func defenses(t, ui) -> void:
	# Portrait views intentionally show only one faction or the acting pair.
	# Every actor actually rendered must expose both defenses independently.
	for id in ui.actor_nodes:
		var control = ui.actor_nodes[id]
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		var actor: Dictionary = ui.combat_battle().get_actor(id)
		var label_ = control.find_child("Defense_" + id, true, false)
		t.check(label_ != null and label_.is_visible_in_tree(), "Displayed actor exposes permanent armor and temporary block: " + id)
		if label_ == null: continue
		t.check(label_.text.contains("Armor %d" % Data.armor(actor)) and label_.text.contains("Block %d" % int(actor.get("block", 0))), "Defense labels match current actor armor and block independently: " + id)
		t.check(control.get_global_rect().grow(1).encloses(label_.get_global_rect()), "Actor contains the armor/block label: " + id)
