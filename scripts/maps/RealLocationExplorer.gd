class_name RealLocationExplorer
extends Control

## RealLocationExplorer: Open/free-first map search, 2D vector preview,
## GPS privacy disclosure, and flight area launcher (Authored vs Approximate).

signal location_flight_requested(mode: String, location_def: Dictionary)
signal explorer_closed

@onready var input_search: LineEdit = $MainLayout/TopBar/HBoxSearch/InputSearch
@onready var btn_search: Button = $MainLayout/TopBar/HBoxSearch/BtnSearch
@onready var btn_gps: Button = $MainLayout/TopBar/HBoxSearch/BtnGPS
@onready var btn_close: Button = $MainLayout/TopBar/HBoxSearch/BtnClose

@onready var results_container: VBoxContainer = $MainLayout/Body/LeftPanel/ScrollResults/VBoxResults
@onready var map_canvas: MapCanvas2D = $MainLayout/Body/CenterPanel/MapCanvas2D

# Location Detail Controls
@onready var label_loc_title: Label = $MainLayout/Body/RightPanel/VBoxDetails/LabelTitle
@onready var label_loc_coords: Label = $MainLayout/Body/RightPanel/VBoxDetails/LabelCoords
@onready var label_loc_elev: Label = $MainLayout/Body/RightPanel/VBoxDetails/LabelElevation
@onready var label_loc_desc: Label = $MainLayout/Body/RightPanel/VBoxDetails/LabelDescription
@onready var label_attribution: Label = $MainLayout/Body/RightPanel/VBoxDetails/LabelAttribution

@onready var btn_fly_authored: Button = $MainLayout/Body/RightPanel/VBoxDetails/BtnFlyAuthored
@onready var btn_fly_approximate: Button = $MainLayout/Body/RightPanel/VBoxDetails/BtnFlyApproximate
@onready var label_status_banner: Label = $MainLayout/BottomBar/LabelStatus

var gps_service: GPSPermissionService
var selected_location: Dictionary = {}

func _ready() -> void:
	gps_service = GPSPermissionService.new()

	if btn_search and not btn_search.pressed.is_connected(_on_search_pressed):
		btn_search.pressed.connect(_on_search_pressed)
	if input_search and not input_search.text_submitted.is_connected(_on_search_submitted):
		input_search.text_submitted.connect(_on_search_submitted)
	if btn_gps and not btn_gps.pressed.is_connected(_on_gps_pressed):
		btn_gps.pressed.connect(_on_gps_pressed)
	if btn_close and not btn_close.pressed.is_connected(_on_close_pressed):
		btn_close.pressed.connect(_on_close_pressed)

	if btn_fly_authored and not btn_fly_authored.pressed.is_connected(_on_fly_authored_pressed):
		btn_fly_authored.pressed.connect(_on_fly_authored_pressed)
	if btn_fly_approximate and not btn_fly_approximate.pressed.is_connected(_on_fly_approximate_pressed):
		btn_fly_approximate.pressed.connect(_on_fly_approximate_pressed)

	# Initial population with default locations
	perform_search("")
	select_location(MapProviderService.get_default_location())

func _on_search_submitted(_text: String) -> void:
	_on_search_pressed()

func _on_search_pressed() -> void:
	var query = input_search.text if input_search else ""
	perform_search(query)

func perform_search(query: String) -> void:
	var results = MapProviderService.search_locations(query)
	_populate_results(results)
	if label_status_banner:
		label_status_banner.text = "Found %d location(s) matching '%s'" % [results.size(), query] if not query.is_empty() else "Showing offline geographic catalogue (%d locations)" % results.size()

func _populate_results(results: Array[Dictionary]) -> void:
	if not results_container:
		return

	for c in results_container.get_children():
		c.queue_free()

	for loc in results:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(240, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var has_authored = loc.get("has_authored_game_world", false)
		var badge = "[3D WORLD]" if has_authored else "[PROCEDURAL]"
		btn.text = "%s %s\n(%.3f°, %.3f°)" % [badge, loc.get("name", "Location"), loc.get("lat", 0.0), loc.get("lon", 0.0)]

		var loc_copy = loc.duplicate(true)
		btn.pressed.connect(func(): select_location(loc_copy))
		results_container.add_child(btn)

func select_location(loc: Dictionary) -> void:
	selected_location = loc

	var title = loc.get("display_name", loc.get("name", "Unknown"))
	var lat = loc.get("lat", 0.0)
	var lon = loc.get("lon", 0.0)
	var elev = loc.get("elevation_m", 0.0)
	var desc = loc.get("description", "")
	var has_authored = loc.get("has_authored_game_world", false)
	var game_world_id = loc.get("game_world_id", "")

	if label_loc_title:
		label_loc_title.text = loc.get("name", "Location")
	if label_loc_coords:
		label_loc_coords.text = "Coordinates: %.4f° N, %.4f° E" % [lat, lon]
	if label_loc_elev:
		label_loc_elev.text = "Regional Elevation: %.0f m MSL" % elev
	if label_loc_desc:
		label_loc_desc.text = desc
	if label_attribution:
		label_attribution.text = MapProviderService.get_attribution()

	if map_canvas:
		map_canvas.set_location(lat, lon, loc.get("name", "Location"))

	if btn_fly_authored:
		btn_fly_authored.visible = has_authored and not game_world_id.is_empty()
		if has_authored:
			btn_fly_authored.text = "FLY AUTHORED 3D WORLD (%s)" % game_world_id.to_upper()

	if btn_fly_approximate:
		btn_fly_approximate.text = "FLY APPROXIMATE WORLD (PROCEDURAL)"

func _on_gps_pressed() -> void:
	var status = gps_service.request_location_permission()
	if status == GPSPermissionService.PermissionStatus.UNAVAILABLE or status == GPSPermissionService.PermissionStatus.DENIED:
		if label_status_banner:
			label_status_banner.text = "GPS Unavailable on this device. Defaulting to local base: Butwal, Nepal."
		select_location(MapProviderService.get_default_location())
	else:
		gps_service.simulate_permission_response(true, 27.7006, 83.4484)
		var pos = gps_service.get_last_known_position()
		if label_status_banner:
			label_status_banner.text = "GPS Acquired: %.4f° N, %.4f° E (Accuracy: ±%.1fm)" % [pos.get("lat", 0.0), pos.get("lon", 0.0), pos.get("accuracy_m", 0.0)]

func _on_fly_authored_pressed() -> void:
	if selected_location.is_empty():
		return
	var world_id = selected_location.get("game_world_id", "")
	var world_def = WorldData.get_world_by_id(world_id)
	if not world_def.is_empty() and world_def.has("scene_path"):
		location_flight_requested.emit("authored", selected_location)
		get_tree().change_scene_to_file(world_def["scene_path"])

func _on_fly_approximate_pressed() -> void:
	if selected_location.is_empty():
		return
	location_flight_requested.emit("approximate", selected_location)
	get_tree().change_scene_to_file("res://scenes/worlds/ProceduralLocationWorld.tscn")

func _on_close_pressed() -> void:
	explorer_closed.emit()
	visible = false
