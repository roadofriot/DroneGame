class_name DroneSpec
extends Resource

## DroneSpec: Single source of truth for Drone visual configuration & physical dynamics.
## Defines dimensional geometry, mass distribution, motor propulsion, battery capacity,
## and procedural styling. Dynamically computes moment arm, inertia tensor, hover thrust,
## and thrust-to-weight ratio for FlightController.

@export_group("Identity")
@export var name: String = "Quadcopter"
@export var description: String = "Standard 5-inch X-Quad simulation model"
@export var preset_id: String = "scout"

@export_group("Dimensions & Mass")
@export var mass: float = 1.25 # Total all-up weight in kilograms
@export var arm_length: float = 0.22 # Center to motor distance in meters
@export var body_size: Vector3 = Vector3(0.14, 0.045, 0.22) # Width (X), Height (Y), Length (Z) in meters
@export var prop_diameter: float = 0.127 # 5-inch prop in meters (0.127m)

@export_group("Propulsion & Power")
@export var max_motor_thrust: float = 7.0 # Newtons per motor (4 * 7.0 = 28.0 N)
@export var battery_wh: float = 56.24 # 3800 mAh @ 14.8V = ~56.2 Wh
@export var has_camera_pod: bool = true
@export var motor_tau: float = 0.04 # Electrical/mechanical lag time constant (s)
@export var yaw_torque_ratio: float = 0.016 # Yaw reaction torque to thrust ratio

@export_group("Colors & Styling")
@export var body_color: Color = Color(0.12, 0.13, 0.15, 1.0) # Carbon dark
@export var front_accent_color: Color = Color(0.95, 0.35, 0.05, 1.0) # High-visibility orange
@export var rear_color: Color = Color(0.18, 0.20, 0.24, 1.0) # Matte slate
@export var prop_color: Color = Color(0.85, 0.85, 0.88, 0.9)
@export var led_front_color: Color = Color(1.0, 1.0, 1.0, 1.0) # White headlights
@export var led_port_color: Color = Color(0.9, 0.1, 0.1, 1.0) # Red port (rear-left)
@export var led_starboard_color: Color = Color(0.1, 0.9, 0.2, 1.0) # Green starboard (rear-right)

## Derived moment arm X and Z offset in meters (symmetric X-quad geometry: arm_length / sqrt(2))
var arm_d: float:
	get:
		return arm_length * 0.70710678

## Derived hover thrust per motor in Newtons: (mass * 9.81) / 4.0
var hover_thrust_per_motor: float:
	get:
		return (mass * 9.81) / 4.0

## Derived Total Hover Thrust in Newtons
var total_hover_thrust: float:
	get:
		return mass * 9.81

## Derived Thrust-to-Weight Ratio (TWR)
var twr: float:
	get:
		return (max_motor_thrust * 4.0) / (mass * 9.81)

## Dynamically calculated 3-axis principal moments of inertia (kg * m^2)
## Models the drone as a rectangular body box + 4 lumped motor masses at arm tips.
var inertia: Vector3:
	get:
		var d = arm_d
		var m_body = mass * 0.68 # 68% mass in central electronics and battery
		var m_single_motor = (mass * 0.32) / 4.0 # 8% per arm motor assembly

		# Box body moments of inertia: I = (1/12) * m * (dim1^2 + dim2^2)
		var i_xx_body = (1.0 / 12.0) * m_body * (body_size.y * body_size.y + body_size.z * body_size.z)
		var i_yy_body = (1.0 / 12.0) * m_body * (body_size.x * body_size.x + body_size.z * body_size.z)
		var i_zz_body = (1.0 / 12.0) * m_body * (body_size.x * body_size.x + body_size.y * body_size.y)

		# 4 Point masses at (+/- d, 0, +/- d):
		# Pitch (X-axis): distance to X-axis is z = +/- d -> 4 * m * d^2
		# Roll (Z-axis): distance to Z-axis is x = +/- d -> 4 * m * d^2
		# Yaw (Y-axis): distance to Y-axis is sqrt(x^2 + z^2) -> 4 * m * (2 * d^2)
		var i_xx_motors = 4.0 * m_single_motor * (d * d)
		var i_zz_motors = 4.0 * m_single_motor * (d * d)
		var i_yy_motors = 4.0 * m_single_motor * (2.0 * d * d)

		return Vector3(
			i_xx_body + i_xx_motors,
			i_yy_body + i_yy_motors,
			i_zz_body + i_zz_motors
		)

## Export physical parameter dictionary compatible with FlightController.configure()
func get_physical_dict() -> Dictionary:
	var inert = inertia
	return {
		"mass_kg": mass,
		"arm_d": arm_d,
		"arm_length_m": arm_length,
		"max_total_thrust_n": max_motor_thrust * 4.0,
		"max_motor_thrust_n": max_motor_thrust,
		"yaw_k": yaw_torque_ratio,
		"motor_tau": motor_tau,
		"inertia": [inert.x, inert.y, inert.z]
	}
