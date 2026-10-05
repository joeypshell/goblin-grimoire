extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Copy = preload("res://scripts/combat_copy.gd")
const Parts = preload("res://scripts/ui_combat_parts.gd")
const Battlefield = preload("res://scripts/ui_battlefield.gd")
const CardFace = preload("res://scripts/ui_card.gd")
var ui
var parts
var compact_side: String = "enemies"
var compact_battle
var compact_selected_id: String = ""

func _init(owner) -> void:
	ui = owner
	parts = Parts.new(ui, self)

func render() -> void:
	if ui.is_compact(): _render_compact()
	else: _render_desktop()

func _banner(parent: Node, compact: bool) -> void:
	var battle = ui.combat_battle()
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var row = HBoxContainer.new()
	box.add_child(row)
	var title: String = "YOUR TURN"
	if ui.resolving_turn:
		title = {"player_end": "YOUR TURN ENDS", "enemy": "INVADERS' TURN", "enemy_end": "ENEMY TURN ENDS", "draw": "NEW PLAYER TURN"}.get(ui.turn_stage, "INVADERS' TURN")
		if ui.turn_stage == "finish": title = "RAID CLEARED" if battle.outcome == "won" else "DUNGEON BREACHED"
	var phase = ui.label(title, 18 if compact else 28, ui.EMBER if ui.resolving_turn else ui.MOSS)
	phase.name = "TurnPhase"
	phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(phase)
	row.add_child(ui.label("%d / %d ENERGY" % [battle.energy, Data.BALANCE["energy"]], 16 if compact else 23, ui.EMBER))
	var context: String = "ROUND %d · Draw %d · Discard %d · Targets locked" % [battle.turn, battle.draw_pile.size(), battle.discard.size()]
	if ui.resolving_turn: context = "Cards paused · watch the highlighted actor and target"
	var build: String = ui.traits_screen.combat_summary(battle)
	if build != "":
		context = ("Cards paused" if ui.resolving_turn else "ROUND %d · Draw %d · Discard %d" % [battle.turn, battle.draw_pile.size(), battle.discard.size()]) + " · " + build
	var uses_field: bool = not compact or (not ui.is_portrait() and ui.get_viewport_rect().size.x >= 900 and ui.get_viewport_rect().size.y >= 560)
	if uses_field and not ui.resolving_turn:
		var captain: String = Copy.banner_guidance(battle)
		if captain != "": context += " · " + captain
	var counter = ui.label(context, 11 if compact else 13, ui.MUTED, true)
	counter.name = "DeckCounter"
	box.add_child(counter)

func _render_desktop() -> void:
	var battle = ui.combat_battle()
	ui.content.add_theme_constant_override("separation", 8)
	_banner(ui.content, false)
	_stage(ui.content, battle)
	_instruction(ui.content, false)
	var center = CenterContainer.new()
	ui.content.add_child(center)
	var hand = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 10)
	center.add_child(hand)
	for index in range(battle.hand.size()): parts.card(index, hand, false)
	if battle.hand.is_empty(): hand.add_child(ui.label(_empty_hand_message(), 16, ui.MUTED))
	_footer(false)

func _stage(parent: Node, battle) -> void:
	var board = VBoxContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 3)
	parent.add_child(board)
	var titles = HBoxContainer.new()
	board.add_child(titles)
	for side in ["YOUR MONSTERS · PLAY CARDS TO ACT", "INVADERS · ANNOUNCED ACTIONS"]:
		var heading = ui.label(side, 12, ui.MOSS if side.begins_with("YOUR") else ui.EMBER)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titles.add_child(heading)
	var center = HBoxContainer.new()
	center.add_theme_constant_override("separation", 0)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_child(center)
	var left = Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(left)
	var holder = Control.new()
	holder.name = "BattlefieldHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(minf(ui.content_width(), 1400), 140)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(holder)
	var stage = Battlefield.new()
	stage.size = Vector2(holder.custom_minimum_size.x, 140)
	holder.add_child(stage)
	# Allocated space only controls geometry, never a container's minimum size.
	holder.resized.connect(func():
		if not is_instance_valid(stage): return
		stage.size = Vector2(holder.size.x, minf(holder.size.y, 360))
		stage.position = Vector2(0, (holder.size.y - stage.size.y) / 2))
	var right = Control.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(right)
	stage.setup(ui, battle)
	ui.battlefield = stage

func _render_compact() -> void:
	var battle = ui.combat_battle()
	if compact_battle != battle:
		compact_battle = battle
		compact_side = "enemies"
		compact_selected_id = ""
	if ui.card_index >= 0 and ui.card_index < battle.hand.size():
		var card: Dictionary = battle.hand[ui.card_index]
		if compact_selected_id != card["id"]:
			compact_selected_id = card["id"]
			compact_side = "monsters" if Data.ABILITIES[card["ability"]]["target"] in ["ally", "all_allies", "self"] else "enemies"
	else: compact_selected_id = ""
	var portrait: bool = ui.is_portrait()
	var short_landscape: bool = not portrait and ui.get_viewport_rect().size.y < 440
	ui.content.add_theme_constant_override("separation", 5)
	var layout: VBoxContainer = ui.content
	var body_scroll: ScrollContainer
	if short_landscape:
		body_scroll = ScrollContainer.new()
		body_scroll.name = "CombatBodyScroll"
		body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ui.content.add_child(body_scroll)
		layout = VBoxContainer.new()
		layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layout.add_theme_constant_override("separation", 5)
		body_scroll.add_child(layout)
	_banner(layout, true)
	if portrait:
		if ui.resolving_turn:
			var watching = ui.label("Acting invader and targets" if ui.turn_stage == "enemy" else ("Monster effects" if ui.turn_stage == "player_end" else "Turn results and next steps"), 13, ui.EMBER, true)
			watching.custom_minimum_size.y = 44
			watching.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			layout.add_child(watching)
		else:
			var tabs = HBoxContainer.new()
			tabs.add_theme_constant_override("separation", 5)
			layout.add_child(tabs)
			_side_tab(tabs, "monsters", battle.monsters)
			_side_tab(tabs, "enemies", battle.enemies)
		var visible_actors: Array = battle.monsters if compact_side == "monsters" else battle.enemies
		if ui.resolving_turn:
			visible_actors = []
			if ui.acting_actor_id != "": visible_actors.append(battle.get_actor(ui.acting_actor_id))
			for id in ui.acting_target_ids:
				var receiver: Dictionary = battle.get_actor(id)
				if not visible_actors.has(receiver): visible_actors.append(receiver)
			if visible_actors.is_empty(): visible_actors = battle.monsters if ui.turn_stage in ["player_end", "draw"] else battle.enemies
		var actors = _actor_scroll(layout, 100)
		for actor in visible_actors:
			if not actor.is_empty(): parts.actor(actor, actors, not battle._is_monster(actor["id"]), true)
	elif ui.get_viewport_rect().size.x >= 900 and ui.get_viewport_rect().size.y >= 560:
		_stage(layout, battle)
	else:
		var board = HBoxContainer.new()
		board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board.add_theme_constant_override("separation", 8)
		layout.add_child(board)
		for side in ["monsters", "enemies"]:
			var column = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_theme_constant_override("separation", 3)
			board.add_child(column)
			column.add_child(ui.label("YOUR MONSTERS" if side == "monsters" else "INVADERS · NEXT ACTIONS", 12, ui.MOSS if side == "monsters" else ui.EMBER))
			var actors = _actor_scroll(column, 116 if short_landscape else 55)
			for actor in battle.monsters if side == "monsters" else battle.enemies:
				parts.actor(actor, actors, side == "enemies", true)
	_instruction(layout, true)
	var card_scroll = ScrollContainer.new()
	card_scroll.name = "HandScroll"
	card_scroll.custom_minimum_size.y = 158 if portrait else 112
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(card_scroll)
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	card_scroll.add_child(cards)
	for index in range(battle.hand.size()): parts.card(index, cards, true, portrait)
	if battle.hand.is_empty(): cards.add_child(ui.label(_empty_hand_message(), 13, ui.MUTED))
	_footer(true)
	if short_landscape and (ui.card_index >= 0 or ui.resolving_turn): call_deferred("_queue_short_focus", body_scroll)

func _queue_short_focus(body_scroll) -> void:
	if not is_instance_valid(body_scroll) or not body_scroll.is_inside_tree(): return
	call_deferred("_focus_short_targets", body_scroll)

func _focus_short_targets(body_scroll) -> void:
	if is_instance_valid(body_scroll) and body_scroll.is_inside_tree(): body_scroll.scroll_vertical = 0

func _actor_scroll(parent: Node, minimum_height: float) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.custom_minimum_size.y = minimum_height
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var actors = VBoxContainer.new()
	actors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actors.add_theme_constant_override("separation", 5 if ui.is_compact() else 3)
	sc.add_child(actors)
	return actors

func _side_tab(parent: Node, side: String, actors: Array) -> void:
	var living: int = 0
	var hp: int = 0
	for actor in actors:
		if actor["hp"] > 0: living += 1
		hp += int(actor["hp"])
	var tab = ui.button(("Your monsters" if side == "monsters" else "Invaders") + " %d · %d HP" % [living, hp], func():
		compact_side = side
		ui.refresh())
	tab.name = "Side_" + side
	tab.custom_minimum_size.y = 44
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_font_size_override("font_size", 12)
	tab.disabled = ui.resolving_turn
	if side == compact_side: tab.add_theme_stylebox_override("normal", ui.style(Color("454732"), ui.EMBER, 8))
	parent.add_child(tab)

func _instruction(parent: Node, compact: bool) -> void:
	var battle = ui.combat_battle()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var sc = ScrollContainer.new()
	sc.custom_minimum_size.y = (88 if ui.resolving_turn or ui.last_action != "" else (72 if ui.card_index >= 0 else 44)) if compact else 64
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	var message: String = Copy.guidance(battle, ui.card_index, ui.resolving_turn, ui.turn_message)
	if ui.resolving_turn:
		if ui.turn_detail != "": message += "\n" + ui.turn_detail
	elif ui.card_index < 0 and ui.last_action != "": message += "\n" + ui.last_action
	if compact and not ui.is_portrait() and ui.get_viewport_rect().size.y < 440 and ui.card_index < 0 and not ui.resolving_turn:
		message += " Scroll down for cards; choosing one returns to targets."
	var explanation = ui.label(message, 13 if compact else 15, ui.EMBER if ui.card_index >= 0 or ui.resolving_turn else ui.MUTED, true)
	explanation.name = "CardExplanation"
	sc.add_child(explanation)
	if ui.card_index >= 0 and not ui.resolving_turn:
		var cancel = ui.button("Cancel", func():
			ui.card_index = -1
			ui.refresh())
		cancel.add_theme_font_size_override("font_size", 13)
		row.add_child(cancel)

func _empty_hand_message() -> String:
	if ui.resolving_turn:
		if ui.turn_stage == "draw": return "Drawing your next hand..."
		if ui.turn_stage == "finish": return "Combat resolved. Next screen follows."
		return "Your next hand arrives after invaders finish."
	return "No cards remain. End your turn for a new hand."

func show_card_details(index: int) -> void:
	if ui.resolving_turn: return
	var battle = ui.combat_battle()
	if index < 0 or index >= battle.hand.size(): return
	var card: Dictionary = battle.hand[index]
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var box = ui.open_modal()
	box.add_child(ui.label(ability["name"], 24, ui.EMBER, true))
	var texture: Texture2D = CardFace.texture_for(card["ability"])
	if texture != null:
		var art = TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size.y = 150 if ui.is_compact() else 220
		box.add_child(art)
	box.add_child(ui.label("%s · %d energy" % [Copy.owner_name(battle, card), ability["cost"]], 16, ui.MOSS, true))
	box.add_child(ui.label(ability["description"], 16, ui.PARCHMENT, true))
	box.add_child(ui.label("Affinity: " + ability["affinity"], 14, ui.MOSS, true))
	for effect in ability["effects"]:
		if effect.get("status", "") in ["poison", "burn", "regen"]:
			box.add_child(ui.label("Each application ticks and decays separately. Reapplying adds another application.", 14, ui.MUTED, true))
			break
	box.add_child(ui.label(Copy.target_prompt(ability["target"]), 14, ui.MUTED, true))
	box.add_child(ui.button("Return to targets", ui.close_modal))

func _footer(compact: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	ui.content.add_child(row)
	if not compact:
		var next = ui.label(Copy.next_step(ui.combat_battle(), ui.resolving_turn), 13, ui.MUTED, true)
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(next)
	var history = ui.button("Log & rules", _show_log)
	history.disabled = ui.resolving_turn
	history.add_theme_font_size_override("font_size", 13)
	row.add_child(history)
	if ui.resolving_turn:
		var skip = ui.primary("Skip animation", ui.skip_turn_animation)
		skip.name = "SkipTurn"
		skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skip.add_theme_font_size_override("font_size", 13)
		row.add_child(skip)
	else:
		var end = ui.primary("End your turn\nInvaders act next" if compact else "End your turn  [Space]", ui.end_player_turn, 0 if compact else 220)
		end.name = "EndTurn"
		end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		end.add_theme_font_size_override("font_size", 12 if compact else 16)
		end.tooltip_text = Copy.next_step(ui.combat_battle(), false)
		row.add_child(end)

func _show_log() -> void:
	if ui.resolving_turn: return
	var box = ui.open_modal()
	box.custom_minimum_size.y = minf(420, ui.get_viewport_rect().size.y - 70)
	box.add_child(ui.label("The chamber's record", 21 if ui.is_compact() else 25, ui.EMBER))
	var history = ui.scroll(box)
	ui.traits_screen.rules(history, ui.combat_battle())
	for entry in ui.combat_battle().log: history.add_child(ui.label(entry, 14, ui.PARCHMENT, true))
	for rule in [
		"Your monsters act through owned cards. Costs use your shared energy. Unplayed cards discard at turn end. Healing cards cycle normally and can be reused.",
		"Each round, offensive invader actions choose random living monsters. Their shown actions and targets stay locked until resolution. Surviving invaders act in the shown order; a defeated target redirects to the first valid living target.",
		"Armor reduces each direct hit before Block and stays for the battle. Block absorbs remaining damage and expires at that faction's next turn. Poison and Burn bypass Armor and Block.",
		"Poison, Burn and Regeneration keep separate applications. At faction turn end, each application ticks and then loses 1 strength. Two Poison 3 applications deal 6, then 4, then 2 damage. Regeneration follows the same timing for healing.",
		"Stun causes one skipped invader action or prevents a monster's owned cards for one player turn. Stun does not stack. After skipping, Resolve protects against Stun through the next normal action or player turn, then expires. Other card effects still apply to a protected target.",
		"Mend restores HP and cleanses every Poison and Burn application on its target. It does not remove other statuses."
	]: history.add_child(ui.label(rule, 13, ui.MUTED, true))
	history.add_child(ui.label("Captain Torren's Banner Volley is announced every third round: 5 damage and 1 Burn to all monsters. Stun skips the volley unless Resolve prevents Stun. Defeating the captain cancels his pending action and future volleys.", 13, ui.MUTED, true))
	var motion = CheckButton.new()
	motion.name = "ReduceMotion"
	motion.text = "Reduce motion"
	motion.custom_minimum_size.y = 44
	motion.button_pressed = ui.reduced_motion
	motion.toggled.connect(func(value): ui.set_reduced_motion(value, true))
	box.add_child(motion)
	box.add_child(ui.button("Playtest reports", ui.report_ui.open))
	box.add_child(ui.button("Return to battle", ui.close_modal))
