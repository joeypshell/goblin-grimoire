extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui

func _init(owner) -> void:
	ui = owner

func title_screen() -> void:
	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 36)
	ui.content.add_child(columns)
	var copy = VBoxContainer.new()
	copy.custom_minimum_size.x = 535
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 18)
	columns.add_child(copy)
	copy.add_child(ui.label("THE DUNGEON IS YOURS", 15, ui.MOSS))
	copy.add_child(ui.label("Small goblins.\nDangerous potential.", 44, ui.PARCHMENT))
	copy.add_child(ui.label("Keep the core alive. Turn adventurers into abilities.\nLet your monsters become something extraordinary.", 19, ui.MUTED, true))
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	copy.add_child(actions)
	actions.add_child(ui.primary("New run", _new_run, 170))
	var resume = ui.button("Continue", func():
		if ui.state.load_game():
			ui.menu = "game"
			ui.card_index = -1
			ui.refresh(), 150)
	resume.disabled = not ui.state.has_save()
	actions.add_child(resume)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(spacer)
	var how = ui.panel(copy)
	how.add_child(ui.label("A keeper's first lesson", 20, ui.EMBER))
	how.add_child(ui.label("01   Prepare your three goblins and inspect the raid.\n02   Spend energy on cards, then end your turn.\n03   Consume the fallen to inherit one of their abilities.\n04   Discover transformations. Defend through rank E.", 16, ui.PARCHMENT, true))
	how.add_child(ui.label("Healing can be played again whenever it cycles back into your hand. Space ends your turn; Escape cancels a selected card.", 14, ui.MUTED, true))
	var art = ui.panel(columns, true)
	art.add_child(ui.label("YOUR HUMBLE BEGINNINGS", 15, ui.MOSS))
	var large = ui.portrait({"form": "goblin"}, 285)
	large.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.add_child(large)
	art.add_child(ui.label("Three lives. One dungeon core.", 24, ui.PARCHMENT))
	art.add_child(ui.label("A six-raid campaign of strange meals\nand unexpected transformations.", 17, ui.MUTED, true))
	art.add_child(ui.label("Rank F to E to D promotion", 18, ui.EMBER))

func _new_run() -> void:
	ui.state.new_run()
	ui.menu = "game"
	ui.feed_body = 0
	ui.feed_monster = ""
	ui.act(func(): pass, "Your goblins await their first raid.")

func preparation() -> void:
	var top = HBoxContainer.new()
	ui.content.add_child(top)
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	text.add_child(ui.label("Prepare the chamber", 29))
	text.add_child(ui.label("Each monster brings its signature and two selected skills. Health carries between raids.", 15, ui.MUTED, true))
	top.add_child(ui.primary("Defend the dungeon", func():
		ui.act(ui.state.start_raid, "Choose a card, then one of its highlighted targets."), 230))
	var roster = HBoxContainer.new()
	roster.add_theme_constant_override("separation", 14)
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.content.add_child(roster)
	for monster in ui.state.run["monsters"]:
		_roster_card(monster, roster)
	ui.content.add_child(ui.label("INCOMING  /  " + ui.state.raid_name().to_upper(), 17, ui.EMBER))
	var party = HBoxContainer.new()
	party.add_theme_constant_override("separation", 12)
	ui.content.add_child(party)
	for enemy in ui.state.party_preview():
		var box = ui.panel(party, true)
		var row = HBoxContainer.new()
		box.add_child(row)
		row.add_child(ui.portrait(enemy, 68))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(enemy["name"], 18))
		info.add_child(ui.label(enemy["class_name"] + "  ·  " + str(enemy["max_hp"]) + " HP", 13, ui.MOSS))
		var names: Array = []
		for ability in enemy["abilities"]: names.append(ui.ability_name(ability))
		info.add_child(ui.label(" / ".join(names), 13, ui.MUTED, true))
	ui.content.add_child(ui.label("Run seed " + str(ui.state.run["seed"]) + "  ·  Enemy abilities shown here are the abilities they can use and transfer.", 12, ui.MUTED, true))

func _roster_card(monster: Dictionary, parent: Node) -> void:
	var box = ui.panel(parent, true)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(ui.portrait(monster, 96))
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(ui.label(monster["name"], 22, ui.PARCHMENT))
	info.add_child(ui.label(ui.form_name(monster["form"]), 15, ui.MOSS))
	ui.health(monster, info)
	var definition = Data.FORMS.get(monster["form"], {})
	box.add_child(ui.label("Signature  ·  " + ui.ability_name(definition.get("signature", "stab")), 15, ui.EMBER))
	box.add_child(ui.label(definition.get("passive", ""), 13, ui.MUTED, true))
	var gap = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	for slot in range(2):
		var skill_row = HBoxContainer.new()
		box.add_child(skill_row)
		skill_row.add_child(ui.label("Skill " + str(slot + 1), 14, ui.MUTED))
		var picker = skill_picker(monster, slot)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_row.add_child(picker)
	box.add_child(ui.label(str(monster["feeds"]) + " meals  ·  " + str(monster["learned"].size()) + " learned skills", 12, ui.MUTED))
	var earned = ui.state.eligible(monster["id"])
	if not earned.is_empty():
		box.add_child(ui.primary("Transformation available", func(): evolution_choices(monster), 0))

func skill_picker(monster: Dictionary, slot: int) -> OptionButton:
	var picker = OptionButton.new()
	picker.custom_minimum_size.y = 36
	picker.add_theme_font_size_override("font_size", 14)
	var ids: Array = monster["learned"]
	for index in range(ids.size()):
		var id = ids[index]
		picker.add_item(ui.ability_name(id))
		picker.set_item_disabled(index, id == monster["selected"][1 - slot])
		if id == monster["selected"][slot]: picker.select(index)
		picker.set_item_tooltip(index, Data.ABILITIES.get(id, {}).get("description", ""))
	picker.item_selected.connect(func(index):
		ui.act(func(): ui.state.set_selected(monster["id"], slot, ids[index]), "The next raid's deck has been updated."))
	return picker

func evolution_choices(monster: Dictionary) -> void:
	var box = ui.open_modal()
	box.add_child(ui.label("Something stirs within " + monster["name"] + "…", 24, ui.EMBER))
	box.add_child(ui.label("These transformations are earned. Choose one now, or return during preparation.", 16, ui.MUTED, true))
	for recipe in ui.state.eligible(monster["id"]):
		var row = HBoxContainer.new()
		box.add_child(row)
		row.add_child(ui.portrait({"form": recipe["result"]}, 104))
		var text = VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(ui.label(ui.form_name(recipe["result"]), 21, ui.MOSS))
		text.add_child(ui.label(Data.FORMS[recipe["result"]]["passive"], 14, ui.MUTED, true))
		text.add_child(ui.primary("Evolve", func():
			ui.close_modal()
			ui.act(func(): ui.state.evolve(monster["id"], recipe["id"]), monster["name"] + " has transformed.")))
	box.add_child(ui.button("Decide later", ui.close_modal))

func grimoire() -> void:
	var top = HBoxContainer.new()
	ui.content.add_child(top)
	var title = ui.label("The keeper's grimoire", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(ui.button("Return", func():
		ui.menu = ui.grimoire_return
		ui.refresh()))
	ui.content.add_child(ui.label("A record of transformations you have performed. Knowledge remains between runs.", 16, ui.MUTED, true))
	var discoveries = ui.state.discoveries()
	if discoveries.is_empty():
		var center = CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ui.content.add_child(center)
		var blank = ui.panel(center)
		blank.custom_minimum_size.x = 520
		blank.add_child(ui.label("A book without an entry", 28, ui.EMBER))
		blank.add_child(ui.label("Your grimoire is empty.\nFeed your monsters and follow what awakens within them.", 18, ui.MUTED, true))
		return
	var list = ui.scroll(ui.content)
	for entry in discoveries:
		var form = entry.get("form", "goblin")
		var box = ui.panel(list)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		box.add_child(row)
		row.add_child(ui.portrait({"form": form}, 140))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(ui.form_name(form), 25, ui.MOSS))
		var recipe_value = entry.get("recipe", {})
		var recipe = recipe_value if recipe_value is Dictionary else _known_recipe(str(recipe_value))
		if not recipe.is_empty():
			info.add_child(ui.label("From " + ui.form_name(recipe["source"]) + "  ·  " + " + ".join(recipe["affinities"]) + "  ·  " + str(recipe["feeds"]) + " total meals", 16, ui.EMBER, true))
		var definition = Data.FORMS.get(form, {})
		info.add_child(ui.label(definition.get("passive", ""), 16, ui.PARCHMENT, true))
		var sig = definition.get("signature", "stab")
		info.add_child(ui.label("Signature: " + ui.ability_name(sig) + " / " + Data.ABILITIES.get(sig, {}).get("description", ""), 15, ui.MUTED, true))
		info.add_child(ui.label(str(definition.get("max_hp", 20)) + " base HP  ·  Learned skills are retained.", 14, ui.MUTED))

func _known_recipe(id: String) -> Dictionary:
	for recipe in Data.RECIPES:
		if recipe["id"] == id: return recipe
	return {}

func results() -> void:
	var phase = ui.state.run["phase"]
	var victory = phase == "victory"
	var defeat = phase == "defeat"
	var breach = ui.state.run.get("last_result", "") == "breach"
	var recovery = str(roundi(float(Data.BALANCE["recovery"]) * 100)) + "%"
	var center = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.content.add_child(center)
	var box = ui.panel(center)
	box.custom_minimum_size.x = 780
	var heading = "DUNGEON DEFENDED"
	var title = "The chamber grows quiet."
	var message = "Your monsters recover " + recovery + " of their maximum health. Your next visitors are approaching."
	if victory:
		heading = "PROMOTED TO RANK D"
		title = "Your dungeon has a future."
		message = "The E-rank champion has fallen. You have completed the six-raid campaign. Your discoveries remain in the grimoire."
	elif defeat:
		heading = "THE CORE HAS FALLEN"
		title = "A dungeon lost. Knowledge kept."
		message = "The core could endure no more breaches. Begin again with three fresh goblins and the discoveries you have earned."
	elif breach:
		heading = "BREACH  ·  " + str(Data.BALANCE["breach"]) + " CORE LOST"
		title = "The goblins rise again."
		message = "Your core survived. All monsters recover " + recovery + " of their maximum health. The same raid awaits another defense."
	elif ui.state.run.get("promotion", "") == "E":
		heading = "PROMOTED TO RANK E"
		title = "Word is spreading."
		message = "The F-rank champion has fallen. Stronger adventurers now seek your core. Prepare your monsters for rank E."
	box.add_child(ui.label(heading, 16, ui.RED if defeat or breach else ui.EMBER))
	box.add_child(ui.label(title, 34))
	box.add_child(ui.label(message, 17, ui.MUTED, true))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for monster in ui.state.run["monsters"]:
		var team = VBoxContainer.new()
		team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(team)
		team.add_child(ui.portrait(monster, 106))
		team.add_child(ui.label(monster["name"] + "  ·  " + ui.form_name(monster["form"]), 15, ui.MOSS))
		ui.health(monster, team)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	if victory or defeat:
		actions.add_child(ui.primary("Begin another run", _new_run, 230))
	else:
		actions.add_child(ui.primary("Return to preparation", func(): ui.act(ui.state.continue_after_result), 270))
	actions.add_child(ui.button("Read grimoire", ui.open_grimoire, 175))
