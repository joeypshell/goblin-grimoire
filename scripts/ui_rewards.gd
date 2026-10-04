extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui

func _init(owner) -> void:
	ui = owner

func render() -> void:
	var rewards: Array = ui.state.run["rewards"]
	var remaining = 0
	for body in rewards:
		if not body["claimed"]: remaining += 1
	ui.content.add_child(ui.label("The fallen become your strength", 29))
	ui.content.add_child(ui.label("Each body offers one actual ability to one monster. You choose who eats. Recovery follows when you continue.", 15, ui.MUTED, true))
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.content.add_child(columns)
	var bodies = ui.panel(columns)
	bodies.custom_minimum_size.x = 230
	bodies.add_child(ui.label("RAID SPOILS", 16, ui.EMBER))
	if ui.feed_body >= rewards.size(): ui.feed_body = 0
	if not rewards.is_empty() and rewards[ui.feed_body]["claimed"] and remaining > 0:
		for i in range(rewards.size()):
			if not rewards[i]["claimed"]:
				ui.feed_body = i
				ui.feed_ability = ""
				break
	for i in range(rewards.size()):
		var body = rewards[i]
		var entry = ui.button(body["name"] + "\n" + ("Consumed / skipped" if body["claimed"] else body["class_name"]), func():
			ui.feed_body = i
			ui.feed_ability = ""
			ui.refresh())
		entry.custom_minimum_size.y = 68
		entry.disabled = body["claimed"]
		if i == ui.feed_body and not body["claimed"]:
			entry.add_theme_stylebox_override("normal", ui.style(Color("424832"), ui.EMBER))
		bodies.add_child(entry)
	var filler = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bodies.add_child(filler)
	bodies.add_child(ui.label(str(remaining) + " bodies remaining", 14, ui.MUTED))
	var continue_button = ui.primary("Recover & continue", func(): ui.act(ui.state.finish_feeding, "The team recovers after the raid."))
	continue_button.disabled = remaining > 0
	bodies.add_child(continue_button)
	var feeding = ui.panel(columns, true)
	feeding.custom_minimum_size.x = 390
	if remaining > 0:
		_body_choices(rewards[ui.feed_body], feeding)
	else:
		feeding.add_child(ui.label("The meal is finished.", 24, ui.MOSS))
		feeding.add_child(ui.label("Choose learned skills or any available transformation, then recover and continue to the next raid.", 17, ui.MUTED, true))
	var team = ui.panel(columns)
	team.custom_minimum_size.x = 345
	team.add_child(ui.label("YOUR MONSTERS / NEXT DECK", 15, ui.MOSS))
	var roster = ui.scroll(team)
	for monster in ui.state.run["monsters"]:
		var group = VBoxContainer.new()
		group.add_theme_constant_override("separation", 5)
		roster.add_child(group)
		var row = HBoxContainer.new()
		group.add_child(row)
		row.add_child(ui.portrait(monster, 46))
		var info = VBoxContainer.new()
		row.add_child(info)
		info.add_child(ui.label(monster["name"] + "  ·  " + ui.form_name(monster["form"]), 15))
		info.add_child(ui.label(str(monster["feeds"]) + " meals  ·  " + str(monster["hp"]) + " / " + str(monster["max_hp"]) + " HP", 12, ui.MUTED))
		var picks = HBoxContainer.new()
		group.add_child(picks)
		for slot in range(2):
			var picker = ui.screens.skill_picker(monster, slot)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.custom_minimum_size.x = 140
			picks.add_child(picker)
		if not ui.state.eligible(monster["id"]).is_empty():
			group.add_child(ui.primary("Transformation available", func(): ui.screens.evolution_choices(monster)))
		var separator = HSeparator.new()
		separator.modulate = Color("465039")
		group.add_child(separator)

func _body_choices(body: Dictionary, box: VBoxContainer) -> void:
	var row = HBoxContainer.new()
	box.add_child(row)
	row.add_child(ui.portrait(body, 82))
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(ui.label(body["name"], 24))
	info.add_child(ui.label("Choose one of this " + body["class_name"].to_lower() + "'s abilities.", 14, ui.MUTED, true))
	box.add_child(ui.label("1  ·  CHOOSE WHO EATS", 14, ui.EMBER))
	if ui.feed_monster == "": ui.feed_monster = ui.state.run["monsters"][0]["id"]
	var recipients = HBoxContainer.new()
	recipients.add_theme_constant_override("separation", 6)
	box.add_child(recipients)
	for monster in ui.state.run["monsters"]:
		var pick = ui.button(monster["name"], func():
			ui.feed_monster = monster["id"]
			ui.feed_ability = ""
			ui.refresh())
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ui.feed_monster == monster["id"]:
			pick.add_theme_stylebox_override("normal", ui.style(Color("424832"), ui.MOSS))
		recipients.add_child(pick)
	box.add_child(ui.label("2  ·  INHERIT ONE ABILITY", 14, ui.EMBER))
	var monster = ui.state.get_monster(ui.feed_monster)
	var choices = ui.scroll(box)
	var fresh = false
	for id in body["abilities"]:
		var known = id in monster["learned"]
		if not known: fresh = true
		var ability = Data.ABILITIES[id]
		var pick = ui.button(ability["name"] + "  ·  " + str(ability["cost"]) + " energy  ·  " + ability["affinity"] + ("\nAlready known" if known else "\n" + ability["description"]), func():
			ui.feed_ability = id
			ui.refresh())
		pick.custom_minimum_size.y = 66
		pick.add_theme_font_size_override("font_size", 14)
		pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pick.disabled = known
		if id == ui.feed_ability:
			pick.add_theme_stylebox_override("normal", ui.style(Color("464833"), ui.EMBER))
		choices.add_child(pick)
	if not fresh:
		box.add_child(ui.label("This monster knows every offered skill. Choose another recipient or skip this body.", 13, ui.MUTED, true))
	var actions = HBoxContainer.new()
	box.add_child(actions)
	var confirm = ui.primary("Consume & inherit", func():
		var recipient = ui.feed_monster
		var ability_id = ui.feed_ability
		var body_index = ui.feed_body
		ui.feed_ability = ""
		ui.act(func(): ui.state.claim_body(body_index, recipient, ability_id), ui.state.get_monster(recipient)["name"] + " inherited " + ui.ability_name(ability_id) + "."))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.disabled = ui.feed_ability == "" or ui.feed_ability in monster["learned"]
	actions.add_child(confirm)
	actions.add_child(ui.button("Skip body", func():
		ui.feed_ability = ""
		ui.act(func(): ui.state.skip_body(ui.feed_body), "The body was left behind.")))

func reveal(info: Dictionary) -> void:
	var box = ui.open_modal()
	box.add_child(ui.label("A NEW PAGE IN THE GRIMOIRE", 15, ui.EMBER))
	var monster = ui.state.get_monster(info["monster_id"])
	box.add_child(ui.label(monster["name"] + " becomes…", 24, ui.PARCHMENT))
	var art = ui.portrait({"form": info["to"]}, 220)
	box.add_child(art)
	box.add_child(ui.label(ui.form_name(info["to"]), 33, ui.MOSS))
	box.add_child(ui.label(Data.FORMS[info["to"]]["passive"], 17, ui.PARCHMENT, true))
	box.add_child(ui.label("New signature: " + ui.ability_name(Data.FORMS[info["to"]]["signature"]), 16, ui.EMBER))
	box.add_child(ui.label("Identity and learned skills preserved. Health keeps its current percentage. This discovery is yours forever.", 14, ui.MUTED, true))
	box.add_child(ui.primary("Welcome the transformation", ui.close_modal))
	art.modulate = Color(0.5, 0.55, 0.35, 0.2)
	var tween = art.create_tween()
	tween.tween_property(art, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
