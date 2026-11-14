class_name HomeArrow
extends Control

## HomeArrow: Vector-drawn dynamic pointer arrow toward launch/home coordinates.

@export var relative_angle_rad: float = 0.0:
	set(val):
		relative_angle_rad = val
		queue_redraw()

@export var distance_m: float = 0.0:
	set(val):
		distance_m = val
		queue_redraw()

@export var arrow_color: Color = Color(0.2, 0.95, 0.55, 0.95)
@export var is_imperial: bool = false

func update_home_vector(drone_pos: Vector3, drone_yaw_rad: float, home_pos: Vector3) -> void:
	var dx = home_pos.x - drone_pos.x
	var dz = home_pos.z - drone_pos.z
	distance_m = sqrt(dx * dx + dz * dz)
	# In Godot 3D: forward is -Z, right is +X.
	# Angle from drone to home in horizontal plane:
	var target_bearing = atan2(dx, -dz)
	relative_angle_rad = target_bearing - drone_yaw_rad
	queue_redraw()

func _draw() -> void:
	var center = Vector2(size.x * 0.35, size.y * 0.5)
	var arrow_len = minf(size.x, size.y) * 0.35

	# Draw circle guide
	draw_arc(center, arrow_len, 0.0, TAU, 32, Color(0.2, 0.5, 0.4, 0.4), 1.5)

	# Draw pointer arrow rotated by relative_angle_rad
	var fwd = Vector2(sin(relative_angle_rad), -cos(relative_angle_rad))
	var tip = center + fwd * arrow_len
	var right_norm = Vector2(-fwd.y, fwd.x)
	var left_flange = center - fwd * (arrow_len * 0.3) - right_norm * (arrow_len * 0.45)
	var right_flange = center - fwd * (arrow_len * 0.3) + right_norm * (arrow_len * 0.45)

	var arrow_pts = PackedVector2Array([tip, left_flange, center, right_flange])
	draw_colored_polygon(arrow_pts, arrow_color)

	# Distance text
	var font = get_theme_default_font()
	if font:
		var dist_text: String
		if is_imperial:
			dist_text = "HOME: %.1f ft" % (distance_m * 3.28084)
		else:
			dist_text = "HOME: %.1f m" % distance_m
		draw_string(font, Vector2(size.x * 0.72, size.y * 0.55), dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, arrow_color)
