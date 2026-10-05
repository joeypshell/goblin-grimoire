extends "res://scripts/monster_portrait.gd"

# The original portrait faces are reused, with complete bodies beneath them.
var ui
var actor_id: String = ""
var dead: bool = false
var facing: float = 1.0
var idle_phase: float = 0.0
var _elapsed: float = 0.0
var _idle_offset: Vector2 = Vector2.ZERO
var _action_offset: Vector2 = Vector2.ZERO
var _breath: float = 1.0
var _action_tween: Tween

func _ready() -> void:
	super._ready()

func motion_offset() -> Vector2:
	return _idle_offset + _action_offset

func _animated() -> bool:
	return ui != null and is_instance_valid(ui) and ui.animations_enabled() and not dead

func _process(delta: float) -> void:
	if _animated():
		_elapsed += delta
		_idle_offset = Vector2(0, sin(_elapsed * 1.7 + idle_phase) * 1.2)
		_breath = 1.0 + sin(_elapsed * 1.7 + idle_phase) * 0.009
	else:
		_idle_offset = Vector2.ZERO
		_action_offset = Vector2.ZERO
		_breath = 1.0
	queue_redraw()

func attack(ranged: bool = false) -> void:
	if not _animated(): return
	if _action_tween != null and _action_tween.is_valid(): _action_tween.kill()
	_action_tween = create_tween()
	_action_tween.set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(self, "_action_offset", Vector2(facing * (8 if ranged else 23), -4), 0.11)
	_action_tween.tween_property(self, "_action_offset", Vector2.ZERO, 0.25)

func react(kind: String) -> void:
	if not _animated(): return
	var color: Color = {"hit": Color("f6aa91"), "heal": Color("b8e4a3"), "shield": Color("b8d7ec"), "status": Color("c5b6e8")}.get(kind, Color.WHITE)
	modulate = color
	var pulse = create_tween()
	pulse.tween_property(self, "modulate", Color.WHITE, 0.38)
	if kind == "hit":
		if _action_tween != null and _action_tween.is_valid(): _action_tween.kill()
		_action_offset = Vector2(-facing * 9, 0)
		_action_tween = create_tween()
		_action_tween.tween_property(self, "_action_offset", Vector2.ZERO, 0.28)

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	var serpent: bool = form in ["basilisk", "ember_basilisk"]
	var scale_value: float = minf(size.x / 150.0, size.y / (170.0 if serpent else 152.0))
	var feet: float = 101.0 if serpent else 83.0
	var origin: Vector2 = Vector2(size.x / 2.0, size.y - 5 - feet * scale_value) + motion_offset()
	# Feet stay grounded while the chest quietly breathes.
	draw_set_transform(Vector2(size.x / 2.0, size.y - 5), 0, Vector2(scale_value * 1.25, scale_value * 0.18))
	draw_circle(Vector2.ZERO, 33, Color(0.03, 0.06, 0.045, 0.65))
	draw_set_transform(origin, -0.18 if dead else 0.0, Vector2(scale_value * facing, scale_value * _breath))
	if serpent:
		_serpent_body(form == "ember_basilisk")
		_serpent(form == "ember_basilisk")
		return
	var skin: Color = _skin()
	if form in ["goblin", "green_ogre", "red_ogre", "oni"]:
		_humanoid_limbs(skin, form != "goblin")
	else:
		_adventurer_body()
	match form:
		"goblin": _goblin()
		"green_ogre": _ogre(skin, false)
		"red_ogre": _ogre(skin, true)
		"oni": _oni()
		"shadow_stalker": _stalker()
		_: _adventurer()
	_weapons()

func _skin() -> Color:
	return {"goblin": Color("92b966"), "green_ogre": Color("7ba34b"), "red_ogre": Color("b85538"), "oni": Color("a36162")}.get(form, Color("c49b79"))

func _humanoid_limbs(skin: Color, large: bool) -> void:
	var hip: float = 21 if large else 14
	var hand: float = 54 if large else 38
	poly([Vector2(-hip - 7, 31), Vector2(-4, 32), Vector2(-8, 62), Vector2(-18, 78), Vector2(-30, 76), Vector2(-22, 56)], Color("5c4936"))
	poly([Vector2(5, 32), Vector2(hip + 7, 31), Vector2(23, 56), Vector2(31, 76), Vector2(17, 78), Vector2(9, 62)], Color("786044"))
	poly([Vector2(-29, 72), Vector2(-17, 72), Vector2(-13, 83), Vector2(-37, 83)], Color("34372d"))
	poly([Vector2(17, 72), Vector2(29, 72), Vector2(37, 83), Vector2(13, 83)], Color("34372d"))
	poly([Vector2(-26 if not large else -38, 10), Vector2(-hand, 19), Vector2(-hand - 5, 47), Vector2(-hand + 7, 52), Vector2(-hand + 16, 26)], skin.darkened(0.1))
	poly([Vector2(26 if not large else 38, 10), Vector2(hand, 19), Vector2(hand + 5, 47), Vector2(hand - 7, 52), Vector2(hand - 16, 26)], skin)
	draw_circle(Vector2(-hand, 47), 8 if large else 6, skin)
	draw_circle(Vector2(hand, 47), 8 if large else 6, skin)
	line([Vector2(-hip, 47), Vector2(hip, 47)], Color("2e392d"), 5)
	if form == "oni":
		poly([Vector2(-27, 40), Vector2(-33, 70), Vector2(-8, 71), Vector2(0, 50), Vector2(8, 71), Vector2(33, 70), Vector2(27, 40)], Color("393c60"))
		line([Vector2(-28, 65), Vector2(29, 65)], GOLD, 2)

func _adventurer_body() -> void:
	var cloth: Color = Color("6e7d86")
	if form in ["mage", "controller"]: cloth = Color("737496")
	if form == "priest": cloth = Color("ac9c69")
	if form == "rogue": cloth = Color("777964")
	if form == "shadow_stalker": cloth = Color("55516e")
	poly([Vector2(-22, 29), Vector2(-4, 31), Vector2(-8, 73), Vector2(-20, 77), Vector2(-25, 60)], cloth.darkened(0.3))
	poly([Vector2(5, 31), Vector2(23, 29), Vector2(25, 60), Vector2(21, 77), Vector2(8, 73)], cloth.darkened(0.1))
	poly([Vector2(-21, 71), Vector2(-8, 71), Vector2(-8, 83), Vector2(-31, 83)], Color("34392f"))
	poly([Vector2(9, 71), Vector2(22, 71), Vector2(32, 83), Vector2(8, 83)], Color("34392f"))
	poly([Vector2(-25, 13), Vector2(-40, 23), Vector2(-44, 48), Vector2(-32, 51), Vector2(-26, 28)], cloth)
	poly([Vector2(26, 13), Vector2(40, 24), Vector2(44, 48), Vector2(33, 51), Vector2(27, 28)], cloth.lightened(0.05))
	draw_circle(Vector2(-38, 49), 6, Color("c49b79"))
	draw_circle(Vector2(38, 49), 6, Color("c49b79"))
	if form in ["mage", "priest", "controller", "shadow_stalker"]:
		poly([Vector2(-28, 30), Vector2(28, 30), Vector2(33, 75), Vector2(20, 81), Vector2(0, 76), Vector2(-22, 81), Vector2(-33, 75)], cloth)
		line([Vector2(0, 37), Vector2(0, 76)], cloth.lightened(0.2), 2)
	else:
		line([Vector2(-25, 42), Vector2(25, 42)], Color("695a45"), 5)
		if form in ["warrior", "defender"]:
			poly([Vector2(-22, 49), Vector2(-10, 50), Vector2(-12, 66), Vector2(-24, 66)], cloth.lightened(0.2))
			poly([Vector2(12, 50), Vector2(24, 49), Vector2(25, 66), Vector2(13, 66)], cloth.lightened(0.2))

func _serpent_body(ember: bool) -> void:
	var skin: Color = Color("bd7850") if ember else Color("6eaa8f")
	draw_arc(Vector2(0, 54), 27, -0.2, TAU - 0.3, 40, skin.darkened(0.22), 18, true)
	draw_arc(Vector2(5, 68), 25, 0.1, PI * 1.6, 35, skin, 15, true)
	line([Vector2(-20, 77), Vector2(-43, 78), Vector2(-51, 70)], skin, 7)
	for x in [-20, -10, 0, 10, 20]: draw_circle(Vector2(x, 55), 2, skin.lightened(0.35))

func _weapons() -> void:
	if form in ["goblin", "rogue", "shadow_stalker"]:
		line([Vector2(35, 43), Vector2(44, 29)], Color("5c4936"), 4)
		poly([Vector2(42, 32), Vector2(47, 7), Vector2(51, 32), Vector2(46, 37)], Color("d6d3b9"))
	elif form in ["warrior", "red_ogre"]:
		var grip: float = 53 if form == "red_ogre" else 38
		line([Vector2(grip, 49), Vector2(grip + 7, 24)], Color("6a4f34"), 5)
		poly([Vector2(grip + 3, 25), Vector2(grip + 2, -5), Vector2(grip + 15, -13), Vector2(grip + 18, 18), Vector2(grip + 9, 29)], Color("bbbca4"))
	elif form in ["defender", "green_ogre"]:
		var x: float = -52 if form == "green_ogre" else -38
		poly([Vector2(x - 17, 18), Vector2(x + 13, 18), Vector2(x + 15, 53), Vector2(x, 66), Vector2(x - 17, 53)], Color("727e68"))
		line([Vector2(x, 24), Vector2(x, 56)], GOLD, 3)
	elif form in ["mage", "controller", "priest", "oni"]:
		line([Vector2(-40, 82), Vector2(-40, -6)], Color("79684a"), 4)
		var glow: Color = Color("b2b5e6") if form in ["mage", "controller", "oni"] else GOLD
		draw_circle(Vector2(-40, -10), 8, glow.darkened(0.15))
		draw_circle(Vector2(-42, -12), 3, glow.lightened(0.2))
