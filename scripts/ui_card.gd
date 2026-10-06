extends Button

# A presentation-only face. The parent owns selection and all card mechanics.
const Copy = preload("res://scripts/combat_copy.gd")
const Data = preload("res://scripts/game_data.gd")
const ART_PATHS = {
	"attack": "res://assets/cards/attack-v1.png",
	"guard": "res://assets/cards/guard-v1.png",
	"vitality": "res://assets/cards/vitality-v1.png"
}
static var _textures: Dictionary = {}
var _ui
var _face: MarginContainer
var _frame: StyleBoxFlat
var _selected: bool = false
var _hover_tween: Tween

func configure(ui, battle, card: Dictionary, compact: bool, portrait: bool, selected: bool, reason: String) -> void:
	_ui = ui
	_selected = selected
	var ability: Dictionary = Data.ABILITIES[card["ability"]]
	var effect: String = Copy.card_effect(battle, card)
	var owner_text: String = "Dungeon shared" if card["owner"] == "" else Copy.owner_name(battle, card)
	text = "%s · %s · %d energy · %s%s" % [owner_text, ability["name"], ability["cost"], effect, " · " + reason if reason != "" else ""]
	tooltip_text = "%s · %d energy\n%s\n%s%s" % [owner_text, ability["cost"], ability["description"], Copy.target_prompt(ability["target"]), "\n" + reason if reason != "" else ""]
	custom_minimum_size = Vector2(154, 146 if portrait else 100) if compact else Vector2(184, 200)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_text = true
	disabled = reason != ""
	add_theme_font_size_override("font_size", 11)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	var fill: Color = Color("493e29") if selected else Color("293329")
	_frame = ui.style(fill, ui.EMBER if selected else Color("738463"), 9)
	_frame.set_border_width_all(2 if selected else 1)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, _frame)
	_face = MarginContainer.new()
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		_face.add_theme_constant_override("margin_" + edge, 8)
	add_child(_face)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_face.add_child(box)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	box.add_child(header)
	var owner = _label(owner_text, "CardOwner", 11, ui.MUTED)
	owner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(owner)
	var cost = _label("%d energy" % ability["cost"], "CardCost", 11, ui.EMBER)
	cost.custom_minimum_size.x = 47
	header.add_child(cost)
	var art = ArtPane.new()
	art.name = "CardArt"
	art.family = _art_family(ability)
	art.accent = _affinity_color(ability.get("affinity", "Neutral"), art.family)
	art.texture = _texture(art.family)
	art.custom_minimum_size.y = (42 if portrait else 18) if compact else 74
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.clip_contents = true
	art.dimmed = disabled
	box.add_child(art)
	if reason != "" or selected:
		var badge = _label(reason if disabled else "SELECTED · tap for details", "CardReason" if disabled else "CardSelected", 10, ui.RED if disabled else ui.EMBER)
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		badge.offset_top = -16
		badge.offset_left = 4
		badge.offset_right = -4
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		art.badged = true
		art.add_child(badge)
	box.add_child(_label(ability["name"], "CardTitle", (14 if portrait else 13) if compact else 16, ui.MUTED if disabled else ui.PARCHMENT))
	var effect_label = _label(effect, "CardEffect", 11 if compact else 13, ui.MUTED if disabled else ui.MOSS)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var needs_two_lines: bool = false
	for item in ability["effects"]:
		if item["kind"] in ["cleanse", "break_block"] or item.get("to", "target") == "self": needs_two_lines = true
	effect_label.max_lines_visible = 2 if portrait or not compact or needs_two_lines else 1
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(effect_label)
	_ignore_mouse(_face)
	mouse_entered.connect(func(): _hover(true))
	mouse_exited.connect(func(): _hover(false))
	if _animations_enabled():
		_face.modulate.a = 0.65
		var entrance = create_tween()
		entrance.tween_property(_face, "modulate:a", 1.0, 0.13 if selected else 0.18)

func _label(value: String, node_name: String, pixels: int, color: Color) -> Label:
	var node: Label = _ui.label(value, pixels, color)
	node.name = node_name
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return node

func _animations_enabled() -> bool:
	return bool(_ui.animations_enabled()) if _ui.has_method("animations_enabled") else true

func _hover(entered: bool) -> void:
	if disabled: return
	if is_instance_valid(_hover_tween): _hover_tween.kill()
	var fill: Color = (Color("594c32") if entered else Color("493e29")) if _selected else (Color("354332") if entered else Color("293329"))
	var border: Color = _ui.EMBER if _selected else (_ui.MOSS if entered else Color("738463"))
	if not _animations_enabled():
		_frame.bg_color = fill
		_frame.border_color = border
		return
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(_frame, "bg_color", fill, 0.12)
	_hover_tween.tween_property(_frame, "border_color", border, 0.12)

static func _art_family(ability: Dictionary) -> String:
	for effect in ability["effects"]:
		if effect["kind"] == "heal" or effect.get("status", "") == "regen": return "vitality"
	for effect in ability["effects"]:
		if effect["kind"] == "damage": return "attack"
	return "guard"

static func _texture(family: String) -> Texture2D:
	if _textures.has(family): return _textures[family]
	var path: String = ART_PATHS[family]
	if not ResourceLoader.exists(path): return null
	var asset: Texture2D = load(path)
	if asset != null: _textures[family] = asset
	return asset

static func texture_for(ability_id: String) -> Texture2D:
	if not Data.ABILITIES.has(ability_id): return null
	return _texture(_art_family(Data.ABILITIES[ability_id]))

static func _affinity_color(affinity: String, family: String) -> Color:
	var colors: Dictionary = {"Might": Color("edb568"), "Guard": Color("91bdc2"), "Flame": Color("f49b59"), "Venom": Color("aecb6b"), "Control": Color("a5bdda"), "Trickery": Color("c7a8db"), "Mystic": Color("bdb0e9"), "Vitality": Color("9bd3a7")}
	return colors.get(affinity, {"attack": Color("edb568"), "guard": Color("91bdc2"), "vitality": Color("9bd3a7")}[family])

static func _ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)

class ArtPane extends Control:
	var texture: Texture2D
	var family: String = "attack"
	var accent: Color = Color("edb568")
	var dimmed: bool = false
	var badged: bool = false

	func _draw() -> void:
		if size.x <= 0 or size.y <= 0: return
		var area = Rect2(Vector2.ZERO, size)
		draw_rect(area, Color("17221d"))
		if texture != null:
			var tex_size: Vector2 = texture.get_size()
			var ratio: float = size.x / maxf(1, size.y)
			var source = Rect2(Vector2.ZERO, tex_size)
			if tex_size.x / tex_size.y > ratio:
				source.size.x = tex_size.y * ratio
				source.position.x = (tex_size.x - source.size.x) / 2
			else:
				source.size.y = tex_size.x / ratio
				source.position.y = (tex_size.y - source.size.y) * 0.45
			draw_texture_rect_region(texture, area, source, Color(0.75, 0.75, 0.75, 0.65) if dimmed else Color.WHITE)
		else:
			_fallback()
		if badged: draw_rect(Rect2(0, maxf(0, size.y - 16), size.x, 16), Color(0.06, 0.08, 0.06, 0.88))
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), accent, 2)
		draw_line(Vector2.ZERO, Vector2(12, 0), accent, 2)

	func _fallback() -> void:
		var center: Vector2 = size / 2
		var radius: float = minf(size.y * 0.35, 25)
		draw_circle(center, radius * 1.2, Color(accent, 0.08))
		for i in range(4):
			var x: float = size.x * (i + 0.5) / 4
			draw_line(Vector2(x - 12, size.y), Vector2(x + 12, 0), Color(accent, 0.08), 1)
		match family:
			"guard":
				var shield = PackedVector2Array([center + Vector2(-radius, -radius), center + Vector2(radius, -radius), center + Vector2(radius * 0.8, radius * 0.3), center + Vector2(0, radius), center + Vector2(-radius * 0.8, radius * 0.3)])
				draw_colored_polygon(shield, Color(accent, 0.24))
				shield.append(shield[0])
				draw_polyline(shield, accent, 2, true)
				draw_line(center + Vector2(0, -radius * 0.7), center + Vector2(0, radius * 0.6), accent, 2, true)
			"vitality":
				draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), accent, maxf(2, radius * 0.3), true)
				draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), accent, maxf(2, radius * 0.3), true)
				for i in range(3): draw_circle(center + Vector2(radius * 1.4, (i - 1) * radius), 1.5, accent)
			_:
				draw_line(center + Vector2(-radius * 0.7, radius * 0.7), center + Vector2(radius, -radius), accent, maxf(3, radius * 0.25), true)
				draw_line(center + Vector2(-radius, 0), center + Vector2(0, radius), accent, 2, true)
				draw_line(center + Vector2(-radius, radius), center + Vector2(-radius * 0.65, radius * 0.65), accent, 3, true)
