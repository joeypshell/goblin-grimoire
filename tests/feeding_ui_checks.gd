extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Traits = preload("res://scripts/dungeon_traits.gd")

func choose_trait(t) -> void:
	var game = t.game
	var ui = t.ui
	var before_meal: bool = game.run.get("trait_return", "result") == "feeding"
	t.check(game.run["phase"] == "trait" and game.run["raid"] == (0 if before_meal else 1), "First earned choice retains its correct pre-meal or legacy post-meal raid boundary")
	if game.run["phase"] != "trait": return
	var bodies_before: Array = game.run["rewards"].duplicate(true)
	var return_phase: String = game.run.get("trait_return", "result")
	var guidance = ui.find_child("TraitReturnGuidance", true, false)
	if before_meal:
		t.check(game.run["recovered_id"] < game.run["resolved_id"] and guidance is Label and guidance.text.contains("Recovery follows the meal") and not guidance.text.contains("already applied"), "New first reward explains feeding before recovery")
		t.check(ui.find_child("RaidRecap", true, false) != null, "New first reward shows the earned victory recap")
	var choices: Array = game.trait_choices()
	t.check(choices.size() == 2 and choices[0] != choices[1] and choices == game.run.get("first_trait_offer", []), "First mobile reward uses its exact two distinct saved offers")
	var offer_copy = ui.find_child("TraitOfferSummary", true, false)
	t.check(offer_copy is Label and offer_copy.text.contains("two offers") and offer_copy.text.contains("Continue keeps"), "Mobile first reward explains the two saved offers and Continue behavior")
	var hp_before: Array = game.run["monsters"].map(func(m): return m["hp"])
	var random_before: int = game.rng.state
	await t.capture("10a_trait_choice")
	for id in choices:
		var select = ui.find_child("TraitSelect_" + id, true, false)
		var advice = ui.find_child("TraitCompatibility_" + id, true, false)
		t.check(select is Button and advice is Label and advice.text != "", "Every offered trait has a real action and readable deck-compatibility advice")
	for id in Traits.DEFINITIONS:
		t.check((ui.find_child("TraitSelect_" + id, true, false) != null) == choices.has(id), "Mobile first reward renders no unoffered trait choice")
	var chosen: String = choices[0]
	var button = ui.find_child("TraitSelect_" + chosen, true, false)
	if button != null:
		await t.ensure_reachable(button, "Trait choice")
		t.check(button.size.y >= 43.9, "Earned trait action has a forty-four-pixel logical tap target")
		button.pressed.emit()
		await t.settle()
	t.check(game.run["phase"] == return_phase and game.run["traits"] == [chosen] and game.run["trait_milestones"] == [1], "Reachable trait action records the chosen rule and returns to its promised phase")
	t.check(game.rng.state == random_before and game.run["monsters"].map(func(m): return m["hp"]) == hp_before, "Trait UI choice consumes no RNG and cannot repeat recovery")
	t.check(game.run["rewards"] == bodies_before, "Trait choice leaves every corpse and inheritance outcome untouched")
	var summary = ui.find_child("TraitSummary", true, false)
	t.check(summary is Label and summary.text.contains(Traits.DEFINITIONS[chosen]["name"]), "Destination visibly identifies the selected dungeon build")
	await t.capture("10b_trait_feeding" if before_meal else "10b_legacy_trait_result")

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
			t.check(label_.text.contains(Data.ABILITIES[option["ability"]]["affinity"]), "Inheritance odds identify the affinity available from this actual corpse")
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
	# Explicit long-history presentation fixture, using transferable invader skills.
	for ability in ["heavy_blow", "shield_wall", "firebolt", "poisoned_blade", "snare", "smoke_step", "arcane_bolt", "regrowth", "mend"]:
		if not recipient["learned"].has(ability): recipient["learned"].append(ability)
		if not recipient["consumed"].has(ability): recipient["consumed"].append(ability)
	recipient["feeds"] = recipient["consumed"].size()
	ui.refresh()
	await t.capture("07c_consumed_affinities")
	var history = ui.find_child("ConsumedAffinities_" + recipient["id"], true, false)
	t.check(history is Label, "Feeding displays the recipient's actual consumed-affinity history")
	if history != null:
		for affinity in Data.consumed_affinities(recipient): t.check(history.text.contains(affinity), "Visible consumed history includes earned affinity " + affinity)
	return info
