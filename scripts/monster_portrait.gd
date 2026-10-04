class_name MonsterPortrait
extends Control

var form = "goblin":
	set(value):
		form = value
		queue_redraw()

const DARK = Color("142019")
const GOLD = Color("ecc17d")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func line(points: Array, color: Color, width: float = 2.0) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)

func _draw() -> void:
	var scale_value = min(size.x, size.y) / 112.0
	draw_set_transform(size / 2.0, 0, Vector2(scale_value, scale_value))
	draw_circle(Vector2.ZERO, 52, Color("17231e"))
	draw_arc(Vector2.ZERO, 51, 0, TAU, 60, Color("667250"), 1.0, true)
	for i in range(8):
		var angle = TAU * i / 8.0
		var point = Vector2(cos(angle), sin(angle)) * 47
		draw_line(point * 0.93, point, Color("ac9b64"), 1, true)
	match form:
		"goblin": _goblin()
		"green_ogre": _ogre(Color("7ba34b"), false)
		"red_ogre": _ogre(Color("b85538"), true)
		"oni": _oni()
		"basilisk": _serpent(false)
		"ember_basilisk": _serpent(true)
		"shadow_stalker": _stalker()
		_: _adventurer()

func _goblin() -> void:
	poly([Vector2(-29, 47), Vector2(-20, 12), Vector2(0, 6), Vector2(23, 14), Vector2(34, 47)], Color("6d5840"))
	poly([Vector2(-29, -10), Vector2(-49, -25), Vector2(-38, 5), Vector2(-21, 10)], Color("83a857"))
	poly([Vector2(29, -10), Vector2(49, -25), Vector2(38, 5), Vector2(21, 10)], Color("83a857"))
	poly([Vector2(-35, -13), Vector2(-43, -18), Vector2(-36, -1)], Color("c28b69"))
	poly([Vector2(35, -13), Vector2(43, -18), Vector2(36, -1)], Color("c28b69"))
	poly([Vector2(-26, -30), Vector2(18, -33), Vector2(29, -10), Vector2(24, 20), Vector2(1, 29), Vector2(-22, 15), Vector2(-29, -8)], Color("92b966"))
	poly([Vector2(15, -29), Vector2(29, -10), Vector2(24, 20), Vector2(1, 29), Vector2(12, 4)], Color("6c934b"))
	poly([Vector2(-24, -24), Vector2(-15, -43), Vector2(-11, -31), Vector2(3, -46), Vector2(12, -31), Vector2(23, -29)], Color("333e2c"))
	draw_circle(Vector2(-12, -7), 7, GOLD)
	draw_circle(Vector2(13, -7), 7, GOLD)
	draw_circle(Vector2(-10, -6), 3, DARK)
	draw_circle(Vector2(11, -6), 3, DARK)
	line([Vector2(-22, -16), Vector2(-8, -12)], DARK, 4)
	line([Vector2(8, -12), Vector2(23, -16)], DARK, 4)
	poly([Vector2(-4, -3), Vector2(2, 5), Vector2(-7, 5)], Color("c0ce87"))
	line([Vector2(-12, 15), Vector2(1, 18), Vector2(15, 12)], DARK, 2)
	poly([Vector2(-11, 13), Vector2(-7, 13), Vector2(-8, 20)], Color("ede4be"))
	poly([Vector2(10, 13), Vector2(14, 12), Vector2(12, 19)], Color("ede4be"))
	line([Vector2(-14, 30), Vector2(17, 46)], Color("aa8359"), 6)
	draw_circle(Vector2(2, 36), 4, Color("d0b06d"))

func _ogre(skin: Color, flame: bool) -> void:
	poly([Vector2(-45, 47), Vector2(-40, 17), Vector2(-22, 8), Vector2(23, 8), Vector2(43, 22), Vector2(48, 47)], skin.darkened(0.17))
	poly([Vector2(-30, -33), Vector2(27, -33), Vector2(35, -10), Vector2(28, 24), Vector2(0, 33), Vector2(-29, 22), Vector2(-35, -5)], skin)
	poly([Vector2(-27, -33), Vector2(-31, -47), Vector2(-14, -34)], GOLD)
	poly([Vector2(14, -34), Vector2(33, -47), Vector2(27, -31)], GOLD)
	line([Vector2(-24, -16), Vector2(-7, -12)], DARK, 6)
	line([Vector2(7, -12), Vector2(24, -16)], DARK, 6)
	draw_circle(Vector2(-15, -6), 4, Color("f3d67c"))
	draw_circle(Vector2(16, -6), 4, Color("f3d67c"))
	poly([Vector2(-10, 14), Vector2(-5, 27), Vector2(-2, 14)], Color("e6dcc1"))
	poly([Vector2(10, 14), Vector2(5, 27), Vector2(2, 14)], Color("e6dcc1"))
	line([Vector2(-17, 16), Vector2(0, 19), Vector2(18, 16)], DARK, 3)
	poly([Vector2(-43, 26), Vector2(-19, 23), Vector2(-15, 47), Vector2(-44, 47)], Color("575b46"))
	for x in [-34, -23]: draw_circle(Vector2(x, 33), 2, GOLD)
	if flame:
		poly([Vector2(22, 46), Vector2(16, 26), Vector2(26, 31), Vector2(30, 13), Vector2(41, 35), Vector2(35, 48)], Color("eb9854"))

func _oni() -> void:
	_ogre(Color("a36162"), false)
	poly([Vector2(-21, -27), Vector2(-29, -50), Vector2(-10, -32)], Color("eadbb7"))
	poly([Vector2(21, -27), Vector2(29, -50), Vector2(10, -32)], Color("eadbb7"))
	draw_circle(Vector2(0, -21), 5, Color("afaddd"))
	poly([Vector2(-25, 26), Vector2(-34, 47), Vector2(31, 47), Vector2(24, 26), Vector2(0, 36)], Color("393c60"))
	line([Vector2(-21, 33), Vector2(0, 44), Vector2(21, 33)], GOLD, 2)

func _serpent(ember: bool) -> void:
	var skin = Color("bd7850") if ember else Color("6eaa8f")
	draw_arc(Vector2(0, 22), 22, -0.2, PI * 1.7, 40, skin.darkened(0.2), 17, true)
	line([Vector2(-20, 33), Vector2(-35, 43), Vector2(-20, 44)], skin, 8)
	poly([Vector2(-11, 20), Vector2(-20, -8), Vector2(-28, -22), Vector2(-19, -37), Vector2(19, -37), Vector2(30, -21), Vector2(18, 1), Vector2(8, 20)], skin)
	poly([Vector2(-28, -22), Vector2(-39, -34), Vector2(-25, -30), Vector2(-29, -47), Vector2(-13, -34)], skin.lightened(0.15))
	poly([Vector2(28, -22), Vector2(39, -34), Vector2(25, -30), Vector2(29, -47), Vector2(13, -34)], skin.lightened(0.15))
	poly([Vector2(-19, -19), Vector2(-5, -15), Vector2(-16, -8)], GOLD)
	poly([Vector2(19, -19), Vector2(5, -15), Vector2(16, -8)], GOLD)
	line([Vector2(-12, -16), Vector2(-12, -10)], DARK, 2)
	line([Vector2(12, -16), Vector2(12, -10)], DARK, 2)
	line([Vector2(-13, 0), Vector2(0, 6), Vector2(14, 0)], DARK, 2)
	line([Vector2(0, 7), Vector2(0, 18), Vector2(-5, 22)], Color("c48379"), 2)
	line([Vector2(0, 18), Vector2(5, 22)], Color("c48379"), 2)
	for y in [8, 16, 24, 32]:
		line([Vector2(-5, y), Vector2(6, y)], skin.lightened(0.3), 2)
	if ember:
		draw_circle(Vector2(-35, 10), 5, Color("f4b765"))
		draw_circle(Vector2(35, 13), 3, Color("eb9854"))

func _stalker() -> void:
	poly([Vector2(-38, 47), Vector2(-31, -18), Vector2(0, -45), Vector2(31, -18), Vector2(39, 47)], Color("55516e"))
	poly([Vector2(-21, -20), Vector2(0, -32), Vector2(24, -17), Vector2(15, 17), Vector2(-14, 17)], Color("1c2527"))
	line([Vector2(-16, -7), Vector2(-5, -4)], Color("bbc781"), 3)
	line([Vector2(6, -4), Vector2(17, -7)], Color("bbc781"), 3)
	poly([Vector2(-29, 17), Vector2(0, 30), Vector2(29, 17), Vector2(14, 47), Vector2(-15, 47)], Color("343b42"))
	line([Vector2(-27, 28), Vector2(29, 44)], Color("988075"), 4)
	poly([Vector2(28, 26), Vector2(43, 4), Vector2(37, 33)], Color("dddabf"))

func _adventurer() -> void:
	var shade = Color("6e7d86")
	if form in ["mage", "controller"]: shade = Color("737496")
	if form == "priest": shade = Color("ac9c69")
	if form == "rogue": shade = Color("777964")
	poly([Vector2(-34, 47), Vector2(-29, 14), Vector2(0, 6), Vector2(28, 14), Vector2(35, 47)], shade)
	draw_circle(Vector2(0, -8), 24, Color("c49b79"))
	poly([Vector2(-23, -7), Vector2(-24, -23), Vector2(-12, -33), Vector2(18, -28), Vector2(25, -10), Vector2(9, -18)], Color("544b3e"))
	draw_circle(Vector2(-9, -7), 2.5, DARK)
	draw_circle(Vector2(10, -7), 2.5, DARK)
	line([Vector2(-7, 9), Vector2(7, 9)], Color("765747"), 2)
	if form == "mage":
		poly([Vector2(-29, -24), Vector2(-5, -51), Vector2(23, -23)], shade)
		line([Vector2(-35, -24), Vector2(32, -24)], GOLD, 3)
	elif form in ["controller", "rogue"]:
		poly([Vector2(-25, -17), Vector2(0, -40), Vector2(28, -17), Vector2(19, -10), Vector2(0, -26), Vector2(-18, -9)], shade.darkened(0.25))
		poly([Vector2(-22, 0), Vector2(23, 0), Vector2(15, 18), Vector2(-13, 18)], shade.darkened(0.25))
	elif form in ["warrior", "defender"]:
		poly([Vector2(-26, -13), Vector2(-22, -31), Vector2(20, -31), Vector2(27, -13)], shade.lightened(0.25))
		line([Vector2(-24, -16), Vector2(25, -16)], DARK, 3)
		line([Vector2(0, -30), Vector2(0, -13)], GOLD, 3)
	elif form == "priest":
		draw_arc(Vector2(0, -30), 23, PI, TAU, 30, GOLD, 3, true)
		line([Vector2(0, 28), Vector2(0, 43)], GOLD, 4)
		line([Vector2(-6, 33), Vector2(6, 33)], GOLD, 3)
	if form == "defender":
		poly([Vector2(13, 15), Vector2(43, 16), Vector2(41, 39), Vector2(28, 50), Vector2(15, 39)], Color("a99d79"))
		line([Vector2(28, 19), Vector2(28, 43)], Color("667782"), 4)
