extends Node

# Route real finger gestures before child buttons consume GUI input.
# Mouse input keeps Godot's normal scrollbars, wheel and button behavior.
var ui: Control
var finger := -1
var origin := Vector2.ZERO
var candidates: Array = []
var active: ScrollContainer
var offset := Vector2i.ZERO
var dragging := false
var suppress_release := false

func _init(owner: Control) -> void:
	ui = owner

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if dragging or suppress_release: get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger < 0:
			finger = event.index
			origin = event.position
			candidates.clear()
			active = null
			dragging = false
			suppress_release = false
			var surface: Node = ui.overlay if is_instance_valid(ui.overlay) else ui
			_collect(surface, origin)
		elif not event.pressed and event.index == finger:
			if dragging:
				get_viewport().set_input_as_handled()
				suppress_release = true
				if is_instance_valid(active):
					active.propagate_notification(Control.NOTIFICATION_SCROLL_END)
					active.scroll_ended.emit()
				call_deferred("_release")
			finger = -1
			dragging = false
		return
	if not (event is InputEventScreenDrag) or event.index != finger: return
	var distance: Vector2 = event.position - origin
	if not dragging:
		if distance.length() < 10: return
		var horizontal: bool = absf(distance.x) > absf(distance.y)
		for index in range(candidates.size() - 1, -1, -1):
			var scroll = candidates[index]
			if not is_instance_valid(scroll): continue
			var bar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
			var mode = scroll.horizontal_scroll_mode if horizontal else scroll.vertical_scroll_mode
			if mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value > bar.page + 1:
				active = scroll
				break
		if not is_instance_valid(active): return
		dragging = true
		offset = Vector2i(active.scroll_horizontal, active.scroll_vertical)
		active.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		active.scroll_started.emit()
	if not is_instance_valid(active): return
	if active.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		active.scroll_horizontal = offset.x - roundi(distance.x)
	if active.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		active.scroll_vertical = offset.y - roundi(distance.y)
	get_viewport().set_input_as_handled()

func _collect(node: Node, point: Vector2) -> void:
	if node is Control:
		if not node.is_visible_in_tree(): return
		if node.clip_contents and not node.get_global_rect().has_point(point): return
		if node is ScrollContainer and node.get_global_rect().has_point(point):
			candidates.append(node)
	for child in node.get_children(): _collect(child, point)

func _release() -> void:
	suppress_release = false
	active = null
	candidates.clear()
