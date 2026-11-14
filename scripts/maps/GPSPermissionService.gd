class_name GPSPermissionService
extends RefCounted

## GPSPermissionService: Privacy-compliant GPS location permission handler.
## Enforces user disclosure, permission gating, accuracy tracking, and graceful manual fallback.

signal permission_status_changed(new_status: int)
signal location_acquired(lat: float, lon: float, accuracy_m: float, timestamp: int)
signal permission_denied(explanation: String)

enum PermissionStatus { NOT_REQUESTED, GRANTED, DENIED, UNAVAILABLE }

const DISCLOSURE_NOTICE = "GPS location is used solely to center the 2D map on your approximate current area. Coordinates are processed locally on your device and are never transmitted to external servers or logged permanently."

var current_status: PermissionStatus = PermissionStatus.NOT_REQUESTED
var last_latitude: float = 0.0
var last_longitude: float = 0.0
var last_accuracy_m: float = 0.0
var last_timestamp: int = 0

func get_disclosure_text() -> String:
	return DISCLOSURE_NOTICE

func request_location_permission() -> PermissionStatus:
	# On desktop Linux/Windows, native mobile GPS sensor is unavailable
	# We simulate graceful detection or allow user toggle
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		# OS permission check hook
		current_status = PermissionStatus.NOT_REQUESTED
	else:
		# Desktop environments default to manual search unless simulated
		if current_status == PermissionStatus.NOT_REQUESTED:
			current_status = PermissionStatus.UNAVAILABLE
	permission_status_changed.emit(current_status)
	return current_status

func simulate_permission_response(granted: bool, lat: float = 27.7006, lon: float = 83.4484, accuracy: float = 15.0) -> void:
	if granted:
		current_status = PermissionStatus.GRANTED
		last_latitude = lat
		last_longitude = lon
		last_accuracy_m = accuracy
		last_timestamp = int(Time.get_unix_time_from_system())
		permission_status_changed.emit(current_status)
		location_acquired.emit(last_latitude, last_longitude, last_accuracy_m, last_timestamp)
	else:
		current_status = PermissionStatus.DENIED
		permission_status_changed.emit(current_status)
		permission_denied.emit("Location access was declined by user. Manual search is fully supported.")

func get_last_known_position() -> Dictionary:
	if current_status != PermissionStatus.GRANTED:
		return {}
	return {
		"lat": last_latitude,
		"lon": last_longitude,
		"accuracy_m": last_accuracy_m,
		"timestamp": last_timestamp
	}

func clear_location_data() -> void:
	last_latitude = 0.0
	last_longitude = 0.0
	last_accuracy_m = 0.0
	last_timestamp = 0
	current_status = PermissionStatus.NOT_REQUESTED
	permission_status_changed.emit(current_status)
