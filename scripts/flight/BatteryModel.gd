class_name BatteryModel
extends RefCounted

## BatteryModel: High-Fidelity Watt-Hour Energy Drain & Failsafe Controller (Phase 7).
## Calculates continuous energy consumption based on motor thrust, idle electronics,
## and pilot boost mode. Emits safety warning, auto-RTH, and forced landing triggers.
## ZERO scene-tree/node access.

# Battery Capacity in Watt-Hours (default: 4S 3800mAh @ 14.8V = 56.24 Wh)
var capacity_wh: float = 56.24
var remaining_wh: float = 56.24

# Base quiescent avionics load (Watts)
var base_avionics_power_w: float = 6.5
# Specific power consumption per Newton of motor thrust (Watts / Newton)
var thrust_power_gain_w_per_n: float = 18.0

# Nominal nominal and min/max voltages
var nominal_voltage_v: float = 14.8
var min_cell_v: float = 3.3
var max_cell_v: float = 4.2
var cell_count: int = 4

signal battery_warning_low(remaining_pct: float)
signal auto_rth_triggered()
signal forced_landing_triggered()

# Failsafe one-shot flags
var _warn_25_fired: bool = false
var _rth_15_fired: bool = false
var _land_5_fired: bool = false

func _init(initial_capacity_wh: float = 56.24) -> void:
	capacity_wh = maxf(1.0, initial_capacity_wh)
	remaining_wh = capacity_wh

func reset() -> void:
	remaining_wh = capacity_wh
	_warn_25_fired = false
	_rth_15_fired = false
	_land_5_fired = false

func get_battery_percent() -> float:
	return clampf((remaining_wh / capacity_wh) * 100.0, 0.0, 100.0)

func get_battery_voltage() -> float:
	var pct = get_battery_percent() / 100.0
	var cell_v = min_cell_v + (max_cell_v - min_cell_v) * pct
	return cell_v * float(cell_count)

func is_flip_allowed() -> bool:
	return get_battery_percent() >= 20.0

## Advances battery drain over timestep delta.
## - total_thrust_n: Sum of 4 motor thrusts (Newtons)
## - is_boost: True if pilot is holding Boost (doubles drain)
## - delta: Timestep in seconds
## Returns Dictionary with current telemetry and failsafe status.
func step(total_thrust_n: float, is_boost: bool, delta: float) -> Dictionary:
	var p_thrust = total_thrust_n * thrust_power_gain_w_per_n
	var p_total = base_avionics_power_w + p_thrust

	if is_boost:
		p_total *= 2.0 # Pilot boost mode doubles power consumption

	# Energy consumed in Watt-Hours: P (W) * (t (s) / 3600.0)
	var wh_drain = p_total * (delta / 3600.0)
	remaining_wh = maxf(0.0, remaining_wh - wh_drain)

	var pct = get_battery_percent()

	var trigger_warn = false
	var trigger_rth = false
	var trigger_land = false

	# Threshold Failsafes:
	if pct <= 25.0 and not _warn_25_fired:
		_warn_25_fired = true
		trigger_warn = true
		battery_warning_low.emit(pct)

	if pct <= 15.0 and not _rth_15_fired:
		_rth_15_fired = true
		trigger_rth = true
		auto_rth_triggered.emit()

	if pct <= 5.0 and not _land_5_fired:
		_land_5_fired = true
		trigger_land = true
		forced_landing_triggered.emit()

	return {
		"remaining_wh": remaining_wh,
		"battery_pct": pct,
		"voltage_v": get_battery_voltage(),
		"current_power_w": p_total,
		"est_time_remaining_s": get_estimated_time_remaining_seconds(p_total),
		"flip_allowed": is_flip_allowed(),
		"warn_low": trigger_warn,
		"auto_rth": trigger_rth,
		"force_land": trigger_land
	}

func get_estimated_time_remaining_seconds(current_w: float = 0.0) -> float:
	var p = current_w if current_w > 10.0 else (base_avionics_power_w + 120.0)
	return (remaining_wh / p) * 3600.0

