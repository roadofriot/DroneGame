# Drone Flight Controls Guide

## Flight Profiles
1. **Cinematic (CINE):** Max tilt 14°, climb/descent rate capped, heavy dampening for film-grade camera movements.
2. **Normal:** Default flight mode with auto-leveling, altitude hold, max tilt 28°, balanced for exploration.
3. **Sport:** Increased agility and speed (max tilt 52°, yaw 220°/s), steep banking for racing maneuvers.
4. **Arcade:** Forgiving assisted flight with stunt maneuvers enabled.
5. **Acro:** Rate-mode manual flight with zero auto-leveling for freestyle aerobatics and inverted flight.

## Input Axis Mapping

### Mode 2 (Default Industry Mapping)
- **Left Stick Vertical:** Throttle (Climb / Descend)
- **Left Stick Horizontal:** Yaw (Rotate heading left / right)
- **Right Stick Vertical:** Pitch (Tilt nose down / up)
- **Right Stick Horizontal:** Roll (Bank left / right)

### Telemetry Readouts
- **ALT:** Altitude Above Ground Level (AGL) via ground-tracking raycast.
- **SPD:** Horizontal ground speed (m/s).
- **V/S:** Vertical speed / climb rate (+ upward, - downward).
- **HDG:** Compass heading in degrees with 8-point cardinal abbreviation.
- **BAT:** Simulated 4S LiPo battery (15.2V nominal, 3800 mAh capacity) with dynamic load drain.
