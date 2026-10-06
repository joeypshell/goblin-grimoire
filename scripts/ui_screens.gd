extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const InvaderTactics = preload("res://scripts/invader_tactics.gd")
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
	copy.add_child(ui.label("Prepare your goblins. Play their cards.\nFeed the fallen. Defend the core.", 16 if compact else 19, ui.MUTED, true))
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
	var sound_row = HBoxContainer.new()
	if compact: copy.add_child(sound_row)
	var sound: Button = ui.button("Sound settings", ui.audio_settings.open, 0 if compact else 160)
	sound.name = "OpenSoundSettings"
	sound.focus_mode = Control.FOCUS_ALL
	if compact: sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_row.add_child(sound)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if compact: spacer.free()
	else: copy.add_child(spacer)
	var how = ui.panel(copy)
	how.add_child(ui.label("A raid in four steps", 19 if compact else 20, ui.EMBER, compact))
	how.add_child(ui.label("1   PREPARE: choose skills and inspect.\n2   FIGHT: card owner acts on a target.\n3   FEED: transfer one enemy ability.\n4   RECOVER: regain HP; earn milestone traits.", 14 if compact else 16, ui.PARCHMENT, true))
	how.add_child(ui.label("End turn resolves the invaders. Healing cards can be played again.", 14, ui.MUTED, true))
	how.add_child(ui.label("Anonymous gameplay reports upload automatically to help improve the game.", 13, ui.MUTED, true))
	var reports = ui.button("Playtest reports", ui.report_ui.open, 0 if compact else 150)
	reports.name = "OpenRunReports"
	reports.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact: how.add_child(reports)
	else: actions.add_child(reports)
	var art = ui.panel(columns, true)
	art.add_child(ui.label("YOUR HUMBLE BEGINNINGS", 13 if compact else 15, ui.MOSS, compact))
	var large = ui.portrait({"form": "goblin"}, 144 if compact else 285)
	if not compact: large.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.add_child(large)
	art.add_child(ui.label("Three lives. One dungeon core.", 20 if compact else 24, ui.PARCHMENT, compact))
	art.add_child(ui.label("A six-raid campaign of strange meals\nand unexpected transformations.", 15 if compact else 17, ui.MUTED, true))
	art.add_child(ui.label("Rank F to E to D promotion", 16 if compact else 18, ui.EMBER, compact))
	if not compact: art.add_child(sound_row)

func _new_run() -> void:
	ui.state.new_run()
	ui.menu = "game"
	ui.feed_body = 0
	ui.feed_monster = ""
	ui.act(func(): pass, "Your goblins await their first raid.")

func preparation() -> void:
	var compact = ui.is_compact()
	var incoming: Array = ui.state.party_preview()
	var page = ui.scroll(ui.content)
	page.get_parent().name = "PreparationScroll"
	var top = _flow(compact)
	page.add_child(top)
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	text.add_child(ui.label("1 / Prepare the chamber", 25 if compact else 27, ui.PARCHMENT, compact))
	text.add_child(ui.label("Choose two skills per monster; check their energy costs. Monsters act through owned cards. Invaders choose living targets each round, then keep their shown intentions. Next: inspect and defend.", 14, ui.MUTED, true))
	var selected = ui.label("READY TO DEFEND / " + ui.state.selected_party_name(), 14, ui.EMBER, true)
	selected.name = "PartySelectionCue"
	text.add_child(selected)
	top.add_child(ui.primary("Defend the dungeon", func():
		ui.act(ui.state.start_raid, "Choose a card, then one of its highlighted targets."), 0 if compact else 230))
	ui.traits_screen.summary(page)
	ui.party_routes.render(page)
	var roster = _flow(compact)
	roster.add_theme_constant_override("separation", 14)
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(roster)
	for monster in ui.state.run["monsters"]:
		_roster_card(monster, roster)
	var incoming_title = ui.label("INCOMING / " + ui.state.selected_party_name(), 15 if compact else 17, ui.EMBER, true)
	incoming_title.name = "SelectedIncomingParty"
	page.add_child(incoming_title)
	ui.traits_screen.champion_warning(incoming, page)
	var party = _flow(compact)
	party.add_theme_constant_override("separation", 12)
	page.add_child(party)
	for enemy in incoming:
		var box = ui.panel(party, true)
		var row = HBoxContainer.new()
		box.add_child(row)
		row.add_child(ui.portrait(enemy, 56 if compact else 68))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(enemy["name"], 18, ui.PARCHMENT, compact))
		info.add_child(ui.label(enemy["class_name"] + "  ·  " + str(enemy["max_hp"]) + " HP  ·  Armor " + str(Data.armor(enemy)), 13, ui.MOSS, true))
		var names: Array = []
		for ability in enemy["abilities"]: names.append(ui.ability_name(ability))
		info.add_child(ui.label(" / ".join(names), 13, ui.MUTED, true))
		var tactic: String = InvaderTactics.description(enemy)
		if tactic != "":
			var role = ui.label(tactic, 13, ui.EMBER, true)
			role.name = "IncomingTactic_" + enemy["id"]
			info.add_child(role)
		var encounter_rule: String = Data.encounter_rule_text(enemy)
		if encounter_rule != "":
			var rule = ui.label(encounter_rule, 13, ui.EMBER, true)
			rule.name = "IncomingRule_" + enemy["id"]
			info.add_child(rule)
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
	var signature: String = definition.get("signature", "stab")
	box.add_child(ui.label("Signature  ·  %s · %d energy" % [ui.ability_name(signature), Data.ABILITIES[signature]["cost"]], 15, ui.EMBER, true))
	if ui.is_compact(): box.add_child(ui.label(Data.ABILITIES.get(definition.get("signature", "stab"), {}).get("description", ""), 13, ui.PARCHMENT, true))
	box.add_child(ui.label(definition.get("passive", ""), 13, ui.MUTED, true))
	form_tactic(monster["form"], box, "FormTacticPreparation_" + monster["id"])
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
	consumed_affinities(monster, box)
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
		picker.add_item("%s · %d energy" % [ui.ability_name(id), Data.ABILITIES[id]["cost"]])
		picker.set_item_disabled(index, id == monster["selected"][1 - slot])
		if id == monster["selected"][slot]: picker.select(index)
		picker.set_item_tooltip(index, Data.ABILITIES.get(id, {}).get("description", ""))
	picker.item_selected.connect(func(index):
		ui.act(func(): ui.state.set_selected(monster["id"], slot, ids[index]), "The next raid's deck has been updated."))
	return picker

func consumed_affinities(monster: Dictionary, parent: Node) -> void:
	var affinities: Array = Data.consumed_affinities(monster)
	var history: String = ", ".join(affinities) if not affinities.is_empty() else "None yet"
	var known = ui.label("Consumed affinities: " + history, 12, ui.MOSS, true)
	known.name = "ConsumedAffinities_" + str(monster["id"])
	parent.add_child(known)

func form_tactic(form: String, parent: Node, node_name: String) -> void:
	var tactic: String = Data.FORMS.get(form, {}).get("tactic", "")
	if tactic == "": return
	var advice = ui.label("PLAYSTYLE / " + tactic, 13, ui.EMBER, true)
	advice.name = node_name
	parent.add_child(advice)

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
		var definition: Dictionary = Data.FORMS[recipe["result"]]
		var health = ui.label("Maximum HP: %d" % definition["max_hp"], 14, ui.MOSS, true)
		health.name = "FormChoiceHealth_" + recipe["result"]
		text.add_child(health)
		text.add_child(ui.label(definition["passive"], 14, ui.MUTED, true))
		form_tactic(recipe["result"], text, "FormTacticChoice_" + recipe["result"])
		var signature: String = definition["signature"]
		var effect = ui.label("Signature: %s · %d energy\n%s" % [ui.ability_name(signature), Data.ABILITIES[signature]["cost"], Data.ABILITIES[signature]["description"]], 13, ui.PARCHMENT, true)
		effect.name = "FormChoiceSignature_" + recipe["result"]
		text.add_child(effect)
		var evolve = ui.primary("Evolve", func():
			ui.close_modal()
			ui.act(func(): ui.state.evolve(monster["id"], recipe["id"]), monster["name"] + " has transformed."))
		evolve.name = "EvolveForm_" + recipe["result"]
		text.add_child(evolve)
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
		form_tactic(form, info, "FormTacticGrimoire_" + form)
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
	var heading = "4 / RECOVERY APPLIED"
	var title = "The chamber grows quiet."
	var message = "Every monster recovered " + recovery + " of maximum HP, capped at full health. Next: return to preparation for " + ui.state.raid_name() + "."
	if victory:
		heading = "PROMOTED TO RANK D"
		title = "Your dungeon has a future."
		message = "The E-rank champion has fallen. Campaign complete. Next: read your discoveries or begin a new run with that knowledge."
	elif defeat:
		heading = "THE CORE HAS FALLEN"
		title = "A dungeon lost. Knowledge kept."
		message = "Your core is destroyed. Next: begin a new run with three fresh goblins. Your discoveries remain in the grimoire."
	elif breach:
		heading = "4 / BREACH  ·  " + str(Data.BALANCE["breach"]) + " CORE LOST"
		title = "The goblins rise again."
		message = "Your core survived. Every monster recovered " + recovery + " of maximum HP. Next: return to preparation and retry this same raid."
	elif ui.state.run.get("promotion", "") == "E":
		heading = "4 / RECOVERY  ·  PROMOTED TO E"
		title = "Word is spreading."
		message = "The F-rank champion has fallen and recovery is applied. Next: select skills and inspect stronger invaders during rank E preparation."
	box.add_child(ui.label(heading, 16, ui.RED if defeat or breach else ui.EMBER, compact))
	box.add_child(ui.label(title, 27 if compact else 34, ui.PARCHMENT, compact))
	box.add_child(ui.label(message, 17, ui.MUTED, true))
	ui.traits_screen.summary(box)
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
	var reports = ui.button("Playtest reports", ui.report_ui.open)
	reports.name = "OpenRunReports"
	actions.add_child(reports)
