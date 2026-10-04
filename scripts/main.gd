extends Control

const State = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/game_data.gd")
const Screens = preload("res://scripts/ui_screens.gd")
const CombatScreen = preload("res://scripts/ui_battle.gd")
const RewardsScreen = preload("res://scripts/ui_rewards.gd")
const Portrait = preload("res://scripts/monster_portrait.gd")
const Chamber = preload("res://scripts/ui_chamber.gd")

const INK = Color("161c19")
const PANEL = Color("222b24")
const PARCHMENT = Color("e4dbbe")
const MUTED = Color("aab5a3")
const MOSS = Color("b3ce78")
const EMBER = Color("f2ad65")
const RED = Color("e68b7c")

var state
var menu = "title"
var content: VBoxContainer
var root_box: VBoxContainer
var toast: Label
var overlay: Control
var card_index = -1
var feed_body = 0
var feed_monster = ""
var feed_ability = ""
var grimoire_return = "title"
var screens
var combat_screen
var rewards_screen
var actor_nodes: Dictionary = {}

func _ready() -> void:
	state = State.new()
	screens = Screens.new(self)
	combat_screen = CombatScreen.new(self)
	rewards_screen = RewardsScreen.new(self)
	_apply_theme()
	var room = Chamber.new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24 if edge in ["left", "right"] else 18)
	add_child(margin)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)
	refresh()

func _apply_theme() -> void:
	var t = Theme.new()
	var base_font = preload("res://assets/fonts/NotoSans.ttf")
	base_font.fallbacks = [preload("res://assets/fonts/NotoSansSymbols2.ttf")]
	var font = FontVariation.new()
	font.base_font = base_font
	font.spacing_top = -3
	font.spacing_bottom = -3
	t.default_font = font
	t.default_font_size = 16
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color("fff2d5"))
	t.set_color("font_disabled_color", "Button", Color("7d887b"))
	t.set_color("font_color", "OptionButton", PARCHMENT)
	t.set_stylebox("panel", "PanelContainer", style(PANEL, Color("475140"), 12))
	t.set_stylebox("normal", "Button", style(Color("303a2b"), Color("576349"), 8))
	t.set_stylebox("hover", "Button", style(Color("424c32"), MOSS, 8))
	t.set_stylebox("pressed", "Button", style(Color("555336"), EMBER, 8))
	t.set_stylebox("disabled", "Button", style(Color("252b25"), Color("394135"), 8))
	t.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), EMBER, 8))
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(kind, "OptionButton", t.get_stylebox(kind, "Button"))
	var health_background = style(Color("101914"), Color("3b4738"), 3)
	var health_fill = style(MOSS, MOSS, 3)
	for s in [health_background, health_fill]:
		s.content_margin_left = 0
		s.content_margin_right = 0
		s.content_margin_top = 0
		s.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", health_background)
	t.set_stylebox("fill", "ProgressBar", health_fill)
	t.set_constant("outline_size", "Label", 0)
	theme = t

func style(fill: Color, line: Color, radius: int = 8) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = line
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func refresh() -> void:
	actor_nodes.clear()
	for child in root_box.get_children():
		root_box.remove_child(child)
		child.queue_free()
	_header()
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root_box.add_child(content)
	if menu == "title":
		screens.title_screen()
	elif menu == "grimoire":
		screens.grimoire()
	else:
		match state.run.get("phase", "prep"):
			"prep": screens.preparation()
			"combat": combat_screen.render()
			"feeding": rewards_screen.render()
			"result", "victory", "defeat": screens.results()
	toast = label("A dungeon lives through the choices of its keeper.", 13, MUTED)
	root_box.add_child(toast)

func _header() -> void:
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	root_box.add_child(bar)
	var mark = Control.new()
	mark.custom_minimum_size = Vector2(24, 36)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func(): mark.draw_colored_polygon(PackedVector2Array([Vector2(12, 7), Vector2(16, 14), Vector2(23, 18), Vector2(16, 22), Vector2(12, 29), Vector2(8, 22), Vector2(1, 18), Vector2(8, 14)]), EMBER))
	bar.add_child(mark)
	bar.add_child(label("GOBLIN GRIMOIRE", 21, PARCHMENT))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	if menu == "game" and not state.run.is_empty():
		bar.add_child(label("RANK " + state.rank_name() + "  ·  RAID " + str(min(int(state.run["raid"]) + 1, int(Data.BALANCE["raids"]))) + " / " + str(Data.BALANCE["raids"]), 15, MOSS))
		bar.add_child(label("CORE  " + str(state.run["core"]) + " / " + str(Data.BALANCE["core"]), 17, EMBER))
	if menu != "grimoire":
		bar.add_child(button("Grimoire", open_grimoire))
	if menu == "game":
		bar.add_child(button("Save & title", func():
			state.save_game()
			menu = "title"
			refresh()))
	var line = HSeparator.new()
	line.modulate = Color("596148")
	root_box.add_child(line)

func label(value: String, size: int = 16, color: Color = PARCHMENT, wrap: bool = false) -> Label:
	var node = Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func button(value: String, action: Callable, min_width: float = 0) -> Button:
	var node = Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(min_width, 42)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(action)
	return node

func primary(value: String, action: Callable, min_width: float = 0) -> Button:
	var node = button(value, action, min_width)
	node.add_theme_stylebox_override("normal", style(Color("7f683c"), EMBER, 8))
	node.add_theme_color_override("font_color", Color("fff2d4"))
	return node

func panel(parent: Node, expand: bool = false) -> VBoxContainer:
	var shell = PanelContainer.new()
	if expand:
		shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(shell)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	shell.add_child(box)
	return box

func scroll(parent: Node) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	sc.add_child(box)
	return box

func portrait(actor: Dictionary, pixels: float = 72) -> Control:
	var art = Portrait.new()
	art.form = actor.get("form", "goblin")
	art.custom_minimum_size = Vector2(pixels, pixels)
	art.tooltip_text = actor.get("name", "")
	return art

func health(actor: Dictionary, parent: Node) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	row.add_child(label("HP " + str(actor.get("hp", 0)) + " / " + str(actor.get("max_hp", 20)), 14, MOSS))
	if actor.get("block", 0) > 0:
		row.add_child(label("  " + str(actor["block"]) + " block", 14, EMBER))
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.max_value = max(1, actor.get("max_hp", 20))
	bar.value = actor.get("hp", 0)
	bar.show_percentage = false
	parent.add_child(bar)

func ability_name(id: String) -> String:
	return Data.ABILITIES.get(id, {}).get("name", id.capitalize())

func form_name(id: String) -> String:
	return Data.FORMS.get(id, {}).get("name", id.replace("_", " ").capitalize())

func act(action: Callable, message: String = "") -> void:
	var previous_hp: Dictionary = {}
	for monster in state.run.get("monsters", []): previous_hp[monster["id"]] = monster["hp"]
	if state.battle != null:
		for enemy in state.battle.enemies: previous_hp[enemy["id"]] = enemy["hp"]
	action.call()
	card_index = -1
	refresh()
	for actor_id in actor_nodes:
		var actor = state.battle.get_actor(actor_id) if state.battle != null else state.get_monster(actor_id)
		if actor.is_empty() or not previous_hp.has(actor_id): continue
		var difference = int(actor["hp"]) - int(previous_hp[actor_id])
		if difference == 0: continue
		var actor_node = actor_nodes[actor_id]
		actor_node.modulate = Color("d1f2b5") if difference > 0 else Color("ee9b86")
		var flash = actor_node.create_tween()
		flash.tween_property(actor_node, "modulate", Color.WHITE, 0.5)
	if message != "":
		toast.text = message
		toast.add_theme_color_override("font_color", EMBER)
		var tween = toast.create_tween()
		toast.modulate.a = 0.3
		tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	if not state.last_evolution.is_empty():
		var info = state.last_evolution.duplicate(true)
		state.last_evolution = {}
		rewards_screen.reveal(info)

func open_grimoire() -> void:
	grimoire_return = menu
	menu = "grimoire"
	refresh()

func open_modal() -> VBoxContainer:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.025, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box = panel(center)
	box.custom_minimum_size = Vector2(570, 0)
	return box

func close_modal() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(overlay):
			close_modal()
		elif card_index >= 0:
			card_index = -1
			refresh()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if menu == "game" and state.run.get("phase", "") == "combat" and not is_instance_valid(overlay):
			act(state.end_turn, "The adventurers resolve their announced actions.")
