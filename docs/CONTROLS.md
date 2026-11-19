# Drone Flight Controls & Pilot Manual

## Architecture: Unified Input Pipeline (Phase 2 & Phase 10)

All control inputs (Hardware USB Gamepads, Physical Keyboard, and Virtual Touch Joysticks) are routed through a single unified pipeline in `InputRouter.gd` and normalized into a single `ControlFrame` RefCounted object:
- **`throttle`**: `[-1.0, 1.0]` (Negative = Descend, Positive = Climb)
- **`yaw`**: `[-1.0, 1.0]` (Negative = Yaw Left, Positive = Yaw Right)
- **`pitch`**: `[-1.0, 1.0]` (Negative = Pitch Down / Backward, Positive = Pitch Up / Forward)
- **`roll`**: `[-1.0, 1.0]` (Negative = Bank Left, Positive = Bank Right)

### Radial Deadzone & Cubic Expo
- **Radial Deadzone (`0.12`)**: Applied using 2D vector length (`v.length() < 0.12 -> (0, 0)`), preventing stick drift while preserving full circular deflection and remapping `[0.12, 1.0]` continuously to `[0.0, 1.0]`. Adjustable in Settings from `0.0` to `0.30`.
- **Cubic Expo (`0.35`)**: Applied to yaw, pitch, and roll axes using $y = (1 - \text{expo}) \cdot x + \text{expo} \cdot x^3$. Provides micro-control precision near stick center while preserving peak angular responsiveness at stick limits. Adjustable in Settings from `0.0` (linear) to `0.80`.

### Keyboard Ramping Filter
- Keyboard digital inputs (`0` or `1`) are softened using physical attack and release rates:
  - **Attack Rate**: `3.333/s` (~0.3 seconds to reach 100% full deflection).
  - **Release Rate**: `6.0/s` (~0.16 seconds to snap back to neutral center).
- Gamepad and Virtual Touch Joysticks bypass the ramp filter, providing direct 1:1 analog response.

### 4-Way Directional Stunt Flip
- Stunt flips triggered by `stunt_flip` (`F` / Gamepad `RB` or `B`) evaluate the instantaneous right stick deflection (Pitch / Roll) and snap to the dominant cardinal direction:
  - **Front Flip**: Pitch Up (`Vector2(0, 1)`) — negative X axis rotation.
  - **Back Flip**: Pitch Down / Neutral (`Vector2(0, -1)`) — positive X axis rotation.
  - **Left Roll**: Roll Left (`Vector2(-1, 0)`) — positive Z axis rotation.
  - **Right Roll**: Roll Right (`Vector2(1, 0)`) — negative Z axis rotation.
- Inverted thrust is automatically cut to $0.0\times$ during the rotation phase to prevent downward ground acceleration. Requires minimum 4.0m AGL and 20% battery.

---

## Flight Modes & Profiles

### Flight Modes (`FlightModeManager.gd`)
1. **ANGLE (Mode 1)**: Self-leveling mode with tilt clamped to profile maximum. Ideal for beginner pilots and aerial photography.
2. **HORIZON (Mode 2)**: Hybrid assisted mode with a 70% deflection deadband. Auto-levels near center; transitions to continuous rate flips at extreme stick deflection.
3. **ACRO (Mode 3)**: Pure gyroscopic angular rate mode ($^\circ/\text{s}$). Zero auto-leveling. Full manual control for FPV freestyle and inverted flight.

### Flight Profiles (`drone_profiles.json`)
- **Cinematic (CINE):** Max tilt 14°, climb/descent rate capped, heavy dampening for film-grade camera movements.
- **Normal:** Default flight mode with auto-leveling, altitude hold, max tilt 28°, balanced for exploration.
- **Sport:** Increased agility and speed (max tilt 52°, yaw 260°/s), steep banking for racing maneuvers.
- **Arcade:** Forgiving assisted flight with stunt maneuvers enabled.
- **Acro:** Direct rate mode (400°/s) with zero auto-leveling for freestyle aerobatics.

---

## Comprehensive Controls Reference

| Action | Keyboard | USB Gamepad | Virtual Touch HUD |
| :--- | :--- | :--- | :--- |
| **Throttle Up / Down** | `W` / `S` | Left Stick Vertical | Left Joystick Y-Axis |
| **Yaw Left / Right** | `A` / `D` | Left Stick Horizontal | Left Joystick X-Axis |
| **Pitch Forward / Backward**| `Up` / `Down` (or `I`/`K`) | Right Stick Vertical | Right Joystick Y-Axis |
| **Roll Left / Right** | `Left` / `Right` (or `J`/`L`) | Right Stick Horizontal | Right Joystick X-Axis |
| **Stunt Flip (4-Way)** | `F` + Direction | Button B / East + Stick | `FLIP (F)` Button + Stick |
| **Takeoff / Land / Recover**| `Space` / `T` | Button A (South) | `TAKEOFF` / `LAND` Button |
| **Active Brake / Damp** | `B` (Hold) | Left Shoulder (LB) | `BRAKE` Button |
| **Pilot Boost (x1.4 Thrust)**| `Shift` (Hold) | Left Stick Click (L3) | HUD Boost Indicator |
| **Headless Mode Toggle** | `U` | D-Pad Left | HUD Headless Toggle |
| **Pitch Trim Adjust** | `[` / `]` | D-Pad Up / Down (+Back) | HUD Trim Controls |
| **Roll Trim Adjust** | `;` / `'` | D-Pad Left / Right (+Back)| HUD Trim Controls |
| **Trim Reset** | `Ctrl` + `T` | D-Pad Click (+Back) | HUD Trim Reset Button |
| **Camera Gimbal Tilt** | `PageUp` / `PageDown` | Left Trigger / Right Stick Y | HUD Gimbal Slider |
| **Switch Camera Mode** | `C` | Button X (West) | `CAM (C)` Button |
| **Cycle Flight Profile** | `M` | Right Bumper | `MODE (M)` Button |
| **Return to Home (RTH)** | `H` (Hold) | D-Pad Down | `RTH` Button |
| **Pause / Settings Menu** | `Escape` | Button Start | HUD Pause Button |
| **Emergency Motor Cut** | `Backspace` / `X` (0.7s)| Button Back/Select (0.7s) | `E-STOP` Button |
| **Reset to Launch Pad** | `R` | Button Y (North) | `RESET (R)` Button |

---

## Pause Menu, Settings & Rebinding

Pressing `Escape` or Gamepad `Start` opens the in-game Settings and Pause Menu:

1. **Input Calibration**:
   - **Expo Sliders:** Adjust cubic expo independently for Pitch/Roll and Yaw (`0.0` linear to `0.8` exponential).
   - **Deadzone Sliders:** Calibrate stick center deadzone from `0.02` to `0.30` to eliminate drift on worn analog hardware.
   - **Axis Inversion:** Toggle Pitch Invert (Flight Simulator style vs FPS style).
2. **Display & Units**:
   - **Unit System:** Toggle between **Metric** ($m/s$, meters AGL) and **Imperial** ($mph$, feet AGL).
   - **Camera Field of View (FOV):** Adjustable from $60^\circ$ (cinematic compression) to $105^\circ$ (wide-angle FPV feel).
3. **Action Rebinding & Conflict Detection**:
   - Pilot action bindings can be remapped directly in the menu.
   - Built-in conflict detection highlights duplicate keys in yellow/red to prevent ambiguous control states.
   - Settings are automatically persisted across sessions via `user://settings.json`.

---

## Telemetry Readouts

- **ALT:** Altitude Above Ground Level (AGL) via high-speed physics raycast queries (or Mean Sea Level via toggle).
- **SPD:** Horizontal ground velocity in $m/s$ (or $mph$ in imperial mode).
- **V/S:** Vertical rate of climb/descent indicator ($+m/s$ climb, $-m/s$ descent).
- **HDG:** 0°–360° heading tape with 8 cardinal indicators (`N`, `NE`, `E`, `SE`, `S`, `SW`, `W`, `NW`).
- **BAT:** Simulated 4S LiPo battery (15.2V nominal) with real-time watt-hour consumption and low-voltage alerts.
- **RTH Pointer:** Vector directional arrow continuously tracking bearing and distance back to home pad.
