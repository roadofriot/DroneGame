# MindSparQ Drone Simulator — v0.2.0 Release Notes

**Version:** 0.2.0 (Phase 10 Release)  
**Date:** 2026-11-19  
**Engine:** Godot Engine 4.3 Stable (`4.3.stable.official.77dcf97d8`)  
**Target Platforms:** Linux x86_64, Windows x86_64, macOS, Android (ARM64/x86_64), Web (HTML5/Wasm)  
**License:** MIT / CC0 (Original & Open Assets)  

---

## 1. Executive Summary

MindSparQ Drone Simulator **v0.2.0** represents a comprehensive overhaul of the quadcopter flight simulation engine. Moving from the initial prototype to a mathematically sound, modular, and scalable architecture, this release delivers:
- Pure-logic decoupled attitude control loops operating at deterministic 120 Hz.
- Aviation-grade vector flight instruments rendered natively without raster assets.
- Infinite procedural terrain streaming with floating-origin shifts supporting 20+ km flights.
- Complete multi-device input unification across Gamepad, Keyboard, and Touchscreen.
- 100% test coverage verified across 15 automated test suites and 110 acceptance test checks.

---

## 2. Major Features & Architecture Upgrades by Phase

### Phase 2: Unified Input Layer & ControlFrame
- **`ControlFrame.gd` Data Contract:** Normalized flight commands in `[-1.0, 1.0]` for throttle, yaw, pitch, and roll.
- **Radial Deadzones & Cubic Expo:** 2D circular vector deadzone (`0.12`) prevents stick drift without cutting diagonals. Cubic expo curves ($y = (1 - \text{expo})x + \text{expo} \cdot x^3$) allow precision hovering while preserving full rate authority at stick extremes.
- **Keyboard Attack/Release Ramping:** Physical rate-limited smoothing filter eliminates jarring digital step-inputs.
- **Multi-Touch Virtual Joysticks:** Dual independent floating joysticks with pointer tracking and zero stuck-touch bugs.

### Phase 3: Core Flight Logic & Decoupled PID
- **`FlightController.gd` (Pure-Logic RefCounted):** Fully decoupled from the SceneTree for mathematical purity and instant testability.
- **Heading Attitude P-Loop:** Calculates orientation error in the heading frame $\mathbf{e} = \text{body}^T (\mathbf{u} \times \mathbf{u}_{\text{desired}})$, driving gyroscopic rate targets.
- **Collective Altitude Hold:** Tilt-compensated collective thrust ensures zero altitude dip during pitch/roll transitions.
- **X-Quad Dynamic Mixer:** Equal-shifting desaturation prevents motor saturation clipping and preserves differential control authority under maximum throttle.

### Phase 4: State Machine & Flight Safety
- **`FlightStateMachine.gd`:** Formal 6-state machine (`DISARMED`, `TAKEOFF`, `FLYING`, `LANDING`, `FLIPPING`, `CRASHED`).
- **Preflight Sensor Checks:** Battery $\ge 5\%$, level surface, and ground contact validation prior to motor arming.
- **Automated Takeoff & Landing:** Smooth 0.5s motor spin-up to 1.5m AGL hover, and 0.8 m/s auto-braking touchdown descent.
- **Safety Failsafes:** Emergency motor cut (0.7s hold), tilt inversion protection (>100° sustained), collision impulse detection, and altitude/geofence boundaries.

### Phase 5: 4-Way Aerobatic Flip System
- **`FlipController.gd`:** Deterministic 3-phase stunt engine:
  1. `BOOST`: 0.12s vertical upward impulse at $1.6\times$ hover thrust.
  2. `ROTATE`: $720^\circ/\text{s}$ angular rate flip along the 4 cardinal axes with **instant inverted thrust cutoff ($0.0\times$)** when upside down.
  3. `RECOVER`: Smooth handoff back to auto-level attitude control with upright angle thresholding ($u_y > 0.90$).
- **Safety Envelopes:** Enforces minimum 4.0m AGL, 20% battery reserve, and non-acro profile validation.

### Phase 6: DroneSpec Resource Architecture & Procedural Frames
- **`DroneSpec.gd` Resource:** Single source of truth defining mass, wheelbase, propeller aerodynamics, motor KV, battery cells, drag coefficients, and inertia tensor estimations.
- **3 Authoritative Presets:**
  - `scout_spec.tres`: 0.85 kg, 220 mm wheelbase, 4S LiPo, balanced exploration craft.
  - `photo_spec.tres`: 1.45 kg, 330 mm wheelbase, 4S LiPo, 3-axis stabilized camera gimbal aerial photography rig.
  - `racer_spec.tres`: 0.55 kg, 180 mm wheelbase, 6S LiPo, high-voltage high-TWR (>3.5) aerobatic racing drone.
- **`DroneFrameGenerator.gd`:** Procedural CSG / ArrayMesh generator creating matte carbon-fiber unibody frames, motor bells, landing skids, and LED lenses without external 3D asset dependencies.

### Phase 7: Advanced Flight Control Systems
- **`FlightModeManager.gd`:** Seamless switching between ANGLE (auto-leveling), HORIZON (70% blend zone with auto-leveling near center and rate flips at full deflection), and ACRO (pure gyroscopic rate control).
- **`BrakeController.gd`:** Active horizontal velocity arrestor tilting against velocity vector until speed $< 0.15\text{ m/s}$.
- **`HeadlessController.gd`:** Decouples drone body yaw from pilot control axes relative to takeoff heading.
- **`TrimManager.gd`:** Calibrated digital pitch and roll bias adjustment stored in user settings.
- **`BatteryModel.gd`:** Watt-hour battery drain modeling accounting for electrical motor power ($\propto \text{RPM}^3$) and voltage sag.
- **`RTHController.gd`:** 3-phase Return-to-Home (Climb to 15m $\to$ Cruise at 8 m/s $\to$ Descend and Auto-Disarm).

### Phase 8: Aviation-Grade Vector HUD & Settings
- **Procedural CanvasItem Rendering:** Custom vector-drawn instruments rendered with zero raster texture memory:
  - `ArtificialHorizon.gd`: Spherical attitude pitch ladder (10° increments) and moving roll arc with seamless 360° `posmod` wrap.
  - `HeadingStrip.gd`: Tape-style compass showing 0°–360° with 8 cardinal indicators.
  - `HomeArrow.gd`: Real-time bearing pointer tracking launch pad position.
- **Pause & Settings Menu (`PauseMenu.gd`, `SettingsService.gd`):**
  - Live expo and deadzone calibration sliders.
  - Camera FOV adjustment ($60^\circ \dots 105^\circ$).
  - Dual metric ($m/s$, meters) and imperial ($mph$, feet) unit toggles.
  - Full action rebinding with conflict detection.

### Phase 9: Long-Distance World & Floating Origin
- **`WorldOrigin.gd` Autoload:** Floating origin manager monitoring drone distance. When $|p| > 2000\text{m}$, shifts the world origin safely via `_integrate_forces` on the physics thread, maintaining 64-bit coordinate accuracy over 20+ km flights.
- **`TerrainStreamer.gd`:** Multi-threaded asynchronous FastNoiseLite terrain chunk streamer on `WorkerThreadPool` with throttled GPU upload (1 chunk/frame), 2-tier LOD mesh generation, and 2-chunk unload hysteresis.
- **Selective Physics Collision:** Immediate $3 \times 3$ chunk neighbourhood enables Layer 2 collision; outer chunks disable collision to minimize broadphase BVH overhead by >80%.
- **`LandmarkBeacon.gd`:** Glowing 40m navigation beacon towers placed every 1,000m along the world grid.

---

## 3. Automated Verification & Testing

Every system has been rigorously tested using Godot 4.3 headless execution:
- **Master CI Runner:** `bash scripts/ci/run_all_tests.sh`
- **Total Test Suites:** 15 / 15 Passed (100%)
- **Total Acceptance Checks:** 110 / 110 Verified (100%)
- **Long-Distance Flight Simulation:** 20 km straight flight verified with 9 origin shifts, zero NaNs, and $< 1\text{ mm}$ coordinate error.
- **Master 20-Point Flight Audit:** All 20 physical flight tests verified (`test_comprehensive_flight_audit.gd`).

---

## 4. Upgrading & Running

```bash
# Clone repository
git clone https://github.com/roadofriot/DroneGame.git
cd DroneGame

# Launch Flight Simulator
godot res://scenes/flight/FlightWorld.tscn

# Run Test Suite
bash scripts/ci/run_all_tests.sh
```
