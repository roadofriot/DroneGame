# Architecture Decision Record & Technical Architecture
## MindSparQ Drone Simulator

### 1. Engine & Runtime Selection
- **Decision:** Godot 4.3 Stable (Forward+ renderer for desktop, Mobile export ready).
- **Physics Ticks:** 120 Hz fixed physics step with `max_physics_steps_per_frame = 8` for deterministic flight dynamics and aerobatic stunt maneuvers.
- **Rationale:** Lightweight footprint, zero runtime royalties, open-source C++ core, deterministic physics tick, native 3D scene tree and cross-platform export without third-party vendor lock-in.

---

### 2. Separation of Concerns & Dataflow (Phase 3 & 4)

```mermaid
graph TD
    InputSources[Gamepad / Keyboard / Touch] -->|Raw Events| IR[InputRouter.gd]
    IR -->|Radial Deadzone, Expo, Ramping| CF[ControlFrame.gd\nNormalized RefCounted]
    CF -->|cmd: ControlFrame| FC[FlightController.gd\nPure-Logic RefCounted]
    Tuning[drone_profiles.json] -->|Gains & Inertia| FC
    FP_State[RigidBody3D State\nBasis, w_world, v_world] -->|Body Orientation & Rates| FC
    
    subgraph FC_Processing [FlightController.step]
        Heading[Heading Frame Basis] --> TargetUp[Target Up Vector]
        TargetUp --> AttP[Attitude P-Loop]
        AttP --> RateP[Rate P-Loop]
        Collective[Collective Altitude Hold] --> Thrust[Total Thrust T]
        Thrust --> Mixer[X-Quad Mixer FL, FR, RL, RR]
        RateP --> Mixer
        Mixer --> Desat[Differential Desaturation & Lag]
    end

    FC -->|force_local, torque_local, motors| FP[FlightPhysics.gd\nRigidBody3D Body]
    FSM[FlightStateMachine.gd\nStates & Safety] <-->|State Progression & Gating| FP
    FP -->|Forces & Torques| RigidBody[RigidBody3D Physics]
    FP -->|Kinematic Telemetry| HUD[FlightHUD.gd]
    FP -->|Velocity/Heading| CD[FlightCameraDirector.gd]
    FP -->|Motor RPMs & Gimbal Angle| DR[DroneRig.gd]
    HUD -->|Touch Virtual Sticks| IR
```

- **`ControlFrame.gd` (RefCounted)**: Unified data contract holding normalized axes in `[-1.0, 1.0]`: `throttle` (climb/descend), `yaw` (yaw right/left), `pitch` (forward/backward), `roll` (right/left).
- **`InputRouter.gd`**: Normalizes inputs across physical keyboard, USB gamepads, and virtual on-screen analog sticks into `ControlFrame` using circular radial deadzone (`0.12`), cubic expo (`0.35`), and keyboard attack/release ramping.
- **`FlightController.gd` (Pure Logic RefCounted)**:
  - **Zero scene-tree/node access**: strictly computational.
  - **Attitude Control**: Evaluates desired body-up orientation in the heading frame. Calculates attitude error vector $\mathbf{e} = \text{body}^T (\mathbf{u} \times \mathbf{u}_{\text{desired}})$, maps to rate target via $k_{p,\text{att}}$, and drives torque via angular rate P-loop with inertia tensor.
  - **Collective & Altitude Hold**: Translates throttle command to target climb rate, maintaining altitude hold when centered. Compares against vertical velocity with tilt compensation: $T = m(g + k_{p,\text{climb}}(v_{z,\text{cmd}} - v_y)) / \max(u_y, 0.5)$.
  - **X-Quad Mixer**: Maps total thrust $T$ and 3 torques $(\tau_x, \tau_y, \tau_z)$ to 4 motors $[0: FL, 1: FR, 2: RL, 3: RR]$. Employs equal shifting desaturation when $\max(f_i) > f_{\max}$ to preserve differential torque authority without control clipping. Models motor electrical/mechanical lag with first-order filter ($\tau = 0.04\text{s}$).
- **`FlightStateMachine.gd` (Pure Logic RefCounted)**: Standalone state machine managing 6 states (`DISARMED`, `TAKEOFF`, `FLYING`, `LANDING`, `FLIPPING`, `CRASHED`), spin-up timers, landing descent, touchdown detection, tilt inversion safety, and emergency disarm.
- **`FlightPhysics.gd`**: RigidBody3D integration node. Receives physical forces and torques from `FlightController`, synchronizes state with `FlightStateMachine`, executes downward raycast queries on `PhysicsDirectSpaceState3D` every physics tick, and emits telemetry.
- **`DroneRig.gd`**: Visual presentation. Animates 4 rotor meshes with counter-rotating pairs, navigation LEDs, and stabilizes the camera gimbal mount.
- **`FlightCameraDirector.gd`**: Multi-camera director managing Chase, FPV Gimbal, Orbit, and Top-Down modes with position damping and velocity look-ahead.

---

### 3. Coordinate System & Sign Conventions

Following standard Godot 3D conventions:
- **Axes**: Forward = $-Z$, Up = $+Y$, Right = $+X$.
- **Pitch**:
  - Pitch Up (nose up, towards $+Z$): Positive rotation about $+X$.
  - Pitch Forward (nose down, towards $-Z$): Negative rotation about $+X$. Rear motors ($RL, RR$) push harder than front motors ($FL, FR$).
- **Roll**:
  - Bank Left: Positive rotation about $-Z$ / positive torque about $+Z$.
  - Bank Right: Negative torque about $+Z$. Left motors ($FL, RL$) push harder than right motors ($FR, RR$).
- **Yaw**:
  - Positive rotation about $+Y$: Counter-clockwise from above (Yaw Left).
  - Negative rotation about $+Y$: Clockwise from above (Yaw Right). Counter-rotating motors ($FR, RL$ CCW) spin faster, imparting clockwise reaction torque.
- **Motor Index Mapping**:
  - `0`: Front Left (`FL`, $x = -d, z = -d$, CW)
  - `1`: Front Right (`FR`, $x = +d, z = -d$, CCW)
  - `2`: Rear Left (`RL`, $x = -d, z = +d$, CCW)
  - `3`: Rear Right (`RR`, $x = +d, z = +d$, CW)

---

### 4. State Machine & Safety Transition Matrix (Phase 4)

```mermaid
stateDiagram-v2
    [*] --> DISARMED
    DISARMED --> TAKEOFF: takeoff_land_pressed (battery >= 5%, grounded)
    TAKEOFF --> FLYING: 0.5s spin-up + reached 1.5m AGL
    FLYING --> LANDING: takeoff_land_pressed
    LANDING --> FLYING: takeoff_land_pressed (abort landing)
    LANDING --> DISARMED: AGL < 0.15m & speed < 0.2 m/s
    FLYING --> FLIPPING: flip_pressed (Phase 5)
    FLIPPING --> FLYING: flip_completed / timeout
    FLYING --> CRASHED: collision impulse / tilt > 100° for 0.5s / emergency_stop
    LANDING --> CRASHED: collision impulse / emergency_stop
    TAKEOFF --> CRASHED: collision impulse / emergency_stop
    CRASHED --> DISARMED: reset_pressed (R / Gamepad Y)
```

| Current State | Event / Trigger | Target State | Guards & Execution Logic |
|---|---|---|---|
| `DISARMED` | `takeoff_land` | `TAKEOFF` | Battery $\ge 5\%$, grounded on launch pad. Starts 0.5s spin-up. |
| `TAKEOFF` | Target reached | `FLYING` | $t \ge 0.5\text{s}$ and $\text{AGL} \ge 1.5\text{m}$. Enables manual control. |
| `TAKEOFF` | `emergency_stop` | `CRASHED` | Held 0.7s. Zeroes all motor thrust within 1 tick. |
| `FLYING` | `takeoff_land` | `LANDING` | Initiates controlled $0.8\text{ m/s}$ vertical descent with horizontal braking. |
| `LANDING` | `takeoff_land` | `FLYING` | Aborts landing; pilot regains full attitude authority immediately. |
| `LANDING` | Touchdown | `DISARMED` | Triggered when $\text{AGL} \le 0.15\text{m}$ and ground speed $\le 0.2\text{ m/s}$. Disarms motors. |
| `FLYING` | `emergency_stop`| `CRASHED` | Held 0.7s. Instantly cuts motor thrust to 0.0 N. |
| `ANY AIRBORNE` | Inversion Tilt | `CRASHED` | Body tilt $> 100^\circ$ sustained for $> 0.5\text{s}$ at altitude $\le 5.0\text{m}$. |
| `ANY AIRBORNE` | Impact | `CRASHED` | Collision impulse $\ge 12.0\text{ N/kg}$. |
| `CRASHED` | `reset` | `DISARMED` | Overloaded Space recover removed; strictly requires Reset (`R` / Gamepad `Y`). |
