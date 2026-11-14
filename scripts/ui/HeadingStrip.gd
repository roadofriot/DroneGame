class_name HeadingStrip
extends Control

## HeadingStrip: Procedural vector-drawn 0..360° compass ribbon with cardinal marks.
## Zero external textures or fonts required.

@export var heading_deg: float = 0.0:
	set(val):
		heading_deg = fmod(val, 360.0)
		if heading_deg < 0.0:
			heading_deg += 360.0
		queue_redraw()

@export var pixels_per_degree: float = 2.2
@export var strip_color: Color = Color(0.2, 0.85, 1.0, 0.9)
@export var marker_color: Color = Color(1.0, 0.82, 0.15, 0.95)
@export var bg_color: Color = Color(0.04, 0.08, 0.14, 0.65)

const CARDINALS = {
	0: "N",
	45: "NE",
	90: "E",
	135: "SE",
	180: "S",
	225: "SW",
	270: "W",
	315: "NW"
}

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 10.0 or h <= 10.0:
		return

	# Draw background pill/box
	draw_rect(Rect2(0, 0, w, h), bg_color, true)
	draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.45, 0.65, 0.4), false, 1.0)

	var center_x = w * 0.5
	var font = get_theme_default_font()
	var visible_span_deg = (w * 0.5) / pixels_per_degree

	var min_deg = int(floor(heading_deg - visible_span_deg))
	var max_deg = int(ceil(heading_deg + visible_span_deg))

	# Draw ticks and numbers every 5 and 15 degrees
	for deg_raw in range(min_deg - 5, max_deg + 6):
		if deg_raw % 5 != 0:
			continue

		var norm_deg = int(posmod(deg_raw, 360))
		var delta_deg = float(deg_raw) - heading_deg
		var x = center_x + delta_deg * pixels_per_degree

		if x < 4.0 or x > w - 4.0:
			continue

		var is_major = (norm_deg % 15 == 0)
		var is_cardinal = CARDINALS.has(norm_deg)
		var tick_len = (h * 0.4) if is_major else (h * 0.22)

		draw_line(Vector2(x, h - tick_len), Vector2(x, h - 2.0), strip_color, 1.5 if is_major else 1.0)

		if font:
			if is_cardinal:
				var c_str = CARDINALS[norm_deg]
				var c_col = Color.RED if c_str == "N" else marker_color
				draw_string(font, Vector2(x - 8.0, h - tick_len - 3.0), c_str, HORIZONTAL_ALIGNMENT_CENTER, 16, 11, c_col)
			elif is_major:
				var num_str = "%03d" % norm_deg
				draw_string(font, Vector2(x - 12.0, h - tick_len - 3.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, 24, 9, Color(0.6, 0.8, 0.95, 0.8))

	# Center Lubber Line / Pointer (Triangle pointing down)
	var tri = PackedVector2Array([
		Vector2(center_x - 5.0, 2.0),
		Vector2(center_x + 5.0, 2.0),
		Vector2(center_x, 9.0)
	])
	draw_colored_polygon(tri, marker_color)
	draw_line(Vector2(center_x, 8.0), Vector2(center_x, h - 2.0), marker_color, 1.5)
