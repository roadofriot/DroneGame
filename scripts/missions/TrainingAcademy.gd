class_name TrainingAcademy
extends Node

## TrainingAcademy: Guided flight instruction curriculum.
## Evaluates real-time telemetry against pedagogical objectives across 5 core lessons:
## Takeoff/Hover, Yaw Heading, Pitch/Roll Braking, Gate Precision, and Helipad Landing.

signal academy_started
signal lesson_started(lesson_id: String, lesson_title: String)
signal step_updated(instruction: String, current_step: int, total_steps: int)
signal lesson_completed(lesson_id: String, medal: String, score: int, rewards: Dictionary)
signal lesson_failed(lesson_id: String, reason: String)
signal lesson_step_advanced(new_step_index: int)

@export var target_drone: FlightPhysics

var progression_service: ProgressionService
var lessons_catalogue: Array = []
var active_lesson: Dictionary = {}
var active_lesson_id: String = ""
var active_step_index: int = 0
var lesson_elapsed_time: float = 0.0
var is_active: bool = false

# Step monitoring variables
var step_timer: float = 0.0
var initial_heading: float = 0.0
var speed_milestone_hit: bool = false
var spawn_pad_position: Vector3 = Vector3.ZERO
var passed_gate_count: int = 0

func _init() -> void:
	if not progression_service:
		progression_service = ProgressionService.new()
	load_lessons()

func _ready() -> void:
	if not progression_service:
		progression_service = ProgressionService.new()
	if lessons_catalogue.is_empty():
		load_lessons()

func load_lessons(file_path: String = "res://data/missions/lessons.json") -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("TrainingAcademy: Could not open %s" % file_path)
		return false

	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		if data is Dictionary and data.has("lessons"):
			lessons_catalogue = data["lessons"]
			return true
	return false

func get_lesson_def(lesson_id: String) -> Dictionary:
	for l in lessons_catalogue:
		if l.get("id") == lesson_id:
			return l
	return {}

func start_lesson(lesson_id: String) -> bool:
	var lesson = get_lesson_def(lesson_id)
	if lesson.is_empty():
		push_error("TrainingAcademy: Unknown lesson_id '%s'" % lesson_id)
		return false

	active_lesson = lesson
	active_lesson_id = lesson_id
	active_step_index = 0
	lesson_elapsed_time = 0.0
	step_timer = 0.0
	speed_milestone_hit = false
	passed_gate_count = 0
	is_active = true

	if target_drone:
		spawn_pad_position = target_drone.global_position if target_drone.is_inside_tree() else target_drone.position
		initial_heading = target_drone.heading_deg

	academy_started.emit()
	lesson_started.emit(lesson_id, active_lesson.get("title", "Lesson"))

	_broadcast_current_step()
	return true

func abort_lesson(reason: String) -> void:
	if not is_active:
		return
	is_active = false
	lesson_failed.emit(active_lesson_id, reason)

func on_gate_passed(_gate_index: int) -> void:
	if not is_active:
		return
	passed_gate_count += 1
	var steps: Array = active_lesson.get("steps", [])
	if active_step_index < steps.size():
		var cur_step: Dictionary = steps[active_step_index]
		if cur_step.get("type") == "pass_gate":
			advance_step()

func advance_step() -> void:
	var steps: Array = active_lesson.get("steps", [])
	active_step_index += 1
	step_timer = 0.0

	if target_drone:
		initial_heading = target_drone.heading_deg

	lesson_step_advanced.emit(active_step_index)

	if active_step_index >= steps.size():
		_complete_active_lesson()
	else:
		_broadcast_current_step()

func _broadcast_current_step() -> void:
	var steps: Array = active_lesson.get("steps", [])
	if active_step_index < steps.size():
		var step: Dictionary = steps[active_step_index]
		var instruction = step.get("instruction", "")
		step_updated.emit(instruction, active_step_index + 1, steps.size())

func _physics_process(delta: float) -> void:
	if not is_active or target_drone == null:
		return

	lesson_elapsed_time += delta

	# Fail check: crash
	if target_drone.current_state == FlightPhysics.DroneState.CRASHED:
		abort_lesson("Drone crashed")
		return

	var steps: Array = active_lesson.get("steps", [])
	if active_step_index >= steps.size():
		return

	var step: Dictionary = steps[active_step_index]
	var stype: String = step.get("type", "")

	match stype:
		"takeoff":
			if target_drone.current_state == FlightPhysics.DroneState.FLYING and target_drone.altitude_agl >= 1.2:
				advance_step()

		"reach_altitude":
			var min_alt = step.get("target_altitude_min", 1.8)
			var max_alt = step.get("target_altitude_max", 3.0)
			if target_drone.altitude_agl >= min_alt and target_drone.altitude_agl <= max_alt:
				advance_step()

		"maintain_hover":
			var min_alt = step.get("target_altitude_min", 1.5)
			var max_alt = step.get("target_altitude_max", 2.7)
			var max_speed = step.get("max_drift_speed", 1.2)
			var duration = step.get("duration_required", 3.0)

			if target_drone.altitude_agl >= min_alt and target_drone.altitude_agl <= max_alt and target_drone.ground_speed <= max_speed:
				step_timer += delta
				if step_timer >= duration:
					advance_step()
			else:
				step_timer = maxf(0.0, step_timer - (delta * 0.5))

		"yaw_rotation":
			var target_deg = step.get("target_angle_deg", 90.0)
			var tolerance = step.get("tolerance_deg", 18.0)
			var heading_delta = fposmod(target_drone.heading_deg - initial_heading, 360.0)
			if heading_delta > 180.0:
				heading_delta -= 360.0
			if absf(heading_delta - target_deg) <= tolerance:
				advance_step()

		"hold_heading":
			var duration = step.get("duration_required", 1.5)
			if absf(target_drone.angular_velocity.y) < 0.35:
				step_timer += delta
				if step_timer >= duration:
					advance_step()
			else:
				step_timer = 0.0

		"return_heading":
			var tolerance = step.get("tolerance_deg", 20.0)
			var heading_delta = fposmod(target_drone.heading_deg - initial_heading, 360.0)
			if heading_delta > 180.0:
				heading_delta -= 360.0
			if absf(heading_delta) <= tolerance:
				advance_step()

		"accelerate_forward":
			var target_speed = step.get("target_speed", 4.0)
			if target_drone.ground_speed >= target_speed:
				advance_step()

		"active_brake":
			var max_spd = step.get("max_speed", 0.6)
			var duration = step.get("duration_required", 1.0)
			if target_drone.ground_speed <= max_spd and target_drone.altitude_agl > 1.0:
				step_timer += delta
				if step_timer >= duration:
					advance_step()
			else:
				step_timer = 0.0

		"align_helipad":
			var max_r = step.get("max_radius", 3.5)
			var cur_pos = target_drone.global_position if target_drone.is_inside_tree() else target_drone.position
			var horizontal_dist = Vector2(cur_pos.x - spawn_pad_position.x, cur_pos.z - spawn_pad_position.z).length()
			if horizontal_dist <= max_r:
				advance_step()

		"gentle_descent":
			var max_desc = step.get("max_descent_speed", 1.0)
			var max_tilt = step.get("max_tilt_deg", 15.0)
			var cur_tilt = maxf(absf(target_drone.pitch_deg), absf(target_drone.roll_deg))
			if target_drone.climb_rate <= -0.1 and absf(target_drone.climb_rate) <= max_desc and cur_tilt <= max_tilt:
				if target_drone.altitude_agl <= 0.4:
					advance_step()

		"touchdown":
			if target_drone.current_state == FlightPhysics.DroneState.DISARMED or (target_drone.altitude_agl <= 0.15 and absf(target_drone.climb_rate) <= 0.3):
				advance_step()

func _complete_active_lesson() -> void:
	is_active = false

	var medal_times = active_lesson.get("medal_times", {"gold": 10.0, "silver": 18.0, "bronze": 30.0})
	var medal = "BRONZE"
	var score = 600

	if lesson_elapsed_time <= medal_times.get("gold", 10.0):
		medal = "GOLD"
		score = 1500
	elif lesson_elapsed_time <= medal_times.get("silver", 18.0):
		medal = "SILVER"
		score = 1000

	var rewards: Dictionary = active_lesson.get("rewards", {"xp": 100, "coins": 50})

	# Register progression reward idempotently
	if progression_service:
		var run_hash = "academy_%s_%d" % [active_lesson_id, int(lesson_elapsed_time * 10)]
		if not progression_service.is_run_already_claimed(run_hash):
			progression_service.claimed_run_hashes.append(run_hash)
			progression_service.add_xp(rewards.get("xp", 100))
			progression_service.add_coins(rewards.get("coins", 50))
			progression_service.save_data()

	lesson_completed.emit(active_lesson_id, medal, score, rewards)
