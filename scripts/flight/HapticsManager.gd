class_name HapticsManager
extends RefCounted

## HapticsManager: Gamepad Vibration & Haptic Feedback Controller (Phase 7).
## Triggers physical rumble effects on supported gamepads for collisions, flips,
## and low-battery warnings.

enum Effect {
	COLLISION,
	FLIP_COMPLETED,
	BATTERY_LOW,
	TOUCHDOWN
}

static func play_haptic(effect: Effect, device_id: int = 0) -> void:
	if not Input.get_connected_joypads().has(device_id):
		return

	match effect:
		Effect.COLLISION:
			# Strong dual-motor impact pulse
			Input.start_joy_vibration(device_id, 0.8, 0.9, 0.35)
		Effect.FLIP_COMPLETED:
			# Quick crisp burst
			Input.start_joy_vibration(device_id, 0.35, 0.6, 0.15)
		Effect.BATTERY_LOW:
			# Subtle pulsing alert
			Input.start_joy_vibration(device_id, 0.5, 0.15, 0.25)
		Effect.TOUCHDOWN:
			# Gentle thud
			Input.start_joy_vibration(device_id, 0.2, 0.3, 0.12)

static func stop(device_id: int = 0) -> void:
	Input.stop_joy_vibration(device_id)
