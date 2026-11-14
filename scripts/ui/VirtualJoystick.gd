class_name VirtualJoystick
extends Control

## VirtualJoystick: High-Performance Multi-Touch Analog Controller with Smooth Physics Animation.
## Features enlarged touch footprint (370x370), responsive spring-damped knob animation,
## illuminated aeronautical crosshairs, and zero axis interference.

signal stick_moved(value: Vector2)
signal stick_released

@export var max_radius: float = 155.0
@export var deadzone: float = 0.05
@export var stick_name: String = "" # e.g. "THROTTLE / YAW" or "PITCH / ROLL"
@export var stick_type: String = "LEFT" # "LEFT" or "RIGHT"

var stick_vector: Vector2 = Vector2.ZERO # x in [-1,1], y in [-1,1] (up is +1)
var is_dragging: bool = false
var touch_pointer_id: int = -1

var base_center: Vector2 = Vector2.ZERO
var knob_pos: Vector2 = Vector2.ZERO
var target_knob_pos: Vector2 = Vector2.ZERO

# Animation & Touch State
var active_glow_alpha: float = 0.0
var pulse_time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(370.0, 370.0)
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		if is_dragging:
			_release_stick()

func _process(delta: float) -> void:
	pulse_time += delta

	# Smooth Spring Knob Animation: fast response under finger, smooth elastic bounce to center on release
	var smooth_speed = 36.0 if is_dragging else 24.0
	var prev_knob = knob_pos
	knob_pos = knob_pos.lerp(target_knob_pos, clampf(smooth_speed * delta, 0.0, 1.0))

	# Glow animation fade
	var target_alpha = 1.0 if is_dragging else 0.0
	active_glow_alpha = move_toward(active_glow_alpha, target_alpha, 4.0 * delta)

	# Redraw if moving or animating glow
	if knob_pos.distance_squared_to(prev_knob) > 0.01 or is_dragging or active_glow_alpha > 0.01:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# Primary Touch Event Entrypoint
	if event is InputEventScreenTouch:
		if event.pressed and not is_dragging:
			is_dragging = true
			Input.vibrate_handheld(25) # Crisp tactile response on contact
			touch_pointer_id = event.index
			_update_stick_target(event.position)
			accept_event()
		elif not event.pressed and event.index == touch_pointer_id:
			_release_stick()
			accept_event()

	# Desktop Mouse Fallback
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not is_dragging:
				is_dragging = true
				touch_pointer_id = 0
				_update_stick_target(event.position)
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
			_update_stick_target(local_pos)

	# Global release tracking - ensures no stuck sticks even if finger lifts outside rect
	elif event is InputEventScreenTouch:
		if not event.pressed and event.index == touch_pointer_id:
			_release_stick()

	# Mouse motion tracking
	elif event is InputEventMouseMotion:
		if touch_pointer_id == 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var local_pos = get_global_transform().affine_inverse() * event.position
			_update_stick_target(local_pos)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release_stick()

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
		var glow_col = Color(0.1, 0.85, 1.0, 0.18 * active_glow_alpha)
		draw_circle(base_center, max_radius * 1.15, glow_col)

	# 2. Main Outer Base Ring (High-Tech Aeronautical Bezel)
	var base_bg = Color(0.03, 0.07, 0.12, 0.65)
	var outer_border = Color(0.15, 0.88, 1.0, 0.90) if is_dragging else Color(0.25, 0.60, 0.82, 0.55)
	draw_circle(base_center, max_radius, base_bg)
	draw_arc(base_center, max_radius, 0.0, TAU, 64, outer_border, 3.5, true)
	
	# Concentric Intermediate Rings
	draw_arc(base_center, max_radius * 0.72, 0.0, TAU, 48, Color(0.2, 0.75, 1.0, 0.22), 1.5, true)
	draw_arc(base_center, max_radius * 0.40, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 1.2, true)

	# 3. Precision Compass Graduation Ticks (16 Ticks around circumference)
	var tick_color = Color(0.7, 0.9, 1.0, 0.55)
	for i in range(16):
		var ang = (TAU / 16.0) * i
		var dir = Vector2(cos(ang), sin(ang))
		var is_cardinal = (i % 4 == 0)
		var tick_len = 12.0 if is_cardinal else 6.0
		var r_outer = max_radius - 2.0
		var r_inner = r_outer - tick_len
		var t_col = Color(0.2, 0.95, 1.0, 0.85) if is_cardinal else tick_color
		var t_w = 2.5 if is_cardinal else 1.5
		draw_line(base_center + dir * r_inner, base_center + dir * r_outer, t_col, t_w)

	# 4. 8 Directional Guidance Arrows (High Contrast)
	var arrow_color = Color(0.3, 0.95, 1.0, 0.95) if is_dragging else Color(0.85, 0.93, 1.0, 0.75)
	for i in range(8):
		var ang = (TAU / 8.0) * i - (PI / 2.0)
		var dir = Vector2(cos(ang), sin(ang))
		var perp = Vector2(-dir.y, dir.x)
		var p_start = base_center + dir * (max_radius * 0.45)
		var p_tip = base_center + dir * (max_radius * 0.82)
		var p_base = base_center + dir * (max_radius * 0.68)
		var p_left = p_base + perp * 7.0
		var p_right = p_base - perp * 7.0
		draw_line(p_start, p_base, arrow_color, 2.5)
		draw_colored_polygon(PackedVector2Array([p_tip, p_left, p_right]), arrow_color)

	# 5. Fine Reticle Crosshairs
	var cross_color = Color(0.2, 0.85, 1.0, 0.28)
	draw_line(base_center - Vector2(max_radius * 0.92, 0), base_center + Vector2(max_radius * 0.92, 0), cross_color, 1.5)
	draw_line(base_center - Vector2(0, max_radius * 0.92), base_center + Vector2(0, max_radius * 0.92), cross_color, 1.5)

	# 6. Connecting Dynamic Vector Line
	if knob_pos.distance_to(base_center) > 4.0:
		var line_color = Color(0.1, 0.98, 0.85, 0.75)
		draw_line(base_center, knob_pos, line_color, 3.0)

	# 7. Thumb Knob (Multi-ring precision tactile cap)
	var knob_radius = max_radius * 0.33
	var knob_fill = Color(0.08, 0.75, 0.95, 0.92) if is_dragging else Color(0.60, 0.78, 0.92, 0.78)
	var knob_stroke = Color(1.0, 1.0, 1.0, 0.95)
	draw_circle(knob_pos, knob_radius, knob_fill)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 36, knob_stroke, 2.8, true)
	draw_arc(knob_pos, knob_radius * 0.65, 0.0, TAU, 24, Color(0.05, 0.2, 0.35, 0.6), 1.5, true)
	draw_circle(knob_pos, 5.0, Color(1, 1, 1, 0.98))

	# 8. Bilingual Directional Annotations
	var font = ThemeDB.fallback_font
	if font:
		var lbl_col = Color(0.88, 0.94, 1.0, 0.90)
		if stick_type == "LEFT":
			# Top: Throttle +
			draw_string(font, Vector2(base_center.x - 75, base_center.y - max_radius - 8), "उचाइ + (Throttle)", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, lbl_col)
			# Bottom: Throttle -
			draw_string(font, Vector2(base_center.x - 75, base_center.y + max_radius + 18), "उचाइ - (Throttle)", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, lbl_col)
			# Left: Yaw Left
			draw_string(font, Vector2(base_center.x - max_radius - 105, base_center.y + 4), "बायाँ Yaw", HORIZONTAL_ALIGNMENT_RIGHT, 100, 12, lbl_col)
			# Right: Yaw Right
			draw_string(font, Vector2(base_center.x + max_radius + 8, base_center.y + 4), "दायाँ Yaw", HORIZONTAL_ALIGNMENT_LEFT, 100, 12, lbl_col)
		else:
			# Top: Pitch Forward
			draw_string(font, Vector2(base_center.x - 75, base_center.y - max_radius - 8), "अगाडि (Pitch +)", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, lbl_col)
			# Bottom: Pitch Backward
			draw_string(font, Vector2(base_center.x - 75, base_center.y + max_radius + 18), "पछाडि (Pitch -)", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, lbl_col)
			# Left: Roll Left
			draw_string(font, Vector2(base_center.x - max_radius - 105, base_center.y + 4), "बायाँ Roll", HORIZONTAL_ALIGNMENT_RIGHT, 100, 12, lbl_col)
			# Right: Roll Right
			draw_string(font, Vector2(base_center.x + max_radius + 8, base_center.y + 4), "दायाँ Roll", HORIZONTAL_ALIGNMENT_LEFT, 100, 12, lbl_col)
