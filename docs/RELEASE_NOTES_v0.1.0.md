# MindSparQ Drone Simulator — v0.1.0 Release Notes

**Version:** 0.1.0-alpha  
**Engine:** Godot Engine 4.3 Stable (`4.3.stable.official.77dcf97d8`)  
**Target Platforms:** Linux x86_64, Windows x86_64, Android (ARM64/x86_64)  
**License:** MIT / CC0 (Original & Open Assets)  

---

## 1. Product Overview

MindSparQ Drone Simulator is a physics-based 3D quadcopter flight simulator and exploration game. It combines deterministic rigid-body aerodynamics, responsive multi-device twin-stick flight controls, authored and procedural environments, guided flight training curriculum, and offline-first cartography.

Built strictly according to the **Master Product Blueprint** and **Antigravity Master Prompt**, with zero placeholder, static mockup, or demo content.

---

## 2. Core Architectural Pillars

### 2.1 60Hz Rigid Body Physics & Flight Dynamics
* **Physical Simulation:** Quadcopter mass $m = 1.25\text{ kg}$, $4\times 7.0\text{ N}$ motors, thrust-to-weight ratio $\text{TWR} = 2.29$.
* **Motor Dynamics:** First-order spool rate factor ($12.0\text{ s}^{-1}$), ground effect lift cushion ($< 1.5\text{m}$ AGL), quadratic linear aerodynamic drag, and angular damping.
* **Flight Tuning Profiles:**
  * **Cinematic:** $14^\circ$ tilt cap, $3.0\text{ m/s}$ climb, smooth auto-leveling.
  * **Normal:** $28^\circ$ tilt cap, $6.0\text{ m/s}$ climb, balanced auto-leveling.
  * **Sport:** $52^\circ$ tilt cap, $10.0\text{ m/s}$ climb, high agility.
  * **Arcade:** $40^\circ$ tilt cap, assisted braking, stunt keys enabled.
  * **Acro:** $180^\circ$ tilt, pure rate manual control, zero auto-leveling.
* **Battery Discharge Modeling:** $3800\text{ mAh}$ 4S LiPo battery with dynamic motor load amperage draw and automated low-voltage landing.

### 2.2 Input Router & Twin-Stick HUD
* Unified input abstraction handling physical keyboards (WASD / IJKL / Arrows / Space / R / C / M / F), physical gamepads (dual analog joysticks), and on-screen virtual analog touch controls.
* Complete telemetry overlay: Ground Speed, Vertical Climb Rate, Altitude AGL/MSL, Compass Heading, Artificial Horizon, Battery Percentage/Voltage, and Warning Banners.

### 2.3 Core Gameplay & Progression Loop
* **Mission Lifecycle:** Countdown timer, state machine (`NOT_STARTED`, `IN_PROGRESS`, `COMPLETED`, `FAILED`), and medal thresholds (Gold, Silver, Bronze).
* **Sequential Gates:** State shader feedback (`INACTIVE`, `ACTIVE`, `PASSED`) with strict out-of-order pass rejection.
* **Collectible 3D Coins:** Floating, rotating gold pickups with Area3D triggers.
* **Progression & Economy:** Nonlinear XP curve ($XP = 150 \times \text{level}^{1.35}$), idempotent run-hash reward crediting, and atomic save persistence with `.bak` corruption recovery.

### 2.4 Authored 3D World Catalogue
1. **Training Valley:** $220\text{m}\times 220\text{m}$ rolling valley terrain, takeoff pad, 4 flight gates, 6 coins, perimeter bounds.
2. **Butwal City:** $250\text{m}\times 250\text{m}$ urban environment, building towers (12m–24m), rooftop helipad spawn ($y=12.1\text{m}$), highway bridge, rooftop gates.
3. **Mountain Lake:** $240\text{m}\times 240\text{m}$ high-altitude alpine basin, water surface, island pad spawn ($y=2.1\text{m}$), 35m cliff ridge dive gates.

### 2.5 Flight Academy & Stunt Engine
* **Aerobatics:** Physics-aware Front Flip, Back Flip, Left Barrel Roll, Right Barrel Roll with pre-boost lift, differential motor spin, and auto-level brake recovery.
* **Safety Gating:** Disarmed lock, mode restriction (Arcade/Acro only), altitude floor ($\ge 3.0\text{m}$ AGL), tilt check ($< 40^\circ$), and 1.8s cooldown timer.
* **5-Lesson Curriculum:**
  1. *Takeoff & Hover Stability:* 2.0m AGL hold for 3 seconds.
  2. *Heading & Horizon Control:* 90° clockwise yaw, hold, and counter-yaw return.
  3. *Pitch, Roll & Braking:* Accelerate to $\ge 4.0\text{m/s}$, active counter-pitch brake to $\le 0.6\text{m/s}$.
  4. *Gate Precision Navigation:* Sequential 3-gate circuit traversal below 8.0m ceiling.
  5. *Precision Helipad Landing:* Helipad alignment, descent rate $< 1.0\text{m/s}$, tilt $< 15^\circ$.

### 2.6 Real Location Explorer
* **Offline Geocache:** Built-in landmark database for Nepal and global destinations with instant substring search and coordinate parsing (`"lat, lon"`).
* **2D Vector Cartography:** Interactive map canvas with Web Mercator projection, coordinate grid lines, procedural contours, compass, and scale bar.
* **GPS Privacy Gating:** Optional device location permission handler with full rationale disclosure, manual search fallback, and zero telemetry leakage.
* **Procedural Approximation World:** Deterministic seeded terrain generator from real coordinates with explicit approximation labeling.

### 2.7 Procedural Audio & Particle VFX
* **Procedural 16-Bit Audio:** Offline mathematical waveform synthesis:
  * Dynamic motor RPM pitch whine ($0.65 \to 2.20$).
  * Speed-driven wind roar pink noise.
  * Harmonic coin ding ($880\text{Hz} + 1760\text{Hz}$).
  * Major triad arpeggio gate chime.
  * Low-frequency crash impact thud.
* **Particle VFX:** Downward rotor wash ground dust ($< 2.5\text{m}$ AGL), golden coin sparkles, cyan gate flare, and crash impact debris.
* **Quality Presets:** Low (Performance), Medium (Balanced), High (Forward+).

---

## 3. Automated Master Verification Results

All 6 test suites executed via `./scripts/ci/run_all_tests.sh`:

| Suite | Focus Area | Tests | Status |
|---|---|---|---|
| Phase 1 | `tests/unit/test_flight_physics.gd` | 6 / 6 | **100% PASS** |
| Phase 2 | `tests/unit/test_core_gameplay.gd` | 6 / 6 | **100% PASS** |
| Phase 3 | `tests/unit/test_world_catalogue.gd` | 6 / 6 | **100% PASS** |
| Phase 4 | `tests/unit/test_stunt_and_academy.gd` | 6 / 6 | **100% PASS** |
| Phase 5 | `tests/unit/test_location_explorer.gd` | 6 / 6 | **100% PASS** |
| Phase 6 | `tests/unit/test_audio_vfx_settings.gd` | 6 / 6 | **100% PASS** |
| **TOTAL** | **Master Test Suite** | **36 / 36** | **100% PASS** |

---

## 4. Release Artifacts

* **Release Game Pack:** `build/linux/mindsparq_drone_simulator.pck`
* **Test Runner Script:** `scripts/ci/run_all_tests.sh`
* **Build Script:** `scripts/build/build_release.sh`
* **Export Presets:** `export_presets.cfg`
