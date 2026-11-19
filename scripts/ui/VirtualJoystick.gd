class_name VirtualJoystick
extends Control

## VirtualJoystick: Precision Multi-Touch Analog Stick with Strict Pointer Isolation.
## Guarantees true simultaneous dual-stick multi-touch operation without pointer stealing,
## axis crosstalk, or false release triggers between left and right controls.

signal stick_moved(value: Vector2)
signal stick_released

const MOUSE_POINTER_ID: int = -999

@export var max_radius: float = 170.0
@export var deadzone: float = 0.05
@export var stick_name: String = "" # e.g. "THROTTLE / YAW" or "PITCH / ROLL"
@export var stick_type: String = "LEFT" # "LEFT" or "RIGHT"

var stick_vector: Vector2 = Vector2.ZERO # x in [-1,1], y in [-1,1] (up is +1)
var is_dragging: bool = false
var touch_pointer_id: int = -1

var base_center: Vector2 = Vector2.ZERO
var knob_pos: Vector2 = Vector2.ZERO
var target_knob_pos: Vector2 = Vector2.ZERO

# Animation and visual state
var active_glow_alpha: float = 0.0
var pulse_time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(400.0, 400.0)
	mouse_filter = MOUSE_FILTER_IGNORE
	base_center = size / 2.0
	knob_pos = base_center
	target_knob_pos = base_center
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

func _on_resized() -> void:
	base_center = size / 2.0
	if not is_dragging:
		target_knob_pos = base_center
		knob_pos = base_center
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_dragging:
			_release_stick()

func _process(delta: float) -> void:
	pulse_time += delta

	# Dual-phase silky spring animation
	var smooth_rate = 42.0 if is_dragging else 28.0
	var prev_knob = knob_pos
	knob_pos = knob_pos.lerp(target_knob_pos, clampf(smooth_rate * delta, 0.0, 1.0))

	# Glow animation interpolation
	var target_alpha = 1.0 if is_dragging else 0.0
	active_glow_alpha = move_toward(active_glow_alpha, target_alpha, 4.0 * delta)

	if knob_pos.distance_squared_to(prev_knob) > 0.01 or is_dragging or active_glow_alpha > 0.01:
		queue_redraw()

## Checks whether a touch coordinate falls within this joystick's active zone.
func _is_point_inside(pt: Vector2, is_local: bool) -> bool:
	var local_pos = pt if is_local else (get_global_transform().affine_inverse() * pt)
	var hit_radius = max_radius * 1.35
	if local_pos.distance_to(base_center) <= hit_radius:
		return true
	if is_local:
		return Rect2(Vector2.ZERO, size).has_point(pt)
	return get_global_rect().has_point(pt)

## Handles GUI input when dispatched directly (e.g. unit tests or UI events)
func _gui_input(event: InputEvent) -> void:
	_process_input_event(event, true)

func _input(event: InputEvent) -> void:
	_process_input_event(event, false)

func _process_input_event(event: InputEvent, is_local: bool) -> void:
	# 1. Multi-Touch Screen Events (True simultaneous independent pointer support)
	if event is InputEventScreenTouch:
		if event.pressed:
			if not is_dragging and _is_point_inside(event.position, is_local):
				is_dragging = true
				touch_pointer_id = event.index
				var local_pos = event.position if is_local else (get_global_transform().affine_inverse() * event.position)
				_update_stick_target(local_pos)
		else:
			if is_dragging and event.index == touch_pointer_id:
				_release_stick()

	elif event is InputEventScreenDrag:
		if is_dragging and event.index == touch_pointer_id:
			var local_pos = event.position if is_local else (get_global_transform().affine_inverse() * event.position)
			_update_stick_target(local_pos)

	# 2. Desktop Mouse Events (Isolated fallback for desktop testing)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_dragging and _is_point_inside(event.position, is_local):
					is_dragging = true
					touch_pointer_id = MOUSE_POINTER_ID
					var local_pos = event.position if is_local else (get_global_transform().affine_inverse() * event.position)
					_update_stick_target(local_pos)
			else:
				if is_dragging and touch_pointer_id == MOUSE_POINTER_ID:
					_release_stick()

	elif event is InputEventMouseMotion:
		var is_mouse_down = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if is_dragging and touch_pointer_id == MOUSE_POINTER_ID and is_mouse_down:
			var local_pos = event.position if is_local else (get_global_transform().affine_inverse() * event.position)
			_update_stick_target(local_pos)

func _update_stick_target(pos: Vector2) -> void:
	var delta_vec = pos - base_center
	var dist = delta_vec.length()
	if dist > max_radius:
		delta_vec = delta_vec.normalized() * max_radius

	target_knob_pos = base_center + delta_vec

	# Normalized mapping: X is right (+1) / left (-1), Y is up (+1) / down (-1)
	var norm_x = delta_vec.x / max_radius
	var norm_y = -delta_vec.y / max_radius

	if absf(norm_x) < deadzone:
		norm_x = 0.0
	if absf(norm_y) < deadzone:
		norm_y = 0.0

	stick_vector = Vector2(norm_x, norm_y)
	stick_moved.emit(stick_vector)

func _release_stick() -> void:
	is_dragging = false
	touch_pointer_id = -1
	target_knob_pos = base_center
	stick_vector = Vector2.ZERO
	stick_moved.emit(stick_vector)
	stick_released.emit()

func _draw() -> void:
	# 1. Outer Ambient Glow Halo
	if active_glow_alpha > 0.05:
		var glow_col = Color(0.1, 0.88, 1.0, 0.20 * active_glow_alpha)
		draw_circle(base_center, max_radius * 1.15, glow_col)

	# 2. Main Outer Bezel Ring
	var base_bg = Color(0.03, 0.07, 0.13, 0.68)
	var outer_border = Color(0.18, 0.92, 1.0, 0.95) if is_dragging else Color(0.28, 0.65, 0.88, 0.60)
	draw_circle(base_center, max_radius, base_bg)
	draw_arc(base_center, max_radius, 0.0, TAU, 64, outer_border, 3.8, true)

	# Concentric Intermediate Rings
	draw_arc(base_center, max_radius * 0.72, 0.0, TAU, 48, Color(0.25, 0.80, 1.0, 0.25), 1.6, true)
	draw_arc(base_center, max_radius * 0.40, 0.0, TAU, 32, Color(1, 1, 1, 0.16), 1.2, true)

	# 3. Precision Compass Graduation Ticks (16 Ticks)
	var tick_color = Color(0.75, 0.92, 1.0, 0.60)
	for i in range(16):
		var ang = (TAU / 16.0) * i
		var dir = Vector2(cos(ang), sin(ang))
		var is_cardinal = (i % 4 == 0)
		var tick_len = 14.0 if is_cardinal else 7.0
		var r_outer = max_radius - 2.0
		var r_inner = r_outer - tick_len
		var t_col = Color(0.25, 0.98, 1.0, 0.90) if is_cardinal else tick_color
		var t_w = 2.8 if is_cardinal else 1.5
		draw_line(base_center + dir * r_inner, base_center + dir * r_outer, t_col, t_w)

	# 4. 8 Directional Guidance Arrows
	var arrow_color = Color(0.35, 0.98, 1.0, 0.95) if is_dragging else Color(0.88, 0.95, 1.0, 0.78)
	for i in range(8):
		var ang = (TAU / 8.0) * i - (PI / 2.0)
		var dir = Vector2(cos(ang), sin(ang))
		var perp = Vector2(-dir.y, dir.x)
		var p_start = base_center + dir * (max_radius * 0.45)
		var p_tip = base_center + dir * (max_radius * 0.82)
		var p_base = base_center + dir * (max_radius * 0.68)
		var p_left = p_base + perp * 7.5
		var p_right = p_base - perp * 7.5
		draw_line(p_start, p_base, arrow_color, 2.8)
		draw_colored_polygon(PackedVector2Array([p_tip, p_left, p_right]), arrow_color)

	# 5. Reticle Crosshairs
	var cross_color = Color(0.22, 0.88, 1.0, 0.30)
	draw_line(base_center - Vector2(max_radius * 0.92, 0), base_center + Vector2(max_radius * 0.92, 0), cross_color, 1.5)
	draw_line(base_center - Vector2(0, max_radius * 0.92), base_center + Vector2(0, max_radius * 0.92), cross_color, 1.5)

	# 6. Dynamic Vector Line
	if knob_pos.distance_to(base_center) > 4.0:
		var line_color = Color(0.15, 1.0, 0.88, 0.80)
		draw_line(base_center, knob_pos, line_color, 3.2)

	# 7. Thumb Knob Cap (Large, Comfortable Pad)
	var knob_radius = max_radius * 0.34
	var knob_fill = Color(0.10, 0.80, 0.98, 0.94) if is_dragging else Color(0.65, 0.82, 0.95, 0.80)
	var knob_stroke = Color(1.0, 1.0, 1.0, 0.98)
	draw_circle(knob_pos, knob_radius, knob_fill)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 36, knob_stroke, 3.0, true)
	draw_arc(knob_pos, knob_radius * 0.65, 0.0, TAU, 24, Color(0.05, 0.22, 0.38, 0.65), 1.6, true)
	draw_circle(knob_pos, 5.5, Color(1, 1, 1, 1.0))

	# 8. Bilingual Directional Annotations
	var font = ThemeDB.fallback_font
	if font:
		var lbl_col = Color(0.90, 0.96, 1.0, 0.92)
		if stick_type == "LEFT":
			# Top: Throttle +
			draw_string(font, Vector2(base_center.x - 85, base_center.y - max_radius - 10), "उचाइ + (Throttle)", HORIZONTAL_ALIGNMENT_CENTER, 170, 12, lbl_col)
			# Bottom: Throttle -
			draw_string(font, Vector2(base_center.x - 85, base_center.y + max_radius + 20), "उचाइ - (Throttle)", HORIZONTAL_ALIGNMENT_CENTER, 170, 12, lbl_col)
			# Left: Yaw Left
			draw_string(font, Vector2(base_center.x - max_radius - 115, base_center.y + 4), "बायाँ Yaw", HORIZONTAL_ALIGNMENT_RIGHT, 110, 12, lbl_col)
			# Right: Yaw Right
			draw_string(font, Vector2(base_center.x + max_radius + 10, base_center.y + 4), "दायाँ Yaw", HORIZONTAL_ALIGNMENT_LEFT, 110, 12, lbl_col)
		else:
			# Top: Pitch Forward
			draw_string(font, Vector2(base_center.x - 85, base_center.y - max_radius - 10), "अगाडि (Pitch +)", HORIZONTAL_ALIGNMENT_CENTER, 170, 12, lbl_col)
			# Bottom: Pitch Backward
			draw_string(font, Vector2(base_center.x - 85, base_center.y + max_radius + 20), "पछाडि (Pitch -)", HORIZONTAL_ALIGNMENT_CENTER, 170, 12, lbl_col)
			# Left: Roll Left
			draw_string(font, Vector2(base_center.x - max_radius - 115, base_center.y + 4), "बायाँ Roll", HORIZONTAL_ALIGNMENT_RIGHT, 110, 12, lbl_col)
			# Right: Roll Right
			draw_string(font, Vector2(base_center.x + max_radius + 10, base_center.y + 4), "दायाँ Roll", HORIZONTAL_ALIGNMENT_LEFT, 110, 12, lbl_col)
