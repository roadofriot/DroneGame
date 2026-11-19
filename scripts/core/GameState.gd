class_name GameStateAutoload
extends Node

## GameState: Global game session state and persistent flight data autoload (Phase 9).
## Coordinates active drone preset, tuning profile, true world home position,
## settings service, and cumulative flight telemetry across world scenes.

signal session_started
signal drone_preset_changed(preset_name: String)
signal flight_profile_changed(profile_name: String)
signal home_updated(true_home_pos: Vector3)

# Active Drone Spec Preset ("scout", "photo", "racer")
var active_preset: String = "scout"

# Active Flight Tuning Profile ("cine", "normal", "sport", "acro")
var active_flight_profile: String = "normal"

# True World Home Position (64-bit coordinates, invariant under origin shifts)
var true_home_position: Vector3 = Vector3.ZERO

# Cumulative Session Telemetry
var total_flight_time_seconds: float = 0.0
var total_distance_meters: float = 0.0
var battery_remaining_percent: float = 100.0

# Open-World Adventure State
var active_adventure_stage: String = "stage_01_butwal"
var active_target_destination: String = "stage_02_lumbini"

# Settings Service reference
var settings_service: SettingsService = null

func _ready() -> void:
	settings_service = SettingsService.new()
	session_started.emit()

func set_active_preset(p_name: String) -> void:
	active_preset = p_name.to_lower()
	drone_preset_changed.emit(active_preset)

func set_flight_profile(prof_name: String) -> void:
	active_flight_profile = prof_name.to_lower()
	flight_profile_changed.emit(active_flight_profile)

func set_true_home(pos: Vector3) -> void:
	true_home_position = pos
	home_updated.emit(true_home_position)

func record_distance_traveled(meters: float) -> void:
	if meters > 0.0 and is_finite(meters):
		total_distance_meters += meters

func record_flight_time(delta: float) -> void:
	if delta > 0.0 and is_finite(delta):
		total_flight_time_seconds += delta

func reset_session() -> void:
	total_flight_time_seconds = 0.0
	total_distance_meters = 0.0
	battery_remaining_percent = 100.0
	true_home_position = Vector3.ZERO
