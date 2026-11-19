# MindSparQ Drone Simulator (v0.2.0 - Phase 10 Release)

**MindSparQ Drone Simulator** is a physics-driven 3D quadcopter flight simulation and exploration platform built with **Godot Engine 4.3 Stable**. It features deterministic 120 Hz aerodynamic flight dynamics, pure-logic attitude PID controllers, twin-stick controller-first HUD, 5 tunable flight profiles, 3 modular drone specs, an infinite floating-origin terrain streamer supporting 20+ km flights, and full support for keyboard, gamepad, and touch controls.

---

## Key Features

- **Realistic Physics & Aerodynamics:** 120 Hz fixed-step physics integration, mass-inertia tensors, motor lag modeling, ground effect, and aerodynamic drag.
- **Pure-Logic Flight Controller:** Decoupled `FlightController` RefCounted class operating without scene tree access for pure mathematical stability.
- **5 Dynamic Flight Profiles:** Cinematic (14° tilt), Normal (28° tilt), Sport (52° tilt), Arcade, and Acro (full rate manual control).
- **3 Modular Drone Presets:** Scout (all-around exploration), Photo (3-axis stabilized gimbal aerial rig), and Racer (high-voltage high-TWR aerobatic drone).
- **Infinite World & Floating Origin:** `WorldOrigin` floating-origin shift manager with 64-bit coordinates, multi-threaded `TerrainStreamer` using FastNoiseLite and LOD meshes, and landmark navigation beacons for 20+ km flights without floating-point degradation.
- **Aviation-Grade Vector HUD:** Custom vector-drawn `ArtificialHorizon` (pitch ladder & roll pointer), 0–360° `HeadingStrip`, target `HomeArrow`, dual units (metric $m/s$ / imperial $mph$), and battery energy telemetry.
- **Flight Features & Safety:** 4-Way cardinal stunt flips (with inverted thrust cutoff), active braking, headless flight mode, pitch/roll trim, altitude ceiling (60m), geofence (250m), and emergency motor cut.

---

## Quickstart & Execution

### Prerequisites
- **Godot Engine 4.3 Stable** (Linux x86_64, Windows, or macOS)
- OpenGL 3.3 / Vulkan compatible GPU (Forward+ or Mobile renderer)

### Run the Flight Simulation
```bash
# Launch the main Flight World in desktop window
godot res://scenes/flight/FlightWorld.tscn

# Or run the project directly from project root
godot .
```

### Run Automated Acceptance Tests
```bash
# Run the Master CI Runner (all 15 test suites)
bash scripts/ci/run_all_tests.sh

# Or run individual unit test suites headless
godot --headless -s tests/unit/test_flight_physics.gd
godot --headless -s tests/unit/test_long_distance_world.gd
godot --headless -s tests/unit/test_comprehensive_flight_audit.gd
```

---

## Flight Controls Manual

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
| **Camera Gimbal Tilt** | `PageUp` / `PageDown` | Left Trigger / Right Stick Y | HUD Gimbal Slider |
| **Switch Camera Mode** | `C` | Button X (West) | `CAM (C)` Button |
| **Cycle Flight Profile** | `M` | Right Bumper | `MODE (M)` Button |
| **Return to Home (RTH)** | `H` (Hold) | D-Pad Down | `RTH` Button |
| **Pause / Settings Menu** | `Escape` | Button Start | HUD Pause Button |
| **Emergency Motor Cut** | `Backspace` / `X` (0.7s)| Button Back/Select (0.7s) | `E-STOP` Button |
| **Reset to Launch Pad** | `R` | Button Y (North) | `RESET (R)` Button |

---

## Project Architecture

```text
DroneGame/
├── project.godot
├── README.md
├── scenes/
│   ├── drones/QuadcopterRig.tscn
│   ├── flight/FlightWorld.tscn
│   └── ui/FlightHUD.tscn
├── scripts/
│   ├── core/
│   │   ├── WorldOrigin.gd             # Floating origin manager (64-bit coordinates)
│   │   ├── GameState.gd               # Global game state & persistent session tracker
│   │   └── SettingsService.gd         # Input bindings, sensitivity & visual settings
│   ├── flight/
│   │   ├── FlightPhysics.gd           # RigidBody3D integration node
│   │   ├── FlightController.gd        # Pure-logic RefCounted attitude/rate loops
│   │   ├── FlightStateMachine.gd      # 6-state safety transition machine
│   │   ├── FlipController.gd          # 4-way cardinal stunt flip controller
│   │   ├── DroneRig.gd                # Visual meshes, rotors, LEDs & gimbal
│   │   ├── DroneSpec.gd               # Modular drone specification resource
│   │   └── DroneFrameGenerator.gd     # Procedural carbon-fiber frame builder
│   ├── features/
│   │   ├── FlightModeManager.gd       # Angle, Horizon (70% blend), and Acro modes
│   │   ├── BrakeController.gd         # Active horizontal deceleration dampener
│   │   ├── HeadlessController.gd      # Takeoff-heading locked pilot controls
│   │   ├── TrimManager.gd             # Persistent pitch/roll mechanical trim
│   │   ├── BatteryModel.gd            # 4S LiPo watt-hour energy consumption
│   │   └── RTHController.gd           # Automated climb-cruise-descend Return to Home
│   ├── world/
│   │   ├── TerrainStreamer.gd         # Multi-threaded FastNoiseLite chunk streamer
│   │   ├── LandmarkBeacon.gd          # 40m glowing navigation beacon towers
│   │   └── ChunkProps.gd              # MultiMeshInstance3D procedural foliage
│   ├── input/
│   │   ├── InputRouter.gd             # Unified radial deadzone, expo & ramping
│   │   └── ControlFrame.gd            # Normalized flight command data contract
│   ├── camera/
│   │   └── FlightCameraDirector.gd    # Chase, FPV Gimbal, Orbit & Top-down director
│   └── ui/
│       ├── FlightHUD.gd               # HUD coordinator & telemetry overlays
│       ├── ArtificialHorizon.gd       # Vector pitch ladder & roll arc
│       ├── HeadingStrip.gd            # 0–360° compass heading strip
│       ├── HomeArrow.gd               # Vector arrow pointing to launch home
│       ├── VirtualJoystick.gd         # Dual-touch floating analog joysticks
│       └── PauseMenu.gd               # Settings, expo sliders & action rebinding
├── data/
│   ├── tuning/drone_profiles.json
│   └── drones/
│       ├── scout_spec.tres
│       ├── photo_spec.tres
│       └── racer_spec.tres
├── tests/unit/                        # 15 automated test suites
├── scripts/ci/run_all_tests.sh        # Master CI automated runner
└── docs/
    ├── ARCHITECTURE.md                # Technical architecture decision record
    ├── CONTROLS.md                    # Detailed controls and sensitivity guide
    ├── QA_RESULTS_PHASE2.md           # Master QA verification matrix
    ├── RELEASE_NOTES_v0.1.0.md
    └── ASSET_LICENSES.md
```

---

## Documentation

- [docs/ARCHITECTURE.md](file:///home/mindsparq/Development/Game/DroneGame/docs/ARCHITECTURE.md): Comprehensive system architecture, dataflow diagrams, and state machines.
- [docs/CONTROLS.md](file:///home/mindsparq/Development/Game/DroneGame/docs/CONTROLS.md): In-depth controls guide, sensitivity curves, and rebinding reference.
- [docs/QA_RESULTS_PHASE2.md](file:///home/mindsparq/Development/Game/DroneGame/docs/QA_RESULTS_PHASE2.md): Automated CI test verification results and multi-input matrix.
- [docs/ASSET_LICENSES.md](file:///home/mindsparq/Development/Game/DroneGame/docs/ASSET_LICENSES.md): Open-source license attribution for procedural code and assets.
