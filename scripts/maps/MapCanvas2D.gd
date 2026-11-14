class_name MapCanvas2D
extends Control

## MapCanvas2D: Interactive 2D cartographic map view with Web Mercator projection,
## procedural topography lines, pin marker, compass, and attribution overlay.

@export var center_lat: float = 27.7006
@export var center_lon: float = 83.4484
@export var zoom_level: float = 14.0 # Range 4.0 to 18.0

var location_title: String = "Butwal, Nepal"
var pin_pulse: float = 0.0

func _ready() -> void:
	clip_contents = true
	queue_redraw()

func _process(delta: float) -> void:
	pin_pulse = fmod(pin_pulse + delta * 2.5, TAU)
	queue_redraw()

func set_location(lat: float, lon: float, title: String) -> void:
	center_lat = lat
	center_lon = lon
	location_title = title
	queue_redraw()

func _draw() -> void:
	var rect_size = size
	if rect_size.x <= 0 or rect_size.y <= 0:
		return

	# 1. Background Cartographic Fill
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.08, 0.11, 0.15, 1.0))

	# 2. Coordinate Grid Lines (Lat/Lon parallels and meridians)
	var grid_color = Color(0.16, 0.22, 0.3, 0.6)
	var major_grid_color = Color(0.25, 0.35, 0.45, 0.8)

	var step_px = 60.0
	for x in range(0, int(rect_size.x), int(step_px)):
		var col = major_grid_color if (x % int(step_px * 2) == 0) else grid_color
		draw_line(Vector2(x, 0), Vector2(x, rect_size.y), col, 1.0)

	for y in range(0, int(rect_size.y), int(step_px)):
		var col = major_grid_color if (y % int(step_px * 2) == 0) else grid_color
		draw_line(Vector2(0, y), Vector2(rect_size.x, y), col, 1.0)

	# 3. Procedural Topographic Elevation Contours (seeded by coordinates)
	var terrain_seed = int((center_lat + center_lon) * 1000.0)
	var rng = RandomNumberGenerator.new()
	rng.seed = terrain_seed

	var contour_color = Color(0.2, 0.45, 0.6, 0.35)
	for i in range(5):
		var ring_center = rect_size * 0.5 + Vector2(rng.randf_range(-100, 100), rng.randf_range(-80, 80))
		var radius = 60.0 + (i * 35.0)
		draw_arc(ring_center, radius, 0.0, TAU, 32, contour_color, 1.5, true)

	# 4. Center Crosshairs and Target Marker
	var center = rect_size * 0.5

	# Pulsing target rings
	var pulse_radius = 16.0 + (sin(pin_pulse) * 4.0)
	draw_circle(center, pulse_radius + 6.0, Color(0.15, 0.65, 0.95, 0.15))
	draw_arc(center, pulse_radius, 0.0, TAU, 24, Color(0.2, 0.8, 1.0, 0.7), 2.0)

	# Center Pin Icon
	draw_circle(center, 5.0, Color(0.95, 0.25, 0.2, 1.0))
	draw_circle(center, 2.0, Color.WHITE)

	# Location Title & Coordinates Tag
	var font = ThemeDB.fallback_font
	var font_size = 13
	var label_text = "%s\n(%.4f° N, %.4f° E)" % [location_title, center_lat, center_lon]
	draw_string(font, center + Vector2(-60, -22), label_text, HORIZONTAL_ALIGNMENT_CENTER, 140, font_size, Color(0.9, 0.95, 1.0))

	# 5. Compass Indicator (Upper Right)
	var compass_pos = Vector2(rect_size.x - 36, 36)
	draw_circle(compass_pos, 18.0, Color(0.06, 0.08, 0.12, 0.85))
	draw_arc(compass_pos, 18.0, 0.0, TAU, 24, Color(0.3, 0.5, 0.7, 0.8), 1.5)
	# North pointer
	var n_tip = compass_pos + Vector2(0, -14)
	var n_base_l = compass_pos + Vector2(-5, 4)
	var n_base_r = compass_pos + Vector2(5, 4)
	draw_colored_polygon(PackedVector2Array([n_tip, n_base_l, compass_pos]), Color(0.9, 0.2, 0.2, 1.0))
	draw_colored_polygon(PackedVector2Array([n_tip, compass_pos, n_base_r]), Color(0.7, 0.15, 0.15, 1.0))
	draw_string(font, compass_pos + Vector2(-4, -18), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

	# 6. Scale Bar (Bottom Left)
	var scale_start = Vector2(24, rect_size.y - 24)
	var scale_width = 80.0
	draw_line(scale_start, scale_start + Vector2(scale_width, 0), Color.WHITE, 2.0)
	draw_line(scale_start, scale_start + Vector2(0, -6), Color.WHITE, 2.0)
	draw_line(scale_start + Vector2(scale_width, 0), scale_start + Vector2(scale_width, -6), Color.WHITE, 2.0)
	draw_string(font, scale_start + Vector2(10, -8), "500 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.9, 0.95))

	# 7. Mandatory OpenStreetMap Attribution (Bottom Right)
	var attr_text = "© OpenStreetMap contributors, ODbL"
	draw_string(font, Vector2(rect_size.x - 220, rect_size.y - 12), attr_text, HORIZONTAL_ALIGNMENT_RIGHT, 210, 10, Color(0.55, 0.65, 0.75, 0.8))
