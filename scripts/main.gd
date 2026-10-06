extends Control

const State = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/game_data.gd")
const Screens = preload("res://scripts/ui_screens.gd")
const CombatScreen = preload("res://scripts/ui_battle.gd")
const RewardsScreen = preload("res://scripts/ui_rewards.gd")
const TraitScreen = preload("res://scripts/ui_traits.gd")
const PartyRoutes = preload("res://scripts/ui_party_routes.gd")
const Portrait = preload("res://scripts/monster_portrait.gd")
const Chamber = preload("res://scripts/ui_chamber.gd")
const TouchScroller = preload("res://scripts/touch_scroller.gd")
const TurnPresentation = preload("res://scripts/turn_presentation.gd")
const Preferences = preload("res://scripts/ui_preferences.gd")
const ReportUploader = preload("res://scripts/report_uploader.gd")
const ReportUI = preload("res://scripts/ui_run_reports.gd")

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
var grimoire_return = "title"
var screens
var combat_screen
var rewards_screen
var traits_screen
var party_routes
var actor_nodes: Dictionary = {}
var margin: MarginContainer
var _layout_size := Vector2.ZERO
var _resize_pending := false
var _screen_key := ""
var _modal_scroll: ScrollContainer
var _modal_shell: PanelContainer
var flow
var last_action := ""
var battlefield: Control
var reduced_motion := false
var report_uploader
var report_ui
var resolving_turn: bool:
	get: return flow != null and flow.active
var acting_actor_id: String:
	get: return flow.actor_id if flow != null else ""
var acting_target_ids: Array:
	get: return flow.target_ids if flow != null else []
var acted_actor_ids: Array:
	get: return flow.acted_ids if flow != null else []
var turn_stage: String:
	get: return flow.stage if flow != null else "player"
var turn_kind: String:
	get: return flow.kind if flow != null else ""
var turn_message: String:
	get: return flow.message if flow != null else ""
var turn_detail: String:
	get: return flow.detail if flow != null else ""

func _ready() -> void:
	_update_density()
	if state == null: state = State.new()
	report_uploader = ReportUploader.new()
	report_uploader.setup(state)
	add_child(report_uploader)
	report_ui = ReportUI.new(self)
	reduced_motion = Preferences.read_motion(state._prefix)
	flow = TurnPresentation.new(self)
	screens = Screens.new(self)
	combat_screen = CombatScreen.new(self)
	rewards_screen = RewardsScreen.new(self)
	traits_screen = TraitScreen.new(self)
	party_routes = PartyRoutes.new(self)
	_apply_theme()
	add_child(TouchScroller.new(self))
	var room = Chamber.new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)
	_layout_size = get_viewport_rect().size
	get_viewport().size_changed.connect(_viewport_changed)
	refresh()

func is_compact() -> bool:
	var viewport_size = get_viewport_rect().size
	return viewport_size.x < 1050 or viewport_size.y < 680

func is_portrait() -> bool:
	var viewport_size = get_viewport_rect().size
	return viewport_size.x < viewport_size.y

func content_width() -> float:
	return maxf(1.0, minf(1600, get_viewport_rect().size.x - (24 if is_compact() else 48)))

func animations_enabled() -> bool:
	return not reduced_motion

func set_reduced_motion(value: bool, persist: bool = false) -> void:
	reduced_motion = value
	if persist: Preferences.save_motion(state._prefix, value)
	refresh()

func _update_density() -> void:
	# Web canvases contain device pixels; controls retain CSS-sized touch targets.
	if OS.has_feature("web"):
		get_tree().root.content_scale_factor = maxf(1.0, DisplayServer.screen_get_scale())

func _viewport_changed() -> void:
	if _resize_pending or not is_instance_valid(root_box): return
	_resize_pending = true
	call_deferred("_reflow")

func _reflow() -> void:
	_resize_pending = false
	_update_density()
	var viewport_size = get_viewport_rect().size
	if viewport_size == _layout_size: return
	_layout_size = viewport_size
	refresh()
	_size_modal()

func _scroll_nodes(node: Node) -> Array:
	var result: Array = []
	if node is ScrollContainer: result.append(node)
	for child in node.get_children(): result.append_array(_scroll_nodes(child))
	return result

func _restore_scroll(offsets: Array) -> void:
	if not is_instance_valid(content): return
	var nodes = _scroll_nodes(content)
	for index in range(mini(offsets.size(), nodes.size())):
		nodes[index].scroll_horizontal = offsets[index].x
		nodes[index].scroll_vertical = offsets[index].y

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
	flow.clear_feedback()
	battlefield = null
	var phase = "combat" if resolving_turn else str(state.run.get("phase", "prep"))
	if phase != "combat": last_action = ""
	var next_key = menu + ":" + phase
	var offsets: Array = []
	if _screen_key == next_key and is_instance_valid(content):
		for sc in _scroll_nodes(content): offsets.append(Vector2i(sc.scroll_horizontal, sc.scroll_vertical))
	_screen_key = next_key
	var side_margin: int = 12 if is_compact() else maxi(24, int((get_viewport_rect().size.x - 1600) / 2))
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, side_margin if edge in ["left", "right"] else (10 if is_compact() else 18))
	root_box.add_theme_constant_override("separation", 5 if is_compact() else 14)
	actor_nodes.clear()
	for child in root_box.get_children():
		root_box.remove_child(child)
		child.queue_free()
	_header()
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8 if is_compact() else 12)
	root_box.add_child(content)
	if menu == "title":
		screens.title_screen()
	elif menu == "grimoire":
		screens.grimoire()
	else:
		match phase:
			"prep": screens.preparation()
			"combat": combat_screen.render()
			"feeding": rewards_screen.render()
			"trait": traits_screen.render()
			"result", "victory", "defeat": screens.results()
	toast = label("A dungeon lives through the choices of its keeper.", 12 if is_compact() else 13, MUTED, true)
	root_box.add_child(toast)
	toast.visible = not (is_compact() and menu == "game" and phase == "combat")
	if not offsets.is_empty(): call_deferred("_restore_scroll", offsets)

func _header() -> void:
	if is_compact():
		_compact_header()
		return
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
		var book = button("Grimoire", open_grimoire)
		book.disabled = resolving_turn
		bar.add_child(book)
	if menu == "game":
		var home = button("Save & title", func():
			if resolving_turn: return
			state.save_game()
			menu = "title"
			refresh())
		home.disabled = resolving_turn
		bar.add_child(home)
	var line = HSeparator.new()
	line.modulate = Color("596148")
	root_box.add_child(line)

func _compact_header() -> void:
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root_box.add_child(bar)
	bar.add_child(label("GOBLIN GRIMOIRE", 16, PARCHMENT))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var in_game = menu == "game" and not state.run.is_empty()
	var stats = bar
	if in_game and is_portrait():
		stats = HBoxContainer.new()
		stats.add_theme_constant_override("separation", 8)
		root_box.add_child(stats)
	if in_game:
		stats.add_child(label("RANK " + state.rank_name() + " · RAID " + str(mini(int(state.run["raid"]) + 1, int(Data.BALANCE["raids"]))) + "/" + str(Data.BALANCE["raids"]), 12, MOSS))
		stats.add_child(label("CORE " + str(state.run["core"]) + "/" + str(Data.BALANCE["core"]), 13, EMBER))
	if menu != "grimoire":
		var book = button("Grimoire", open_grimoire)
		book.disabled = resolving_turn
		book.add_theme_font_size_override("font_size", 13)
		bar.add_child(book)
	if in_game:
		if is_portrait():
			var space = Control.new()
			space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats.add_child(space)
		var home = button("Save & title", func():
			if resolving_turn: return
			state.save_game()
			menu = "title"
			refresh())
		home.add_theme_font_size_override("font_size", 13)
		home.disabled = resolving_turn
		stats.add_child(home)

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
	node.custom_minimum_size = Vector2(min_width, 44)
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
	if resolving_turn: return
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
	if resolving_turn: return
	grimoire_return = menu
	menu = "grimoire"
	refresh()

func open_modal() -> VBoxContainer:
	flow.clear_feedback()
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
	_modal_shell = PanelContainer.new()
	center.add_child(_modal_shell)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_shell.add_child(_modal_scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	_modal_scroll.add_child(box)
	_size_modal()
	return box

func _size_modal() -> void:
	if not is_instance_valid(_modal_scroll) or not is_instance_valid(overlay): return
	var viewport_size = get_viewport_rect().size
	_modal_shell.custom_minimum_size = Vector2(minf(598, viewport_size.x - 24), 0)
	_modal_scroll.custom_minimum_size = Vector2(0, minf(600, viewport_size.y - 56))

func close_modal() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if resolving_turn: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(overlay):
			close_modal()
		elif card_index >= 0:
			card_index = -1
			refresh()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if menu == "game" and state.run.get("phase", "") == "combat" and not is_instance_valid(overlay):
			end_player_turn()

func combat_battle():
	return flow.view if resolving_turn and flow.view != null else state.battle

func end_player_turn() -> void:
	flow.end_turn()

func skip_turn_animation() -> void:
	flow.skip()

func play_selected_card(target_id: String) -> void:
	flow.play(target_id)
