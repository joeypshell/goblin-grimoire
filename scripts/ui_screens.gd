extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui

func _init(owner) -> void:
	ui = owner

func _page() -> VBoxContainer:
	return ui.scroll(ui.content) if ui.is_compact() else ui.content

func _flow(stacked: bool) -> BoxContainer:
	return VBoxContainer.new() if stacked else HBoxContainer.new()

func title_screen() -> void:
	var compact = ui.is_compact()
	var page = _page()
	var columns = _flow(compact)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14 if compact else 36)
	page.add_child(columns)
	var copy = VBoxContainer.new()
	copy.custom_minimum_size.x = 0 if compact else 535
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 12 if compact else 18)
	columns.add_child(copy)
	copy.add_child(ui.label("THE DUNGEON IS YOURS", 13 if compact else 15, ui.MOSS))
	copy.add_child(ui.label("Small goblins.\nDangerous potential.", 30 if compact else 44, ui.PARCHMENT, compact))
	copy.add_child(ui.label("Keep the core alive. Turn adventurers into abilities.\nLet your monsters become something extraordinary.", 16 if compact else 19, ui.MUTED, true))
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8 if compact else 12)
	copy.add_child(actions)
	var new_button = ui.primary("New run", _new_run, 0 if compact else 170)
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(new_button)
	var resume = ui.button("Continue", func():
		if ui.state.load_game():
			ui.menu = "game"
			ui.card_index = -1
			ui.refresh(), 0 if compact else 150)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.disabled = not ui.state.has_save()
	actions.add_child(resume)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if compact: spacer.free()
	else: copy.add_child(spacer)
	var how = ui.panel(copy)
	how.add_child(ui.label("A keeper's first lesson", 19 if compact else 20, ui.EMBER, compact))
	how.add_child(ui.label("01   Prepare your three goblins and inspect the raid.\n02   Spend energy on cards, then end your turn.\n03   Consume the fallen to inherit one of their abilities.\n04   Discover transformations. Defend through rank E.", 14 if compact else 16, ui.PARCHMENT, true))
	how.add_child(ui.label("Healing cycles back into your hand. Tap a card, then a highlighted target. Use End turn when you are ready." if compact else "Healing can be played again whenever it cycles back into your hand. Space ends your turn; Escape cancels a selected card.", 14, ui.MUTED, true))
	var art = ui.panel(columns, true)
	art.add_child(ui.label("YOUR HUMBLE BEGINNINGS", 13 if compact else 15, ui.MOSS, compact))
	var large = ui.portrait({"form": "goblin"}, 144 if compact else 285)
	if not compact: large.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.add_child(large)
	art.add_child(ui.label("Three lives. One dungeon core.", 20 if compact else 24, ui.PARCHMENT, compact))
	art.add_child(ui.label("A six-raid campaign of strange meals\nand unexpected transformations.", 15 if compact else 17, ui.MUTED, true))
	art.add_child(ui.label("Rank F to E to D promotion", 16 if compact else 18, ui.EMBER, compact))

func _new_run() -> void:
	ui.state.new_run()
	ui.menu = "game"
	ui.feed_body = 0
	ui.feed_monster = ""
	ui.act(func(): pass, "Your goblins await their first raid.")

func preparation() -> void:
	var compact = ui.is_compact()
	var page = _page()
	var top = _flow(compact)
	page.add_child(top)
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	text.add_child(ui.label("Prepare the chamber", 25 if compact else 29, ui.PARCHMENT, compact))
	text.add_child(ui.label("Each monster brings its signature and two selected skills. Health carries between raids.", 15, ui.MUTED, true))
	top.add_child(ui.primary("Defend the dungeon", func():
		ui.act(ui.state.start_raid, "Choose a card, then one of its highlighted targets."), 0 if compact else 230))
	var roster = _flow(compact)
	roster.add_theme_constant_override("separation", 14)
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(roster)
	for monster in ui.state.run["monsters"]:
		_roster_card(monster, roster)
	page.add_child(ui.label("INCOMING  /  " + ui.state.raid_name().to_upper(), 15 if compact else 17, ui.EMBER, compact))
	var party = _flow(compact)
	party.add_theme_constant_override("separation", 12)
	page.add_child(party)
	for enemy in ui.state.party_preview():
		var box = ui.panel(party, true)
		var row = HBoxContainer.new()
		box.add_child(row)
		row.add_child(ui.portrait(enemy, 56 if compact else 68))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(enemy["name"], 18, ui.PARCHMENT, compact))
		info.add_child(ui.label(enemy["class_name"] + "  ·  " + str(enemy["max_hp"]) + " HP", 13, ui.MOSS))
		var names: Array = []
		for ability in enemy["abilities"]: names.append(ui.ability_name(ability))
		info.add_child(ui.label(" / ".join(names), 13, ui.MUTED, true))
	page.add_child(ui.label("Run seed " + str(ui.state.run["seed"]) + "  ·  Enemy abilities shown here are the abilities they can use and transfer.", 12, ui.MUTED, true))

func _roster_card(monster: Dictionary, parent: Node) -> void:
	var box = ui.panel(parent, true)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(ui.portrait(monster, 72 if ui.is_compact() else 96))
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(ui.label(monster["name"], 22, ui.PARCHMENT, ui.is_compact()))
	info.add_child(ui.label(ui.form_name(monster["form"]), 15, ui.MOSS, ui.is_compact()))
	ui.health(monster, info)
	var definition = Data.FORMS.get(monster["form"], {})
	box.add_child(ui.label("Signature  ·  " + ui.ability_name(definition.get("signature", "stab")), 15, ui.EMBER, ui.is_compact()))
	if ui.is_compact(): box.add_child(ui.label(Data.ABILITIES.get(definition.get("signature", "stab"), {}).get("description", ""), 13, ui.PARCHMENT, true))
	box.add_child(ui.label(definition.get("passive", ""), 13, ui.MUTED, true))
	var gap = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ui.is_compact(): gap.free()
	else: box.add_child(gap)
	for slot in range(2):
		var skill_row = HBoxContainer.new()
		box.add_child(skill_row)
		skill_row.add_child(ui.label("Skill " + str(slot + 1), 14, ui.MUTED))
		var picker = skill_picker(monster, slot)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_row.add_child(picker)
		if ui.is_compact():
			box.add_child(ui.label(Data.ABILITIES[monster["selected"][slot]]["description"], 13, ui.MUTED, true))
	box.add_child(ui.label(str(monster["feeds"]) + " meals  ·  " + str(monster["learned"].size()) + " learned skills", 12, ui.MUTED))
	var earned = ui.state.eligible(monster["id"])
	if not earned.is_empty():
		box.add_child(ui.primary("Transformation available", func(): evolution_choices(monster), 0))

func skill_picker(monster: Dictionary, slot: int) -> OptionButton:
	var picker = OptionButton.new()
	picker.custom_minimum_size.y = 44 if ui.is_compact() else 36
	picker.fit_to_longest_item = not ui.is_compact()
	picker.add_theme_font_size_override("font_size", 14)
	if ui.is_compact():
		var popup = picker.get_popup()
		popup.add_theme_font_size_override("font_size", 16)
		var spacing = maxi(24, ceili(44.0 - ui.theme.default_font.get_height(16)))
		popup.add_theme_constant_override("v_separation", spacing)
		popup.max_size = Vector2i(int(ui.content_width()), maxi(80, int(ui.get_viewport_rect().size.y) - 40))
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
	box.add_child(ui.label("Something stirs within " + monster["name"] + "…", 22 if ui.is_compact() else 24, ui.EMBER, true))
	box.add_child(ui.label("These transformations are earned. Choose one now, or return during preparation.", 16, ui.MUTED, true))
	for recipe in ui.state.eligible(monster["id"]):
		var row = HBoxContainer.new()
		box.add_child(row)
		row.add_child(ui.portrait({"form": recipe["result"]}, 64 if ui.is_compact() else 104))
		var text = VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(ui.label(ui.form_name(recipe["result"]), 19 if ui.is_compact() else 21, ui.MOSS, true))
		text.add_child(ui.label(Data.FORMS[recipe["result"]]["passive"], 14, ui.MUTED, true))
		text.add_child(ui.primary("Evolve", func():
			ui.close_modal()
			ui.act(func(): ui.state.evolve(monster["id"], recipe["id"]), monster["name"] + " has transformed.")))
	box.add_child(ui.button("Decide later", ui.close_modal))

func grimoire() -> void:
	var compact = ui.is_compact()
	var page = _page()
	var top = _flow(compact)
	page.add_child(top)
	var title = ui.label("The keeper's grimoire", 25 if compact else 30, ui.PARCHMENT, compact)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(ui.button("Return", func():
		ui.menu = ui.grimoire_return
		ui.refresh()))
	page.add_child(ui.label("A record of transformations you have performed. Knowledge remains between runs.", 16, ui.MUTED, true))
	var discoveries = ui.state.discoveries()
	if discoveries.is_empty():
		var center = CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not compact: page.add_child(center)
		var blank = ui.panel(page if compact else center)
		if compact: center.free()
		blank.custom_minimum_size.x = 0 if compact else 520
		blank.add_child(ui.label("A book without an entry", 24 if compact else 28, ui.EMBER, compact))
		blank.add_child(ui.label("Your grimoire is empty.\nFeed your monsters and follow what awakens within them.", 18, ui.MUTED, true))
		return
	var list = page if compact else ui.scroll(ui.content)
	for entry in discoveries:
		var form = entry.get("form", "goblin")
		var box = ui.panel(list)
		var row = _flow(compact)
		row.add_theme_constant_override("separation", 20)
		box.add_child(row)
		row.add_child(ui.portrait({"form": form}, 96 if compact else 140))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(ui.form_name(form), 23 if compact else 25, ui.MOSS, compact))
		var recipe_value = entry.get("recipe", {})
		var recipe = recipe_value if recipe_value is Dictionary else _known_recipe(str(recipe_value))
		if not recipe.is_empty():
			info.add_child(ui.label("From " + ui.form_name(recipe["source"]) + "  ·  " + " + ".join(recipe["affinities"]) + "  ·  " + str(recipe["feeds"]) + " total meals", 16, ui.EMBER, true))
		var definition = Data.FORMS.get(form, {})
		info.add_child(ui.label(definition.get("passive", ""), 16, ui.PARCHMENT, true))
		var sig = definition.get("signature", "stab")
		info.add_child(ui.label("Signature: " + ui.ability_name(sig) + " / " + Data.ABILITIES.get(sig, {}).get("description", ""), 15, ui.MUTED, true))
		info.add_child(ui.label(str(definition.get("max_hp", 20)) + " base HP  ·  Learned skills are retained.", 14, ui.MUTED, compact))

func _known_recipe(id: String) -> Dictionary:
	for recipe in Data.RECIPES:
		if recipe["id"] == id: return recipe
	return {}

func results() -> void:
	var compact = ui.is_compact()
	var page = _page()
	var phase = ui.state.run["phase"]
	var victory = phase == "victory"
	var defeat = phase == "defeat"
	var breach = ui.state.run.get("last_result", "") == "breach"
	var recovery = str(roundi(float(Data.BALANCE["recovery"]) * 100)) + "%"
	var center = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not compact: page.add_child(center)
	var box = ui.panel(page if compact else center)
	if compact: center.free()
	box.custom_minimum_size.x = 0 if compact else 780
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
	box.add_child(ui.label(heading, 16, ui.RED if defeat or breach else ui.EMBER, compact))
	box.add_child(ui.label(title, 27 if compact else 34, ui.PARCHMENT, compact))
	box.add_child(ui.label(message, 17, ui.MUTED, true))
	var row = _flow(compact)
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for monster in ui.state.run["monsters"]:
		var team = HBoxContainer.new() if compact else VBoxContainer.new()
		team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(team)
		team.add_child(ui.portrait(monster, 64 if compact else 106))
		var info = VBoxContainer.new() if compact else team
		if compact:
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			team.add_child(info)
		info.add_child(ui.label(monster["name"] + "  ·  " + ui.form_name(monster["form"]), 15, ui.MOSS, compact))
		ui.health(monster, info)
	var actions = _flow(compact)
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	if victory or defeat:
		actions.add_child(ui.primary("Begin another run", _new_run, 0 if compact else 230))
	else:
		actions.add_child(ui.primary("Return to preparation", func(): ui.act(ui.state.continue_after_result), 0 if compact else 270))
	actions.add_child(ui.button("Read grimoire", ui.open_grimoire, 0 if compact else 175))
