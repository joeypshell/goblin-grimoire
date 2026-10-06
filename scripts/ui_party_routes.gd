extends RefCounted

const Data = preload("res://scripts/game_data.gd")
var ui

func _init(owner) -> void:
	ui = owner

func render(parent: Node) -> void:
	var options: Array = ui.state.party_choices()
	if options.is_empty():
		if ui.state.run.get("party_locked", false) and ui.state.run.get("last_result", "") == "breach":
			var retry = ui.label("RETRY / This party is locked. Prepare your skills, then face the same invaders again.", 14, ui.EMBER, true)
			retry.name = "PartyRetryNotice"
			parent.add_child(retry)
		return
	var compact: bool = ui.is_compact()
	var heading = ui.label("CHOOSE YOUR INVADERS", 17 if compact else 19, ui.EMBER, true)
	heading.name = "PartyChoiceHeading"
	parent.add_child(heading)
	parent.add_child(ui.label("Pick the threats and possible meals that suit your build. You can switch until you Defend; that party then stays locked for retries. Inherited skills are still random.", 13, ui.MUTED, true))
	var cards = VBoxContainer.new() if compact else HBoxContainer.new()
	cards.name = "PartyChoices"
	cards.add_theme_constant_override("separation", 12)
	parent.add_child(cards)
	for option in options:
		_route_card(option, cards)

func _route_card(option: Dictionary, parent: Node) -> void:
	var id: String = option["id"]
	var selected: bool = ui.state.run.get("party_choice", "standard") == id
	var box = ui.panel(parent, true)
	box.name = "PartyChoice_" + id
	box.add_theme_constant_override("separation", 6)
	if selected:
		box.get_parent().add_theme_stylebox_override("panel", ui.style(Color("2b3528"), ui.MOSS, 12))
	var status = ui.label("SELECTED PARTY" if selected else "ALTERNATIVE PARTY", 12, ui.MOSS if selected else ui.MUTED)
	status.name = "PartyChoiceStatus_" + id
	box.add_child(status)
	box.add_child(ui.label(option["name"], 20, ui.PARCHMENT, true))
	box.add_child(ui.label(option["description"], 13, ui.MUTED, true))
	for actor in option["party"]:
		var class_id: String = actor.get("class_name", actor.get("form", ""))
		var actor_class: String = Data.CLASSES.get(class_id, {}).get("name", class_id.capitalize())
		var member = ui.label("%s · %d HP · Armor %d" % [actor_class, int(actor["max_hp"]), Data.armor(actor)], 13, ui.PARCHMENT, true)
		member.name = "PartyMember_" + id + "_" + str(actor["id"])
		box.add_child(member)
		var rule_text: String = Data.encounter_rule_text(actor)
		if rule_text != "":
			var rule = ui.label(rule_text, 13, ui.EMBER, true)
			rule.name = "PartyRule_" + id + "_" + str(actor["id"])
			box.add_child(rule)
	var affinities: Array = meal_affinities(option["party"])
	var opportunities = ui.label("Possible meal affinities: " + (", ".join(affinities) if not affinities.is_empty() else "No unknown non-Neutral skills for this team"), 13, ui.MOSS, true)
	opportunities.name = "PartyAffinities_" + id
	box.add_child(opportunities)
	var action = ui.button("Selected / inspect below" if selected else "Choose this party", func(): _select(id))
	action.name = "PartySelect_" + id
	action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action.disabled = selected
	if selected:
		action.add_theme_color_override("font_disabled_color", ui.MOSS)
	box.add_child(action)

func meal_affinities(party: Array) -> Array:
	# Use actual skills that at least one recipient can still inherit.
	var result: Array = []
	for actor in party:
		for monster in ui.state.run.get("monsters", []):
			for outcome in Data.inheritance_outcomes(actor.get("abilities", []), monster.get("learned", [])):
				var affinity: String = Data.ABILITIES[outcome["ability"]]["affinity"]
				if affinity != "Neutral" and not result.has(affinity): result.append(affinity)
	return result

func _select(id: String) -> void:
	if not ui.state.select_party(id): return
	ui.card_index = -1
	ui.refresh()
	ui.toast.text = "Selected " + ui.state.selected_party_name() + ". Inspect the incoming party below, then Defend when ready."
