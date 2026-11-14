class_name VirtualJoystick
extends Control

## VirtualJoystick: Precision Multi-Touch Analog Stick with Ownership Pointer Isolation.
## Guarantees simultaneous independent operation of left stick, right stick, and buttons
## without pointer stealing, axis swapping, or stuck inputs on release/cancel.

signal stick_moved(value: Vector2)
signal stick_released

@export var max_radius: float = 105.0
@export var deadzone: float = 0.06
@export var stick_name: String = "" # e.g. "THROTTLE / YAW" or "PITCH / ROLL"
@export var stick_type: String = "LEFT" # "LEFT" or "RIGHT"

var stick_vector: Vector2 = Vector2.ZERO # x in [-1,1], y in [-1,1] (up is +1)
var is_dragging: bool = false
var touch_pointer_id: int = -1

var base_center: Vector2 = Vector2.ZERO
var knob_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(260.0, 260.0)
	base_center = size / 2.0
	knob_pos = base_center
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

func _on_resized() -> void:
	base_center = size / 2.0
	if not is_dragging:
		knob_pos = base_center
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		if is_dragging:
			_release_stick()

func _gui_input(event: InputEvent) -> void:
	# Primary Touch Event Entrypoint
	if event is InputEventScreenTouch:
		if event.pressed and not is_dragging:
			# Claim exclusive ownership of this touch pointer ID
			is_dragging = true
			touch_pointer_id = event.index
			_update_stick(event.position)
			accept_event()
		elif not event.pressed and event.index == touch_pointer_id:
			# Released by owner pointer
			_release_stick()
			accept_event()

	# Desktop Mouse Fallback
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

	# Global drag tracking - finger can roam anywhere across the screen without losing control
	if event is InputEventScreenDrag:
		if event.index == touch_pointer_id:
			var local_pos = get_global_transform().affine_inverse() * event.position
			_update_stick(local_pos)

	# Global release tracking - ensures no stuck sticks even if finger lifts outside rect
	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == touch_pointer_id:
			_release_stick()

	# Mouse motion tracking
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

	# Normalized mapping: X is right (+1) / left (-1), Y is up (+1) / down (-1)
	var norm_x = delta_vec.x / max_radius
	var norm_y = -delta_vec.y / max_radius

	if absf(norm_x) < deadzone:
		norm_x = 0.0
	if absf(norm_y) < deadzone:
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
	# Outer Base Ring
	var base_bg_color = Color(0.04, 0.08, 0.14, 0.60)
	var ring_border_color = Color(0.15, 0.88, 1.0, 0.85) if is_dragging else Color(0.2, 0.65, 0.85, 0.5)
	draw_circle(base_center, max_radius, base_bg_color)
	draw_arc(base_center, max_radius, 0.0, TAU, 48, ring_border_color, 3.5, true)
	draw_arc(base_center, max_radius * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.18), 1.5, true)

	# 8 Directional Guidance Arrows (Matching Controller Guide)
	var arrow_color = Color(0.85, 0.92, 1.0, 0.70) if not is_dragging else Color(0.35, 0.95, 1.0, 0.90)
	for i in range(8):
		var ang = (TAU / 8.0) * i - (PI / 2.0) # Start from top (0 = UP)
		var dir = Vector2(cos(ang), sin(ang))
		var perp = Vector2(-dir.y, dir.x)
		var p_start = base_center + dir * (max_radius * 0.52)
		var p_tip = base_center + dir * (max_radius * 0.86)
		var p_base = base_center + dir * (max_radius * 0.70)
		var p_left = p_base + perp * 6.5
		var p_right = p_base - perp * 6.5
		draw_line(p_start, p_base, arrow_color, 2.5)
		draw_colored_polygon(PackedVector2Array([p_tip, p_left, p_right]), arrow_color)

	# Crosshair Markings
	var cross_color = Color(0.2, 0.8, 1.0, 0.25)
	draw_line(base_center - Vector2(max_radius * 0.88, 0), base_center + Vector2(max_radius * 0.88, 0), cross_color, 1.5)
	draw_line(base_center - Vector2(0, max_radius * 0.88), base_center + Vector2(0, max_radius * 0.88), cross_color, 1.5)

	# Directional Vector Line when dragged
	if is_dragging and knob_pos != base_center:
		draw_line(base_center, knob_pos, Color(0.1, 0.95, 0.8, 0.7), 2.5)

	# Thumb Knob
	var knob_radius = max_radius * 0.36
	var knob_color = Color(0.1, 0.9, 1.0, 0.9) if is_dragging else Color(0.65, 0.80, 0.95, 0.75)
	draw_circle(knob_pos, knob_radius, knob_color)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 2.5, true)
	draw_circle(knob_pos, 4.0, Color(1, 1, 1, 0.9))

	# Axis Annotations (Bilingual labels matching Controller Reference Image)
	var font = ThemeDB.fallback_font
	if font:
		var lbl_col = Color(0.85, 0.92, 1.0, 0.85)
		if stick_type == "LEFT":
			# Top: Throttle +
			draw_string(font, Vector2(base_center.x - 70, base_center.y - max_radius - 6), "उचाइ + (Throttle)", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, lbl_col)
			# Bottom: Throttle -
			draw_string(font, Vector2(base_center.x - 70, base_center.y + max_radius + 16), "उचाइ - (Throttle)", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, lbl_col)
			# Left: Yaw Left
			draw_string(font, Vector2(base_center.x - max_radius - 95, base_center.y + 4), "बायाँ Yaw", HORIZONTAL_ALIGNMENT_RIGHT, 90, 11, lbl_col)
			# Right: Yaw Right
			draw_string(font, Vector2(base_center.x + max_radius + 6, base_center.y + 4), "दायाँ Yaw", HORIZONTAL_ALIGNMENT_LEFT, 90, 11, lbl_col)
		else:
			# Top: Pitch Forward
			draw_string(font, Vector2(base_center.x - 70, base_center.y - max_radius - 6), "अगाडि (Pitch +)", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, lbl_col)
			# Bottom: Pitch Backward
			draw_string(font, Vector2(base_center.x - 70, base_center.y + max_radius + 16), "पछाडि (Pitch -)", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, lbl_col)
			# Left: Roll Left
			draw_string(font, Vector2(base_center.x - max_radius - 95, base_center.y + 4), "बायाँ Roll", HORIZONTAL_ALIGNMENT_RIGHT, 90, 11, lbl_col)
			# Right: Roll Right
			draw_string(font, Vector2(base_center.x + max_radius + 6, base_center.y + 4), "दायाँ Roll", HORIZONTAL_ALIGNMENT_LEFT, 90, 11, lbl_col)
