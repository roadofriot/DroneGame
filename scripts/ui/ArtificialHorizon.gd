class_name ArtificialHorizon
extends Control

## ArtificialHorizon: Procedural vector-drawn pitch ladder and roll indicator.
## Zero external textures or fonts required.

@export var pitch_deg: float = 0.0:
	set(val):
		pitch_deg = clampf(val, -89.0, 89.0)
		queue_redraw()

@export var roll_deg: float = 0.0:
	set(val):
		roll_deg = posmod(val + 180.0, 360.0) - 180.0
		queue_redraw()

@export var pixels_per_degree: float = 2.4
@export var horizon_color: Color = Color(0.2, 0.85, 1.0, 0.9)
@export var ground_color: Color = Color(0.65, 0.45, 0.2, 0.4)
@export var sky_color: Color = Color(0.15, 0.45, 0.75, 0.4)
@export var reticle_color: Color = Color(1.0, 0.82, 0.15, 0.95)

func set_attitude(p_pitch_deg: float, p_roll_deg: float) -> void:
	pitch_deg = p_pitch_deg
	roll_deg = p_roll_deg

func _draw() -> void:
	var center = size * 0.5
	var radius = minf(size.x, size.y) * 0.46
	if radius <= 5.0:
		return

	# Circular clipping boundary ring
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.15, 0.35, 0.5, 0.5), 2.0, true)

	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()

	# Save transform and apply roll rotation + pitch vertical shift
	var roll_rad = deg_to_rad(-roll_deg)
	var pitch_offset_y = pitch_deg * pixels_per_degree

	# We draw the ladder transformed
	draw_set_transform(center, roll_rad, Vector2.ONE)

	# Sky / Ground separation line (Horizon line)
	var horiz_y = pitch_offset_y
	draw_line(Vector2(-radius * 0.9, horiz_y), Vector2(radius * 0.9, horiz_y), horizon_color, 2.5, true)

	# Pitch ladder rungs: +/- 5, 10, 15, 20, 25, 30, 45, 60 deg
	var rungs = [5, 10, 15, 20, 25, 30, 45, 60, -5, -10, -15, -20, -25, -30, -45, -60]
	for deg in rungs:
		var rung_y = horiz_y - deg * pixels_per_degree
		if absf(rung_y) > radius * 0.85:
			continue # out of circular viewport

		var is_major = (abs(deg) % 10 == 0)
		var half_w = (radius * 0.35) if is_major else (radius * 0.2)
		var notch_h = 4.0 if deg > 0 else -4.0 # pointing toward horizon
		var rung_col = horizon_color if deg > 0 else Color(0.85, 0.55, 0.3, 0.85)

		# Left segment
		draw_line(Vector2(-half_w, rung_y), Vector2(-12.0, rung_y), rung_col, 1.5, true)
		if is_major:
			draw_line(Vector2(-half_w, rung_y), Vector2(-half_w, rung_y + notch_h), rung_col, 1.5, true)
			if font:
				draw_string(font, Vector2(-half_w - 24.0, rung_y + 4.0), str(abs(deg)), HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, rung_col)

		# Right segment
		draw_line(Vector2(12.0, rung_y), Vector2(half_w, rung_y), rung_col, 1.5, true)
		if is_major:
			draw_line(Vector2(half_w, rung_y), Vector2(half_w, rung_y + notch_h), rung_col, 1.5, true)
			if font:
				draw_string(font, Vector2(half_w + 6.0, rung_y + 4.0), str(abs(deg)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, rung_col)

	# Reset transform to draw fixed aircraft reticle in center
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Fixed Center Aircraft Reticle: [ —  •  — ]
	var rw = 22.0
	var rh = 4.0
	# Left wing
	draw_line(center + Vector2(-rw - 8.0, 0.0), center + Vector2(-8.0, 0.0), reticle_color, 2.5, true)
	draw_line(center + Vector2(-8.0, 0.0), center + Vector2(-8.0, rh), reticle_color, 2.5, true)
	# Center dot
	draw_circle(center, 2.5, reticle_color)
	# Right wing
	draw_line(center + Vector2(8.0, 0.0), center + Vector2(rw + 8.0, 0.0), reticle_color, 2.5, true)
	draw_line(center + Vector2(8.0, 0.0), center + Vector2(8.0, rh), reticle_color, 2.5, true)
