class_name FlightStateMachine
extends RefCounted

## FlightStateMachine: Pure-logic, robust state machine for Drone Flight Dynamics.
## States: DISARMED, TAKEOFF, FLYING, LANDING, FLIPPING, CRASHED.
## Handles spin-up, climb to 1.5m AGL, controlled landing touchdown, tilt safety,
## and emergency stop with zero-latency disarm.

signal state_changed(new_state: State, old_state: State)
signal state_name_changed(state_name: String)
signal armed_changed(is_armed: bool)
signal takeoff_completed
signal landing_completed
signal crash_detected(reason: String)

enum State {
	DISARMED,
	TAKEOFF,
	FLYING,
	LANDING,
	FLIPPING,
	CRASHED
}

const STATE_NAMES: Dictionary = {
	State.DISARMED: "DISARMED",
	State.TAKEOFF: "TAKEOFF",
	State.FLYING: "FLYING",
	State.LANDING: "LANDING",
	State.FLIPPING: "FLIPPING",
	State.CRASHED: "CRASHED"
}

# State & Configuration
var state: State = State.DISARMED
var is_armed: bool = false
var state_timer: float = 0.0

# Takeoff & Landing Settings
var takeoff_target_agl: float = 1.5 # 1.5m climb clearance
var takeoff_spinup_time: float = 0.5 # 0.5s motor spool on ground
var landing_descent_rate: float = 0.8 # 0.8 m/s controlled descent
var landing_touchdown_agl: float = 0.15 # < 0.15m ground contact detection
var landing_touchdown_speed: float = 0.2 # < 0.2 m/s linear velocity

# Safety & Crash Detection Settings
var tilt_crash_threshold_deg: float = 100.0 # > 100° inversion
var tilt_crash_time_sec: float = 0.5 # 0.5s sustained inversion
var tilt_crash_max_agl: float = 5.0 # Low-altitude guard (< 5.0m)
var impact_crash_threshold: float = 12.0 # Force threshold (N/kg)
var tilt_timer: float = 0.0

func _init() -> void:
	reset()

func reset() -> void:
	state = State.DISARMED
	is_armed = false
	state_timer = 0.0
	tilt_timer = 0.0

func get_state_name() -> String:
	return STATE_NAMES.get(state, "UNKNOWN")

func is_flying() -> bool:
	return state == State.FLYING or state == State.FLIPPING

func is_airborne() -> bool:
	return state == State.TAKEOFF or state == State.FLYING or state == State.LANDING or state == State.FLIPPING

func is_crashed() -> bool:
	return state == State.CRASHED

## Execute explicit state transition with safety validation
func transition_to(target_state: State, reason: String = "") -> bool:
	if state == target_state:
		return true

	# Guard against illegal transitions out of CRASHED without pad reset
	if state == State.CRASHED and target_state != State.DISARMED:
		return false

	var old_state = state
	state = target_state
	state_timer = 0.0
	tilt_timer = 0.0

	# Update Armed flag
	var new_armed = (state != State.DISARMED and state != State.CRASHED)
	if new_armed != is_armed:
		is_armed = new_armed
		armed_changed.emit(is_armed)

	state_changed.emit(state, old_state)
	state_name_changed.emit(get_state_name())

	if state == State.TAKEOFF:
		pass
	elif state == State.FLYING and old_state == State.TAKEOFF:
		takeoff_completed.emit()
	elif state == State.DISARMED and old_state == State.LANDING:
		landing_completed.emit()
	elif state == State.CRASHED:
		crash_detected.emit(reason if not reason.is_empty() else "CRASH")

	return true

## Handle takeoff_land action:
## - DISARMED -> TAKEOFF (if grounded & battery sufficient)
## - FLYING -> LANDING
## - LANDING -> FLYING (aborts landing and resumes normal flight)
func handle_takeoff_land(battery_percent: float = 100.0, is_grounded: bool = true) -> bool:
	match state:
		State.DISARMED:
			if battery_percent < 5.0:
				return false
			if not is_grounded:
				return false
			return transition_to(State.TAKEOFF, "TAKEOFF_REQUESTED")

		State.FLYING:
			return transition_to(State.LANDING, "LAND_REQUESTED")

		State.LANDING:
			# Abort landing and resume manual flying
			return transition_to(State.FLYING, "LANDING_ABORTED")

		State.TAKEOFF:
			# If pressed during climb, switch directly to manual flying
			return transition_to(State.FLYING, "MANUAL_OVERRIDE")

		State.CRASHED:
			# Overloaded recover removed! Must use reset (R / Gamepad Y)
			return false

		_:
			return false

## Instant Emergency Stop disarm (called on deliberate hold)
func handle_emergency_stop() -> void:
	if state != State.DISARMED and state != State.CRASHED:
		transition_to(State.CRASHED, "EMERGENCY_STOP")

## Reset to Launch Pad
func handle_reset() -> void:
	transition_to(State.DISARMED, "RESET_TO_PAD")

## Per-physics-tick state update and condition evaluation
func update(delta: float, agl: float, speed: float, vert_speed: float, tilt_deg: float, impact_force: float = 0.0) -> void:
	state_timer += delta

	# Impact crash detection across all active airborne states
	if is_airborne() and impact_force >= impact_crash_threshold:
		transition_to(State.CRASHED, "COLLISION_IMPACT")
		return

	# Inversion crash detection (> 100° for > 0.5s at low altitude)
	if is_airborne() and state != State.FLIPPING and agl <= tilt_crash_max_agl:
		if tilt_deg >= tilt_crash_threshold_deg:
			tilt_timer += delta
			if tilt_timer >= tilt_crash_time_sec:
				transition_to(State.CRASHED, "INVERTED_CRASH")
				return
		else:
			tilt_timer = maxf(0.0, tilt_timer - delta * 2.0)
	else:
		tilt_timer = 0.0

	match state:
		State.TAKEOFF:
			# 0.5s motor spin-up on ground, then climb to 1.5m AGL
			if state_timer >= takeoff_spinup_time:
				if agl >= takeoff_target_agl - 0.10:
					transition_to(State.FLYING, "TAKEOFF_TARGET_REACHED")

		State.LANDING:
			# Touchdown detection: AGL < 0.15m and total speed < 0.2 m/s
			if agl <= landing_touchdown_agl and speed <= landing_touchdown_speed and abs(vert_speed) <= landing_touchdown_speed:
				transition_to(State.DISARMED, "TOUCHDOWN_CONFIRMED")
