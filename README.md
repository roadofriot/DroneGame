# MindSparQ Drone Simulator

**MindSparQ Drone Simulator** is a physics-driven 3D quadcopter flight simulation and exploration game built with **Godot Engine 4.3 Stable**. It features deterministic 60 Hz aerodynamic flight dynamics, twin-stick controller-first HUD, 5 tunable flight profiles (Cinematic, Normal, Sport, Arcade, Acro), multi-camera directors (Chase, FPV Gimbal, Orbit, Top-Down), and modular architecture.

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

### Run Automated Headless Acceptance Tests
```bash
godot --headless -s tests/unit/test_flight_physics.gd
```

---

## Controls

| Action | Keyboard | USB Gamepad | Virtual Touch HUD |
| :--- | :--- | :--- | :--- |
| **Throttle Up / Down** | `W` / `S` | Left Stick Vertical | Left Joystick Y-Axis |
| **Yaw Left / Right** | `A` / `D` | Left Stick Horizontal | Left Joystick X-Axis |
| **Pitch Forward / Backward**| `Up` / `Down` (or `I`/`K`) | Right Stick Vertical | Right Joystick Y-Axis |
| **Roll Left / Right** | `Left` / `Right` (or `J`/`L`) | Right Stick Horizontal | Right Joystick X-Axis |
| **Stunt Flip (4-Way)** | `F` + Direction | Button B / East + Stick | `FLIP (F)` Button + Stick |
| **Takeoff / Land / Recover**| `Space` | Button A (Cross) | `TAKEOFF` / `LAND` Button |
| **Switch Camera Mode** | `C` | Button X (Square) | `CAM (C)` Button |
| **Cycle Flight Profile** | `M` | Right Bumper | `MODE (M)` Button |
| **Return to Home (RTH)** | `H` | D-Pad Down | Telemetry / HUD |
| **Reset to Launch Pad** | `R` | Button Y (Triangle) | `RESET (R)` Button |

---

## Project Structure
```text
DroneGame/
├── project.godot
├── README.md
├── scenes/
│   ├── drones/QuadcopterRig.tscn
│   ├── flight/FlightWorld.tscn
│   └── ui/FlightHUD.tscn
├── scripts/
│   ├── flight/FlightPhysics.gd
│   ├── flight/DroneRig.gd
│   ├── input/InputRouter.gd
│   ├── camera/FlightCameraDirector.gd
│   └── ui/
│       ├── FlightHUD.gd
│       └── VirtualJoystick.gd
├── data/tuning/drone_profiles.json
├── tests/unit/test_flight_physics.gd
└── docs/
    ├── ARCHITECTURE.md
    ├── CONTROLS.md
    ├── ASSET_LICENSES.md
    └── QA_RESULTS_PHASE1.md
```
