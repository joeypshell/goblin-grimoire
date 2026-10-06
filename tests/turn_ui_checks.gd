extends RefCounted

# Deliberate end-turn tests use the same warning and confirm control as players.
static func request_and_confirm(test, ui) -> void:
	var remaining: int = ui.state.battle.energy
	var before: Dictionary = ui.state.battle.to_dict()
	ui.end_player_turn()
	if remaining <= 0:
		test.check(not is_instance_valid(ui.overlay), "A deliberately exhausted turn needs no unspent-energy warning")
		return
	var warning = named(ui, "EndTurnWarning")
	var confirm = named(ui, "EndTurnAnyway")
	test.check(warning != null and confirm is Button and not confirm.disabled, "Ending with unspent energy requires the production warning and explicit confirmation")
	test.check(not ui.resolving_turn and JSON.stringify(before) == JSON.stringify(ui.state.battle.to_dict()), "An unconfirmed warning preserves the authoritative battle and its RNG")
	if confirm != null: confirm.pressed.emit()

static func named(node: Node, id: String):
	if node.is_queued_for_deletion(): return null
	if str(node.name) == id and (not node is Control or node.is_visible_in_tree()): return node
	for child in node.get_children():
		var found = named(child, id)
		if found != null: return found
	return null

static func visible_text(node: Node) -> String:
	if node.is_queued_for_deletion() or (node is Control and not node.is_visible_in_tree()): return ""
	var text: String = node.text + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): text += visible_text(child)
	return text
