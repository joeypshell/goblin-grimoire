extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui
var _page_scroll: ScrollContainer

func _init(owner) -> void:
	ui = owner

func render() -> void:
	var compact = ui.is_compact()
	var page = ui.scroll(ui.content)
	_page_scroll = page.get_parent()
	_page_scroll.name = "FeedingScroll"
	var rewards: Array = ui.state.run["rewards"]
	var final_raid = int(ui.state.run["raid"]) + 1 >= int(Data.BALANCE["raids"])
	var trait_reward: bool = ui.traits_screen.reward_after_raid()
	var remaining = 0
	for body in rewards:
		if not body["claimed"]: remaining += 1
	if ui.feed_body < 0 or ui.feed_body >= rewards.size(): ui.feed_body = 0
	if not rewards.is_empty() and rewards[ui.feed_body]["claimed"] and remaining > 0:
		for i in range(rewards.size()):
			if not rewards[i]["claimed"]:
				ui.feed_body = i
				break
	page.add_child(ui.label("3 / Feed the fallen", 25 if compact else 27, ui.PARCHMENT, compact))
	ui.screens.raid_recap(page)
	ui.traits_screen.summary(page, false)
	var next_step = "NEXT: Recover & continue to complete the campaign." if final_raid else "NEXT: Recover & continue. Then prepare the next raid."
	if trait_reward: next_step = "NEXT: Recover & continue, then choose a dungeon trait that lasts for this run."
	if remaining > 0:
		var body = rewards[ui.feed_body]
		var monster = ui.state.get_monster(ui.feed_monster)
		if monster.is_empty():
			next_step = "NEXT: 2 / Choose a recipient for " + body["name"] + ", or select a different body."
		elif ui.state.inheritance_outcomes(ui.feed_body, ui.feed_monster).is_empty():
			next_step = "NEXT: Choose another recipient or skip this body. This monster knows every offered skill."
		else:
			next_step = "NEXT: 3 / Devour " + body["name"] + " with " + monster["name"] + " to inherit one random skill."
	page.add_child(ui.label(next_step, 14, ui.EMBER, true))
	_meal_results(rewards, page)
	var columns = VBoxContainer.new() if compact else HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not compact: columns.custom_minimum_size.y = 390
	page.add_child(columns)
	var bodies = ui.panel(columns)
	bodies.custom_minimum_size.x = 0 if compact else 230
	bodies.add_child(ui.label("1 / SELECT BODY", 14, ui.EMBER))
	var body_options = HBoxContainer.new() if compact else bodies
	if compact:
		body_options.add_theme_constant_override("separation", 5)
		bodies.add_child(body_options)
	for i in range(rewards.size()):
		var body = rewards[i]
		var status = ("Skipped" if body.get("skipped", false) else "Devoured") if body["claimed"] else body["class_name"]
		var entry = ui.button(body["name"] + "\n" + status, func():
			ui.feed_body = i
			ui.refresh())
		entry.name = "Body_%d" % i
		entry.custom_minimum_size.y = 68
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if compact:
			entry.add_theme_font_size_override("font_size", 13)
			entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.disabled = body["claimed"]
		if i == ui.feed_body and not body["claimed"]:
			entry.add_theme_stylebox_override("normal", ui.style(Color("424832"), ui.EMBER))
		body_options.add_child(entry)
	var filler = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if compact: filler.free()
	else: bodies.add_child(filler)
	bodies.add_child(ui.label(str(remaining) + " bodies remaining", 14, ui.MUTED))
	bodies.add_child(ui.label("Devour or skip every body to unlock recovery." if remaining > 0 else "All bodies resolved. Recovery is ready.", 12, ui.MUTED, true))
	var continue_button = ui.primary("Recover & continue", func(): ui.act(ui.state.finish_feeding, "The team recovers after the raid."))
	continue_button.disabled = remaining > 0
	bodies.add_child(continue_button)
	var feeding = ui.panel(columns, true)
	feeding.custom_minimum_size.x = 0 if compact else 390
	if remaining > 0:
		_body_choices(ui.feed_body, rewards[ui.feed_body], feeding)
	else:
		feeding.add_child(ui.label("The meal is finished.", 22 if compact else 24, ui.MOSS, compact))
		var instructions = "Next: Recover & continue to complete the campaign and receive rank D promotion." if final_raid else "Next: Recover & continue to restore health. You can select learned skills and any earned transformation before the next raid."
		if trait_reward: instructions = "Next: Recover & continue to restore health, then choose a lasting dungeon trait. Your equipped cards will help you compare the choices."
		feeding.add_child(ui.label(instructions, 16, ui.MUTED, true))
	var team = ui.panel(columns)
	team.custom_minimum_size.x = 0 if compact else 345
	team.add_child(ui.label("YOUR MONSTERS / DISCOVERIES" if final_raid else "YOUR MONSTERS / NEXT DECK", 14 if compact else 15, ui.MOSS, compact))
	var roster = team if compact else ui.scroll(team)
	for monster in ui.state.run["monsters"]:
		var group = VBoxContainer.new()
		group.add_theme_constant_override("separation", 5)
		roster.add_child(group)
		var row = HBoxContainer.new()
		group.add_child(row)
		row.add_child(ui.portrait(monster, 46))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(monster["name"] + "  ·  " + ui.form_name(monster["form"]), 15, ui.PARCHMENT, compact))
		info.add_child(ui.label(str(monster["feeds"]) + " meals  ·  " + str(monster["hp"]) + " / " + str(monster["max_hp"]) + " HP", 12, ui.MUTED))
		ui.screens.form_tactic(monster["form"], group, "FormTacticFeeding_" + monster["id"])
		ui.screens.consumed_affinities(monster, group)
		var picks = VBoxContainer.new() if compact else HBoxContainer.new()
		group.add_child(picks)
		for slot in range(2):
			var picker = ui.screens.skill_picker(monster, slot)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.custom_minimum_size.x = 0 if compact else 140
			picks.add_child(picker)
			if compact:
				picks.add_child(ui.label(Data.ABILITIES[monster["selected"][slot]]["description"], 13, ui.MUTED, true))
		if not ui.state.eligible(monster["id"]).is_empty():
			var can_evolve = int(ui.state.run.get("evolution_budget", 1)) > 0
			var transform = ui.primary("Transformation available" if can_evolve else "Earned / available in preparation", func(): ui.screens.evolution_choices(monster))
			if compact:
				transform.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				transform.add_theme_font_size_override("font_size", 14)
			transform.disabled = not can_evolve
			transform.tooltip_text = "One transformation is allowed after each body consumed. Earned choices remain available during preparation."
			group.add_child(transform)
		var separator = HSeparator.new()
		separator.modulate = Color("465039")
		group.add_child(separator)

func _meal_results(rewards: Array, parent: Node) -> void:
	var lines: Array = []
	for body in rewards:
		if not body.get("claimed", false): continue
		var inherited: String = str(body.get("taken", ""))
		if inherited != "":
			var monster: Dictionary = ui.state.get_monster(str(body.get("recipient", "")))
			lines.append("INHERITED: %s learned %s (%s) from %s." % [monster.get("name", "Your monster"), ui.ability_name(inherited), Data.ABILITIES[inherited]["affinity"], body["name"]])
		elif body.get("skipped", false):
			lines.append(body["name"] + " was left behind.")
	if lines.is_empty(): return
	var receipt = ui.panel(parent)
	var result = ui.label("\n".join(lines), 14 if ui.is_compact() else 16, ui.MOSS, true)
	result.name = "InheritedResult"
	receipt.add_child(result)
	receipt.add_child(ui.label("New skills are available in this team's deck selectors below. Armor is not inherited.", 12, ui.MUTED, true))
	var received: Dictionary = _received_skill(rewards)
	if received.is_empty(): return
	var monster: Dictionary = received["monster"]
	var id: String = received["ability"]
	var ability: Dictionary = Data.ABILITIES[id]
	var skill = ui.label("%s's new skill / %s · %d energy\n%s" % [monster["name"], ability["name"], ability["cost"], ability["description"]], 14, ui.PARCHMENT, true)
	skill.name = "InheritedSkillDetail"
	receipt.add_child(skill)
	var equipped: int = monster["selected"].find(id)
	var status = ui.label("EQUIPPED / %s will play %s in skill slot %d next raid." % [monster["name"], ability["name"], equipped + 1] if equipped >= 0 else "Not in the next deck yet. Choose which skill to replace below.", 13, ui.MOSS if equipped >= 0 else ui.EMBER, true)
	status.name = "InheritedEquipStatus"
	receipt.add_child(status)
	if equipped >= 0: return
	var actions = VBoxContainer.new() if ui.is_compact() else HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	receipt.add_child(actions)
	for slot in range(2):
		var replace = ui.button("Replace " + ui.ability_name(monster["selected"][slot]), func(): _equip_received(monster["id"], slot, id))
		replace.name = "EquipInherited_%d" % slot
		replace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		replace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(replace)

func _received_skill(rewards: Array) -> Dictionary:
	var latest = ui.state.run.get("last_meal", {})
	var order: Array = []
	if latest is Dictionary:
		var selected_body: int = int(latest.get("body", -1))
		if selected_body >= 0 and selected_body < rewards.size(): order.append(selected_body)
	# Older saves have the persistent corpse receipts but no last-meal index.
	# Keep those skills usable without inventing an inheritance result.
	for index in range(rewards.size() - 1, -1, -1):
		if not order.has(index): order.append(index)
	for index in order:
		var body: Dictionary = rewards[index]
		var id: String = str(body.get("taken", ""))
		if not body.get("claimed", false) or not Data.ABILITIES.has(id): continue
		var monster: Dictionary = ui.state.get_monster(str(body.get("recipient", "")))
		if monster.is_empty() or not monster["learned"].has(id): continue
		return {"monster": monster, "ability": id}
	return {}

func _equip_received(monster_id: String, slot: int, ability_id: String) -> void:
	if not ui.state.set_selected(monster_id, slot, ability_id): return
	ui.card_index = -1
	ui.refresh()
	ui.toast.text = "%s equipped %s. The next raid's deck is updated." % [ui.state.get_monster(monster_id)["name"], ui.ability_name(ability_id)]
	call_deferred("_focus_receipt")

func _body_choices(body_index: int, body: Dictionary, box: VBoxContainer) -> void:
	var compact = ui.is_compact()
	var row = HBoxContainer.new()
	box.add_child(row)
	row.add_child(ui.portrait(body, 58 if compact else 82))
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(ui.label(body["name"], 21 if compact else 24, ui.PARCHMENT, compact))
	info.add_child(ui.label("Selected body / " + body["class_name"] + ". One devour, one random skill.", 13, ui.MUTED, true))
	info.add_child(ui.label("Armor %d · Armor is not inherited" % Data.armor(body), 12, ui.MUTED, true))
	var monster = ui.state.get_monster(ui.feed_monster)
	var has_recipient = not monster.is_empty()
	box.add_child(ui.label("2 / SELECT RECIPIENT", 14, ui.MOSS if has_recipient else ui.EMBER))
	var recipients = HBoxContainer.new()
	recipients.add_theme_constant_override("separation", 6)
	box.add_child(recipients)
	for recipient in ui.state.run["monsters"]:
		var pick = ui.button(recipient["name"], func():
			ui.feed_monster = recipient["id"]
			ui.refresh())
		pick.name = "Recipient_" + recipient["id"]
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ui.feed_monster == recipient["id"]:
			pick.add_theme_stylebox_override("normal", ui.style(Color("424832"), ui.MOSS))
		recipients.add_child(pick)
	box.add_child(ui.label("3 / DEVOUR FOR A RANDOM SKILL", 14, ui.EMBER if has_recipient else ui.MUTED, true))
	box.add_child(ui.label("Common skills are more likely. Known skills are excluded from the roll.", 13, ui.MUTED, true))
	var choices = box if compact else ui.scroll(box)
	if not compact: choices.get_parent().custom_minimum_size.y = 70
	var outcomes: Array = ui.state.inheritance_outcomes(body_index, ui.feed_monster)
	if not has_recipient:
		choices.add_child(ui.label("Choose a recipient to see their possible skills and chances.", 13, ui.MUTED, true))
	elif outcomes.is_empty():
		choices.add_child(ui.label("This monster knows every offered skill. Choose another recipient or skip this body.", 13, ui.MUTED, true))
	for outcome in outcomes:
		var id: String = outcome["ability"]
		var ability: Dictionary = Data.ABILITIES[id]
		var option = ui.label("%s · %.1f%% · %s · %s" % [ability["name"], float(outcome["chance"]) * 100, str(outcome["rarity"]).capitalize(), ability["affinity"]], 14, ui.PARCHMENT, true)
		option.name = "InheritanceChance_" + id
		choices.add_child(option)
		choices.add_child(ui.label("%d energy · %s" % [ability["cost"], ability["description"]], 12, ui.MUTED, true))
	var ready = has_recipient and not outcomes.is_empty()
	var summary = "Choose a recipient, then devour. The skill is rolled when you press Devour & inherit."
	if ready: summary = "READY: %s devours %s and inherits one skill from the chances above." % [monster["name"], body["name"]]
	var ready_label = ui.label(summary, 14, ui.EMBER if ready else ui.MUTED, true)
	ready_label.name = "DevourSummary"
	box.add_child(ready_label)
	var actions = VBoxContainer.new() if compact else HBoxContainer.new()
	box.add_child(actions)
	var confirm = ui.primary("Devour & inherit", func(): _devour(body_index, ui.feed_monster))
	confirm.name = "DevourBody"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.disabled = not ready
	actions.add_child(confirm)
	actions.add_child(ui.button("Skip body", func(): ui.act(func(): ui.state.skip_body(body_index), "The body was left behind.")))

func _devour(body_index: int, recipient: String) -> void:
	if not ui.state.claim_body(body_index, recipient): return
	ui.card_index = -1
	ui.refresh()
	# The receipt is part of the page, so phones never depend on the hidden toast.
	call_deferred("_focus_receipt")

func _focus_receipt() -> void:
	if is_instance_valid(_page_scroll) and ui.menu == "game" and ui.state.run.get("phase", "") == "feeding":
		_page_scroll.scroll_vertical = 0

func reveal(info: Dictionary) -> void:
	var compact = ui.is_compact()
	var box = ui.open_modal()
	box.add_child(ui.label("A NEW PAGE IN THE GRIMOIRE", 13 if compact else 15, ui.EMBER, true))
	var monster = ui.state.get_monster(info["monster_id"])
	box.add_child(ui.label(monster["name"] + " becomes…", 22 if compact else 24, ui.PARCHMENT, true))
	var art = ui.portrait({"form": info["to"]}, 124 if compact else 220)
	box.add_child(art)
	box.add_child(ui.label(ui.form_name(info["to"]), 26 if compact else 33, ui.MOSS, true))
	var health = ui.label("New health: %d / %d HP" % [monster["hp"], monster["max_hp"]], 16, ui.MOSS, true)
	health.name = "FormRevealHealth"
	box.add_child(health)
	box.add_child(ui.label(Data.FORMS[info["to"]]["passive"], 17, ui.PARCHMENT, true))
	ui.screens.form_tactic(info["to"], box, "FormTacticReveal_" + info["to"])
	var signature: String = Data.FORMS[info["to"]]["signature"]
	box.add_child(ui.label("New signature: %s · %d energy" % [ui.ability_name(signature), Data.ABILITIES[signature]["cost"]], 15 if compact else 16, ui.EMBER, true))
	var effect = ui.label(Data.ABILITIES[signature]["description"], 14, ui.PARCHMENT, true)
	effect.name = "FormRevealSignatureEffect"
	box.add_child(effect)
	box.add_child(ui.label("Identity and learned skills preserved. Health keeps its current percentage. This discovery is yours forever.", 14, ui.MUTED, true))
	var accept = ui.primary("Welcome the transformation", ui.close_modal)
	accept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(accept)
	art.modulate = Color(0.5, 0.55, 0.35, 0.2)
	var tween = art.create_tween()
	tween.tween_property(art, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
