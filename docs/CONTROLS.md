# Drone Flight Controls Guide

## Architecture: Unified Input Pipeline (Phase 2)

All control inputs (Hardware Gamepad, Keyboard, and Virtual Touch Joysticks) are routed through a single unified pipeline in `InputRouter.gd` and normalized into a single `ControlFrame` RefCounted object:
- **`throttle`**: `[-1.0, 1.0]` (Negative = Descend, Positive = Climb)
- **`yaw`**: `[-1.0, 1.0]` (Negative = Yaw Left, Positive = Yaw Right)
- **`pitch`**: `[-1.0, 1.0]` (Negative = Pitch Down / Backward, Positive = Pitch Up / Forward)
- **`roll`**: `[-1.0, 1.0]` (Negative = Bank Left, Positive = Bank Right)

### Radial Deadzone & Cubic Expo
- **Radial Deadzone (`0.12`)**: Applied using 2D vector length (`v.length() < 0.12 -> (0, 0)`), preventing stick drift while preserving full circular deflection and remapping `[0.12, 1.0]` continuously to `[0.0, 1.0]`.
- **Cubic Expo (`0.35`)**: Applied to yaw, pitch, and roll axes using `y = (1 - expo) * x + expo * x³`. Provides micro-control precision near stick center while preserving peak angular responsiveness at stick limits.

### Keyboard Ramping Filter
- Keyboard digital inputs (`0` or `1`) are softened using physical attack and release rates:
  - **Attack Rate**: `3.333/s` (~0.3 seconds to reach 100% full deflection).
  - **Release Rate**: `6.0/s` (~0.16 seconds to snap back to neutral center).
- Gamepad and Virtual Touch Joysticks bypass the ramp filter, providing direct 1:1 analog response.

### 4-Way Directional Stunt Flip
- Stunt flips triggered by `stunt_flip` evaluate the instantaneous right stick deflection (Pitch / Roll) and snap to the dominant cardinal direction:
  - **Front Flip**: Pitch Up (`Vector2(0, 1)`)
  - **Back Flip**: Pitch Down / Neutral (`Vector2(0, -1)`)
  - **Left Roll**: Roll Left (`Vector2(-1, 0)`)
  - **Right Roll**: Roll Right (`Vector2(1, 0)`)

---

## Flight Profiles
1. **Cinematic (CINE):** Max tilt 14°, climb/descent rate capped, heavy dampening for film-grade camera movements.
2. **Normal:** Default flight mode with auto-leveling, altitude hold, max tilt 28°, balanced for exploration.
3. **Sport:** Increased agility and speed (max tilt 52°, yaw 220°/s), steep banking for racing maneuvers.
4. **Arcade:** Forgiving assisted flight with stunt maneuvers enabled.
5. **Acro:** Rate-mode manual flight with zero auto-leveling for freestyle aerobatics and inverted flight.

---

## Controls Reference Table

| Action | Keyboard | USB Gamepad | Virtual Touch HUD |
| :--- | :--- | :--- | :--- |
| **Throttle Up / Down** | `W` / `S` | Left Stick Vertical | Left Joystick Y-Axis |
| **Yaw Left / Right** | `A` / `D` | Left Stick Horizontal | Left Joystick X-Axis |
| **Pitch Forward / Backward**| `Up` / `Down` (or `I`/`K`) | Right Stick Vertical | Right Joystick Y-Axis |
| **Roll Left / Right** | `Left` / `Right` (or `J`/`L`) | Right Stick Horizontal | Right Joystick X-Axis |
| **Stunt Flip (4-Way)** | `F` + Direction | Right Shoulder (RB) + Stick | `FLIP` Button + Stick |
| **Takeoff / Land** | `Space` / `T` | Button A (South) | `TAKEOFF` / `LAND` Button |
| **Active Brake / Damp** | `B` (Hold) | Left Shoulder (LB) | `BRAKE` Button |
| **Pilot Boost (x1.4 / 2x Wh)**| `Shift` (Hold) | Left Stick Click (L3) | HUD Boost Trigger |
| **Headless Mode Toggle** | `U` | D-Pad Left | HUD Headless Toggle |
| **Pitch Trim Adjust** | `[` / `]` | D-Pad Up / Down (+Back) | HUD Trim Controls |
| **Roll Trim Adjust** | `;` / `'` | D-Pad Left / Right (+Back)| HUD Trim Controls |
| **Camera Gimbal Tilt** | `PageUp` / `PageDown` | Left Trigger / Right Stick Y | HUD Gimbal Slider |
| **Switch Camera Mode** | `C` | Button X (West) | `CAM` Button |
| **Cycle Flight Mode** | `M` | D-Pad Up | `MODE` Button |
| **Return to Home (RTH)** | `H` (Hold) | D-Pad Down | `RTH` Button |
| **Emergency Motor Cut** | `Backspace` / `X` (0.7s)| Button Back/Select (0.7s) | `E-STOP` Button |
| **Reset to Launch Pad** | `R` | Button Y (North) | `RESET` Button |

---

## Telemetry Readouts
- **ALT:** Altitude Above Ground Level (AGL) via ground-tracking raycast.
- **SPD:** Horizontal ground speed (m/s).
- **V/S:** Vertical speed / climb rate (+ upward, - downward).
- **HDG:** Compass heading in degrees with 8-point cardinal abbreviation.
- **BAT:** Simulated 4S LiPo battery (15.2V nominal, 3800 mAh capacity) with dynamic load drain.
