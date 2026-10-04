extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("141b17"))
	var center = Vector2(size.x * 0.65, size.y * 0.5)
	for i in range(12, 0, -1):
		draw_circle(center, float(i) * 40, Color(0.22, 0.29, 0.2, 0.025))
	for y in range(0, int(size.y), 72):
		var offset = 58 if (y / 72) % 2 == 0 else 0
		for x in range(-offset, int(size.x), 116):
			draw_rect(Rect2(x + 2, y + 2, 111, 66), Color(0.2, 0.26, 0.2, 0.13), false, 1)
	draw_arc(center, 230, 0, TAU, 100, Color(0.55, 0.58, 0.35, 0.06), 2, true)
	draw_arc(center, 245, 0, TAU, 100, Color(0.55, 0.58, 0.35, 0.035), 1, true)
	for side in [0.0, size.x]:
		for j in range(7):
			var p = Vector2(side, j * 120 + 22)
			draw_line(p, p + Vector2(24 if side == 0 else -24, 55), Color(0.27, 0.37, 0.23, 0.25), 3, true)
			var dir = 1 if side == 0 else -1
			draw_colored_polygon(PackedVector2Array([p + Vector2(7 * dir, 20), p + Vector2(36 * dir, 17), p + Vector2(18 * dir, 35)]), Color(0.28, 0.4, 0.22, 0.25))
