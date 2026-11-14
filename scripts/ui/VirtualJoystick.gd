class_name VirtualJoystick
extends Control

## VirtualJoystick: Precision Touch & Mouse analog stick with spring self-centering.
## Features global drag tracking so thumbs never drop input outside the bounding box.

signal stick_moved(value: Vector2)
signal stick_released

@export var max_radius: float = 95.0
@export var deadzone: float = 0.06

var stick_vector: Vector2 = Vector2.ZERO # x in [-1,1], y in [-1,1] (up is +1)
var is_dragging: bool = false
var touch_pointer_id: int = -1

var base_center: Vector2 = Vector2.ZERO
var knob_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(max_radius * 2.5, max_radius * 2.5)
	base_center = size / 2.0
	knob_pos = base_center
	resized.connect(_on_resized)

func _on_resized() -> void:
	base_center = size / 2.0
	if not is_dragging:
		knob_pos = base_center
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not is_dragging:
			is_dragging = true
			touch_pointer_id = event.index
			_update_stick(event.position)
			accept_event()
		elif not event.pressed and event.index == touch_pointer_id:
			_release_stick()
			accept_event()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not is_dragging:
				is_dragging = true
				touch_pointer_id = 0
				_update_stick(event.position)
				accept_event()
			elif not event.pressed and is_dragging:
				_release_stick()
				accept_event()

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventScreenDrag:
		if event.index == touch_pointer_id:
			var local_pos = get_global_transform().affine_inverse() * event.position
			_update_stick(local_pos)

	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == touch_pointer_id:
			_release_stick()

	elif event is InputEventMouseMotion:
		if touch_pointer_id == 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var local_pos = get_global_transform().affine_inverse() * event.position
			_update_stick(local_pos)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release_stick()

func _update_stick(pos: Vector2) -> void:
	var delta_vec = pos - base_center
	var dist = delta_vec.length()
	if dist > max_radius:
		delta_vec = delta_vec.normalized() * max_radius

	knob_pos = base_center + delta_vec

	# Normalized: X is right (+1) / left (-1), Y is up (+1) / down (-1)
	var norm_x = delta_vec.x / max_radius
	var norm_y = -delta_vec.y / max_radius # Invert screen Y so up is +1

	if abs(norm_x) < deadzone:
		norm_x = 0.0
	if abs(norm_y) < deadzone:
		norm_y = 0.0

	stick_vector = Vector2(norm_x, norm_y)
	stick_moved.emit(stick_vector)
	queue_redraw()

func _release_stick() -> void:
	is_dragging = false
	touch_pointer_id = -1
	knob_pos = base_center
	stick_vector = Vector2.ZERO
	stick_moved.emit(stick_vector)
	stick_released.emit()
	queue_redraw()

func _draw() -> void:
	# Outer Ring Base with high-contrast glowing neon aesthetic
	var base_bg_color = Color(0.04, 0.08, 0.12, 0.65)
	var ring_border_color = Color(0.15, 0.85, 1.0, 0.85) if is_dragging else Color(0.2, 0.65, 0.85, 0.5)
	draw_circle(base_center, max_radius, base_bg_color)
	draw_arc(base_center, max_radius, 0.0, TAU, 48, ring_border_color, 3.5, true)
	draw_arc(base_center, max_radius * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.2), 1.5, true)

	# Crosshair markings
	var cross_color = Color(0.2, 0.8, 1.0, 0.4)
	draw_line(base_center - Vector2(max_radius * 0.85, 0), base_center + Vector2(max_radius * 0.85, 0), cross_color, 1.5)
	draw_line(base_center - Vector2(0, max_radius * 0.85), base_center + Vector2(0, max_radius * 0.85), cross_color, 1.5)

	# Drag displacement line
	if is_dragging and knob_pos != base_center:
		draw_line(base_center, knob_pos, Color(0.1, 0.95, 0.8, 0.6), 2.5)

	# Inner Thumb Knob
	var knob_radius = max_radius * 0.38
	var knob_color = Color(0.1, 0.9, 1.0, 0.9) if is_dragging else Color(0.7, 0.85, 0.95, 0.75)
	draw_circle(knob_pos, knob_radius, knob_color)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 2.5, true)
	# Center dot
	draw_circle(knob_pos, 4.0, Color(1, 1, 1, 0.9))
