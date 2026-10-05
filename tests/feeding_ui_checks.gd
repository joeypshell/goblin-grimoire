extends RefCounted

const Data = preload("res://scripts/game_data.gd")

func exercise(t) -> Dictionary:
	var ui = t.ui
	var game = t.game
	# The actual mage corpse has two unknown skills with different weights.
	ui.feed_body = 1
	ui.refresh()
	await t.capture("07_feeding")
	var recipient: Dictionary = game.run["monsters"][0]
	var corpse: Dictionary = game.run["rewards"][1]
	var before: Dictionary = game.run.duplicate(true)
	var random_before: int = game.rng.state
	var options: Array = game.inheritance_outcomes(1, recipient["id"])
	t.check(not options.is_empty(), "Selected corpse and recipient expose eligible random outcomes")
	for option in options:
		var label_ = ui.find_child("InheritanceChance_" + option["ability"], true, false)
		t.check(label_ is Label and not label_ is BaseButton, "Inheritance odds are read-only text rather than an ability choice")
		if label_ != null:
			t.check(label_.text.contains(Data.ABILITIES[option["ability"]]["name"]) and label_.text.contains("%.1f%%" % (float(option["chance"]) * 100)) and label_.text.to_lower().contains(option["rarity"]), "Visible inheritance odds show the actual ability, weighted percentage and rarity")
	t.check(JSON.stringify(before) == JSON.stringify(game.run) and random_before == game.rng.state, "Rendering random outcomes does not roll or modify the run")
	await t.reachable_button("Devour", true)
	await t.capture("07a_devour_chances")
	var devour = t.find_button(ui, "Devour")
	if devour != null:
		devour.pressed.emit()
		await t.settle()
	t.check(corpse["claimed"] and options.any(func(option): return option["ability"] == corpse.get("taken", "")), "Reachable Devour control claims its actual corpse with one eligible random result")
	var result = ui.find_child("InheritedResult", true, false)
	t.check(result is Label, "Feeding displays a persistent inheritance result")
	if result != null:
		t.check(result.text.contains(recipient["name"]) and result.text.contains(corpse["name"]) and result.text.contains(Data.ABILITIES[corpse["taken"]]["name"]), "Readable result identifies the recipient, corpse and rolled ability")
		t.check(Rect2(Vector2.ZERO, Vector2(t.current_size)).grow(1).encloses(result.get_global_rect()), "Random inheritance result is immediately visible within the logical viewport")
	await t.capture("07b_inherited_result")
	t.check(game.claim_body(0, recipient["id"]), "Second actual corpse still uses random inheritance")
	# Explicit earned-evolution UI fixture: the reveal must remain covered even
	# when this size's legitimate random roll does not supply Flame.
	for ability in ["heavy_blow", "firebolt"]:
		if not recipient["learned"].has(ability): recipient["learned"].append(ability)
		if not recipient["consumed"].has(ability): recipient["consumed"].append(ability)
	t.check(game.evolve(recipient["id"], "red_ogre"), "Explicit earned lineage fixture opens the evolution reveal")
	var info: Dictionary = game.last_evolution.duplicate(true)
	game.last_evolution = {}
	ui.refresh()
	return info
