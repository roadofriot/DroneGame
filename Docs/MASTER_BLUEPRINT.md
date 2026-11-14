# MindSparQ Drone Simulator
## Product Requirements, Game Design, Technical Architecture & Phased Implementation Blueprint

**Document status:** Implementation-ready product blueprint (pre-build)  
**Product type:** 3D drone simulator + open-world exploration game  
**Working title:** MindSparQ Drone Simulator  
**Target platforms:** Windows, Linux, Android; architecture should not block macOS/iOS later  
**Primary language:** English UI initially; Nepali localization-ready  
**Product principle:** A real-feeling drone flight experience inside a rewarding, visually rich game world.

---

# 1. Product Vision

Build a polished 3D drone simulator in which players can fly a distinctive quadcopter, explore authored environments and selected real-world locations, complete missions, collect coins, perform controlled aerobatic stunts, unlock drones and cosmetics, and learn progressively more advanced flight skills.

This is not a static drone showroom, a UI-only mockup, a physics-less flying demo, or a Google Maps wrapper. The core product must be a playable 3D game with a working flight model, responsive controls, real collision, persistent progression, authored levels, audio, camera systems, and reliable save/recovery behavior.

## 1.1 Product pillars

1. **Flight feel:** responsive, understandable, tunable drone movement.
2. **World exploration:** handcrafted locations with meaningful landmarks and routes.
3. **Game loop:** missions, coins, XP, unlocks, achievements and replayability.
4. **Controller-first UX:** twin virtual sticks matching the supplied controller reference, without showing a phone frame.
5. **Camera experience:** chase, FPV, follow, orbit, top-down and gimbal camera modes.
6. **Location discovery:** searchable real-world map preview, with clear distinction between map imagery and playable game worlds.
7. **Performance:** scalable quality presets for modest hardware and mobile devices.
8. **Honesty and safety:** no claim that map imagery is live drone video; no real-world drone control in this game.

## 1.2 Product boundaries

- This is a simulated game. It must not connect to or control a real aircraft.
- Real-location explorer is for map visualization and optional GPS-based centering only.
- Google Maps imagery is not a live camera feed and must not be presented as one.
- Real-world drone operation, airspace authorization, surveillance, or flight planning are outside this product.
- Multiplayer is a later phase; do not compromise the offline single-player core to build it prematurely.

---

# 2. Reference Analysis and Design Direction

## 2.1 Supplied drone reference

Use the supplied first image as the visual direction for an original drone:
- compact four-arm quadcopter;
- protective circular propeller guards;
- dark graphite/black mechanical frame;
- metallic cyan/blue arm accents;
- glossy blue upper shell;
- visible motors and spinning propellers;
- underside gimbal camera;
- believable material roughness, reflections, shadows and rotor blur.

Do not trace or reproduce a third-party commercial drone design exactly. Create an original silhouette and original mesh.

## 2.2 Supplied controller reference

Use only the controller layout inside the second image. Do not render a phone, hands, device bezel or phone mockup.

Target layout:
- left virtual stick: throttle + yaw;
- right virtual stick: pitch + roll;
- compact top telemetry strip;
- flight-mode selector;
- take-off / land / return-to-home;
- camera shutter / recording;
- mini-map / compass;
- battery, GPS, signal, speed and altitude;
- optional obstacle proximity indicator;
- flip/stunt button available only in compatible arcade/aerobatic modes.

The controller must be a responsive HUD overlay, not a separate phone object.

## 2.3 Reference website learnings

The reference simulators demonstrate useful patterns:
- multiple maps/world themes;
- map-specific level lists;
- free flight, time trial, racing and delivery missions;
- precision landing and drop targets;
- multiple camera views;
- configurable flight modes;
- controller calibration and external gamepad/USB transmitter support;
- custom map/world creation and multiplayer as later-stage features.

Use these as product inspiration only. Do not copy their source code, artwork, level geometry, maps, branding, names, or proprietary assets.

---

# 3. Target Users and Modes

## 3.1 Player types

- Casual explorer: wants beautiful locations and easy controls.
- Arcade player: wants coins, flips, rings, time trials and unlocks.
- Flight learner: wants stable, progressive flight lessons.
- FPV/racing enthusiast: wants manual control, speed and skill challenges.
- Creator: wants custom routes and later custom-map tools.

## 3.2 Game modes

### A. Explore / Free Flight
- no countdown;
- free movement inside the playable boundary;
- optional coin trails and discovery points;
- pause, reset-to-pad and return-to-home;
- no mandatory objective.

### B. Training Academy
- guided take-off and landing;
- hover stability;
- yaw and orientation;
- pitch/roll movement;
- braking and momentum management;
- figure-eight route;
- precision landing;
- obstacle awareness;
- camera operation.

### C. Coin Hunt
- collect floating coin pickups;
- route-based coin trails;
- hidden coin clusters;
- combo multiplier for consecutive pickups;
- coins persist after a successful mission;
- prevent farming exploits through mission/run identity and reward rules.

### D. Ring Racing
- fly through ordered 3D gates;
- time limit and checkpoints;
- missed gates must not count;
- bronze/silver/gold medals;
- replay ghost as a later enhancement.

### E. Delivery / Cargo
- pick up a virtual package;
- fly to a marked target;
- land or hover within a tolerance zone;
- package drop animation;
- score based on accuracy, time and collision penalties.

### F. Precision Landing
- land inside a pad;
- score based on center offset, vertical speed, tilt and stability;
- hard fail only for severe crash conditions.

### G. Stunt / Freestyle
- flips, rolls, loops and controlled aerobatics;
- score based on clean execution, height, speed and landing;
- stunt input disabled in beginner training and realistic learning mode unless explicitly enabled.

### H. Photo Scavenger
- visit marked scenic viewpoints;
- align camera framing with a target composition;
- take virtual screenshots;
- earn stars for framing and discovery.

### I. Time Trial
- fixed route and timer;
- checkpoint integrity;
- compare best time and medal.

### J. Custom Flight (later)
- create route gates, pads, rings and pickup points;
- save custom courses;
- share only after moderation and security design.

---

# 4. Flight Model and Drone Behaviour

The flight model is the heart of the product. It must not be faked by moving a drone model along scripted paths.

## 4.1 Control axes

- Throttle: vertical thrust / climb and descend.
- Yaw: rotate heading around vertical axis.
- Pitch: tilt forward/back.
- Roll: tilt left/right.

The twin-stick default mapping:
- Left stick vertical = throttle.
- Left stick horizontal = yaw.
- Right stick vertical = pitch.
- Right stick horizontal = roll.

Provide invert-Y, stick mode presets (Mode 1 / Mode 2), deadzone, sensitivity, expo, and calibration.

## 4.2 Flight profiles

1. **Cine:** low speed, gentle tilt, high stabilization.
2. **Normal:** balanced response and auto-level.
3. **Sport:** higher acceleration and tilt limits.
4. **Acro:** rate-based manual flight, advanced users only.
5. **Arcade:** forgiving assistance, stunt actions and game scoring.

The game should expose a short explanation for each mode.

## 4.3 Physics requirements

Implement a deterministic, fixed-timestep flight simulation:
- mass, gravity, thrust, drag and angular damping;
- motor spool-up/spool-down response;
- pitch/roll/yaw torque;
- maximum tilt and angular rates by mode;
- linear and angular velocity;
- ground effect approximation near ground;
- collision impulses and damage state;
- wind as optional force field;
- battery drain as a gameplay system, not a fake decorative percentage;
- propeller RPM audio mapped to throttle;
- rotor animation mapped to motor state;
- gimbal stabilization separate from body orientation.

Use a configurable physics model. Start with an accessible quadcopter rigid-body approximation; only progress to a four-motor force/torque model after the baseline is stable and testable. Never claim manufacturer-grade flight accuracy without validation against measured data.

## 4.4 Flight assistance

- auto-level toggle;
- altitude hold (mode-dependent);
- position hold (simulated GPS mode);
- return-to-home;
- low-battery warning;
- out-of-bounds warning;
- crash recovery / reset at pad;
- optional obstacle warning.

RTH must navigate to the recorded take-off point using a safe, bounded simulated route. It must not teleport the drone. If the path is obstructed, stop/hover and show a clear failure state or use a validated safe-altitude route.

## 4.5 Stunt system

Stunts are explicit game actions, not random uncontrolled transforms:
- front flip;
- back flip;
- left/right barrel roll;
- optional loop in a later iteration.

Requirements:
- trigger only in Arcade/Stunt mode or when enabled in custom settings;
- check minimum altitude and speed;
- animate through a physics-aware angular target;
- score only when the drone completes the manoeuvre and stabilizes;
- crash or partial completion must not award full points;
- provide cooldown and input feedback.

---

# 5. Controller HUD and Screen UX

## 5.1 Main flight screen

The 3D world fills the screen. The HUD is layered over it with safe margins and adaptive scaling.

**Top telemetry bar**
- GPS status / simulated GPS lock;
- signal quality (game simulation);
- battery icon + percentage;
- flight mode;
- altitude;
- horizontal speed;
- compass heading;
- recording state;
- pause/settings.

**Left control cluster**
- circular virtual stick;
- plus/minus camera zoom or configurable auxiliary controls;
- optional altitude/compass widget.

**Right control cluster**
- circular virtual stick;
- camera-look or gimbal control as an optional secondary gesture.

**Bottom action cluster**
- Take Off / Land stateful action;
- RTH;
- camera shutter;
- video record;
- camera mode;
- flight mode chips;
- stunt/flip button only when available;
- mission objective / progress.

**Side indicator**
- proximity/obstacle warning;
- warning must be based on actual game-world collision probes, not random animation.

## 5.2 HUD behavior

- controls must remain visible against bright and dark scenes;
- translucent dark panels with readable contrast;
- touch targets at least 44–48 logical pixels where practical;
- no action hidden under OS navigation bars/notches;
- no overlap with joystick zones;
- landscape is the primary flight orientation;
- portrait may show menu/map, but flight mode should either reflow cleanly or prompt landscape;
- keyboard, mouse, controller and touchscreen inputs must coexist without duplicate command application.

## 5.3 Desktop input

- WASD / arrow keys configurable;
- mouse camera look;
- keyboard take-off, land, RTH, pause, camera switch;
- gamepad analog sticks;
- USB RC transmitter recognized through supported joystick/HID mapping where platform permissions allow;
- calibration wizard with axis visualization.

---

# 6. Location and World Catalogue

Every world is a self-contained, optimized scene package with its own visual identity, landmarks, mission set, soundscape, boundary, weather profile and progression.

## 6.1 Nepal — launch-region world pack

### World N01: Butwal City & Tinau Corridor
Visual identity:
- stylized but recognizable western Terai urban environment;
- city roads, mixed low-rise/high-rise buildings, green patches;
- Tinau river corridor and bridges;
- hill silhouettes and warm haze;
- market streets and open training grounds.

Mission ideas:
- Beginner: take-off from a training pad.
- Coin Hunt: collect coins along a river-side route.
- Ring Run: pass through bridge-side gates.
- Delivery: transport a virtual parcel to a marked courtyard.
- Precision: land on a rooftop helipad (fictional/safe game set).
- Photo: frame the hill/river panorama.

### World N02: Lumbini Sacred Garden
- peaceful landscaped gardens;
- ponds, pathways, trees and stylized heritage architecture;
- no disrespectful or intrusive mission design around sacred sites;
- gentle cinematic mode and photo exploration;
- restricted/no-fly game zones around sensitive structures if required by the level design.

### World N03: Pokhara Lakeside
- lake, boats as static/animated background props, forested slopes;
- mountain backdrop;
- route rings over designated open-water game corridors;
- scenic photo missions and precision landing.

### World N04: Kathmandu Valley
- dense city blocks, temples and courtyards as stylized original assets;
- hills surrounding the valley;
- traffic and crowds represented as low-cost ambient simulation;
- obstacle navigation and delivery missions;
- culturally respectful art direction.

### World N05: Chitwan Plains
- grassland, river bends, forest, wetlands;
- wildlife only as distant ambient non-interactive scenery;
- delivery and navigation routes;
- no wildlife chasing or disturbance gameplay.

### World N06: Himalayan Base Camp
- mountain terrain, snow, ridgelines, clouds and wind;
- high-altitude handling preset;
- battery and wind-management challenge;
- cinematic exploration and advanced ring routes.

## 6.2 International worlds

### World W01: Al-Madina Inspired Desert City
- warm sand palette, mud-brick-inspired architecture, wind towers, market lanes, oasis;
- original fictional city, not a replica of protected/sacred places;
- heat haze and dust ambience;
- 10–15 mission slots over time.

### World W02: Metro City
- modern urban grid;
- high-rise clusters, elevated roads, parks and delivery courtyards;
- racing, delivery, precision landing;
- clear playable corridors and obstacle volumes.

### World W03: Aldenburg Medieval Town
- fictional walled medieval town;
- narrow lanes, towers, market square, stone bridge;
- FPV course and exploration;
- avoid copying a real game's exact layout.

### World W04: Mountain Farm
- rolling green hills, farm buildings, dirt tracks, ponds and windbreak trees;
- beginner and intermediate flight lessons;
- crop-survey-style virtual missions without real agricultural claims.

### World W05: Canyon Run
- sandstone cliffs, ridges, caves and ravines;
- advanced FPV racing;
- visibility and wind variation.

### World W06: Moon Basin
- stylized lunar terrain, craters and low-gravity arcade mode;
- explicitly fictional physics preset;
- no claim of realistic terrestrial flight.

### World W07: Ruined City
- fictional abandoned city, collapsed structures, vegetation;
- obstacle and route-finding missions;
- no gore or horror requirement.

### World W08: Coastal Port
- sea, docks, containers, cranes, warehouses and lighthouse;
- delivery and ring racing;
- wind gusts and moving ship ambience.

### World W09: Snow Valley
- alpine village, ski slopes, pine forest, frozen lake;
- cold-weather visual effects and wind challenge.

### World W10: Neon Future City
- original sci-fi city, glowing routes and elevated tracks;
- arcade races, stunt zones and time trials.

## 6.3 World data contract

Each world must declare:
- `world_id`, display name, region, version;
- scene entry point;
- world bounds and safe spawn pads;
- quality tiers;
- landmark IDs;
- mission IDs;
- collectible spawn definitions;
- ambient audio;
- weather presets;
- navigation/mini-map metadata;
- required asset bundle;
- licensing/attribution metadata where relevant;
- minimum supported device tier.

Do not ship a world card that opens an empty scene. Locked worlds must be explicitly labelled as locked or coming later, never represented as playable.

---

# 7. Mission and Level Design

Each world should launch with a small, complete and polished set rather than dozens of empty level buttons.

## 7.1 Recommended launch content

MVP content:
- 3 playable worlds: Training Valley, Butwal-inspired City, Mountain Lake.
- 3–5 missions per world.
- 1 free-flight mode per world.
- 1 coin-hunt route per world.
- 1 ring course per world.
- 1 precision landing or delivery mission per world.

Post-MVP:
- Lumbini, Pokhara, Kathmandu, Chitwan, Himalayan Base Camp;
- Desert City, Metro City, Medieval Town;
- additional mission variants and weather.

## 7.2 Mission lifecycle

`Locked -> Available -> InProgress -> Completed | Failed -> RewardClaimed`

- completion must be persisted once;
- reward claim must be idempotent;
- retries must not duplicate rewards;
- pause/resume must preserve mission state safely;
- leaving a mission must ask whether to resume, restart or exit when progress would be lost.

## 7.3 Medal scoring

Score dimensions:
- mission objective completion;
- time;
- collision count/severity;
- landing accuracy;
- route/checkpoint accuracy;
- coin collection;
- optional stunt execution.

Do not over-reward reckless speed in training missions.

---

# 8. Coins, XP, Unlocks and Economy

## 8.1 Collectibles

- floating 3D coin mesh with metallic material;
- idle bobbing and slow rotation;
- proximity pickup radius;
- magnetic pickup only as a temporary power-up;
- pickup sound, particles and HUD counter;
- clear feedback when collected;
- deterministic spawn placement.

## 8.2 Reward integrity

- mission rewards are calculated by trusted game logic;
- one mission completion grants its reward once per completion record;
- no unlimited reward on restart;
- offline local progression is allowed for single-player;
- if accounts/cloud saves are added, server-side validation is required for competitive leaderboards and purchases;
- never sell real-money currency in MVP.

## 8.3 Unlockables

- drone paint skins;
- propeller guard accents;
- camera/gimbal cosmetic skins;
- controller themes;
- trails and pickup effects;
- new drone classes only when their performance differences are clearly explained.

Cosmetics must not secretly change competitive physics.

## 8.4 Economy screens

- wallet total;
- XP and level;
- earned/available rewards;
- unlock requirements;
- transaction history for earned/spent in-game currency;
- no dead purchase buttons;
- if store is not implemented, do not show a fake store.

---

# 9. Drone Garage

Launch with one fully polished primary drone and optionally one alternate handling preset. Additional drone models should be added only after each has a complete model, rig, flight tuning, camera mount and UI metadata.

Garage features:
- 3D turntable preview;
- rotate/zoom;
- material and skin selection;
- propeller and camera preview;
- drone stats: mass class, agility, top speed, stability, battery endurance (gameplay values);
- select/favorite;
- locked state with clear unlock criteria.

The supplied cyan/black quadcopter is the hero drone direction. Build an original model in Blender and export optimized glTF/GLB.

---

# 10. Camera and Recording

Camera modes:
1. Chase camera.
2. FPV camera.
3. Follow camera.
4. Orbit camera.
5. Top-down camera.
6. Ground observer camera.
7. Gimbal/photo camera.

Requirements:
- smooth camera transitions;
- camera collision avoidance;
- adjustable FOV;
- gimbal pitch control;
- photo screenshot capture;
- optional local video recording only after platform feasibility is tested;
- recording indicator and permission handling;
- do not claim cinematic recording if only screenshots are supported.

---

# 11. Real Location Explorer

This module is distinct from the handcrafted game-world system.

## 11.1 User journey

1. Open `Real Location Explorer`.
2. Search a place (e.g., Butwal, Rupandehi, Nepal).
3. Show map results and geographic context.
4. User selects a location.
5. Show 2D map first; optionally load 3D terrain/buildings if a provider supports it.
6. Display provider, data freshness limitations and attribution.
7. User chooses:
   - `Preview Map` (map visualization only);
   - `Create Game Flight Area` (only if an authored/processed game-world package exists);
   - `Approximate Training World` (procedurally generated, clearly labelled approximation).
8. Start a simulated flight only in a supported game scene.

## 11.2 Open/free-first map architecture

Recommended provider abstraction:
- OpenStreetMap-compatible data for place/map context;
- MapLibre GL JS for 2D/vector map rendering where an appropriate tile provider is configured;
- optional self-hosted vector tiles for predictable long-term use;
- optional CesiumJS for globe/terrain/3D Tiles visualization;
- optional Google Photorealistic 3D Tiles adapter, explicitly premium/usage-billed and governed by Google terms.

Do not hard-code one tile provider URL. Add a provider configuration layer.

## 11.3 Important licensing and cost constraints

- OpenStreetMap data is open, but the public `tile.openstreetmap.org` tile service is not an unlimited free CDN.
- Follow OSM attribution, caching and usage policy.
- Do not bulk download or prefetch public OSM raster tiles for offline use.
- For offline maps, use self-hosted tiles or a provider whose licence explicitly permits offline packaging.
- Google Photorealistic 3D Tiles require an enabled billing account and API key; pricing and quotas can change.
- Google map tiles have attribution, caching, display and content-use restrictions. Keep required Google branding and data attributions visible.
- Never extract or recreate Google's 3D geometry from its tiles for a separate offline game world.
- Do not promise every village/town has photorealistic 3D coverage.

## 11.4 GPS and privacy

- GPS is optional and permission-gated.
- Explain why location is requested.
- Provide manual search when permission is denied.
- Do not store precise location history by default.
- Do not transmit location unless required and explicitly disclosed.
- A location permission provides the device's location, not a live aerial camera.
- Show an accuracy radius and last-updated timestamp when available.

## 11.5 Live preview terminology

Use:
- `Live Location` for current device GPS position (if permission granted);
- `3D Map Preview` for streamed map imagery;
- `Game Flight` for the simulated drone inside a playable scene.

Never label map tiles as a live drone camera view.

---

# 12. Technical Architecture

## 12.1 Recommended stack

**Primary game engine: Godot 4.x (stable release at implementation time).**

Reasons:
- open-source and lightweight relative to large commercial engines;
- native 3D game workflow;
- GDScript/C# options;
- desktop and Android export;
- suitable for a performance-conscious first release;
- no mandatory proprietary runtime subscription.

**3D authoring:** Blender  
**3D asset format:** glTF 2.0 / GLB  
**Game data:** versioned JSON/Resource files initially  
**Persistence:** local save files with schema versioning; SQLite only if structured data volume justifies it  
**Map explorer:** MapLibre GL JS / CesiumJS as a separately isolated map module  
**Build automation:** Git + reproducible Godot export presets  
**Audio:** Godot audio buses and imported OGG/ WAV assets  
**Localization:** Godot translation resources; English first, Nepali-ready.

Do not select Unity/Unreal by default for this project. Re-evaluate only if a proven requirement cannot be met in Godot.

## 12.2 High-level modules

- `AppShell`: boot, menus, settings, navigation.
- `WorldManager`: load/unload world scenes and asset bundles.
- `DroneController`: input mapping and control modes.
- `FlightPhysics`: fixed-step physics, thrust, torque, drag and assistance.
- `DroneRig`: mesh, motors, propellers, gimbal and damage visuals.
- `CameraDirector`: camera modes and transitions.
- `MissionManager`: mission lifecycle, objectives and scoring.
- `CollectibleManager`: coins and pickups.
- `ProgressionService`: XP, levels, unlocks and rewards.
- `SaveService`: versioned local persistence.
- `AudioDirector`: motors, UI, environment and event sounds.
- `HUDController`: telemetry and controller UI.
- `InputRouter`: touch, keyboard, mouse, gamepad and supported HID.
- `MapExplorer`: real-location search and map rendering.
- `SettingsService`: graphics, controls, audio, accessibility.
- `Telemetry/Diagnostics`: local crash/error diagnostics with privacy controls.

## 12.3 Suggested project structure

```text
mindsparq-drone-simulator/
├── project.godot
├── README.md
├── LICENSES.md
├── CHANGELOG.md
├── export_presets.cfg
├── addons/
├── assets/
│   ├── drones/
│   ├── environments/
│   ├── props/
│   ├── ui/
│   ├── audio/
│   ├── vfx/
│   └── fonts/
├── scenes/
│   ├── app/
│   ├── menus/
│   ├── flight/
│   ├── drones/
│   ├── worlds/
│   ├── missions/
│   └── ui/
├── scripts/
│   ├── core/
│   ├── flight/
│   ├── input/
│   ├── camera/
│   ├── missions/
│   ├── economy/
│   ├── save/
│   ├── maps/
│   └── ui/
├── data/
│   ├── drones/
│   ├── worlds/
│   ├── missions/
│   ├── tuning/
│   └── localization/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── acceptance/
├── map-explorer/
│   ├── package.json
│   ├── src/
│   └── README.md
└── docs/
    ├── PRODUCT_BLUEPRINT.md
    ├── ARCHITECTURE.md
    ├── CONTROLS.md
    ├── WORLD_PIPELINE.md
    ├── QA_PLAN.md
    └── ASSET_LICENSES.md
```

This is a proposed structure, not a mandate to create empty folders. Add modules when they own real behavior.

## 12.4 Performance strategy

Target tiers:
- Low: 30 FPS target, reduced shadows, lower render scale, fewer particles, lower terrain detail.
- Balanced: 45–60 FPS target where hardware permits.
- High: 60 FPS target, higher shadows/effects and draw distance.

Device profiles must be measured, not assumed. Provide automatic preset detection with manual override.

Optimization:
- object pooling for coins, particles and repeated props;
- LODs for buildings and environment meshes;
- occlusion culling where beneficial;
- baked lighting for static scenes;
- limit real-time shadow casters;
- texture atlases and compressed textures;
- impostors/billboards for distant vegetation;
- instancing for repeated props;
- avoid excessive physics bodies;
- fixed physics timestep separated from render FPS;
- stream world chunks only when needed;
- loading screens with real progress signals;
- no huge uncompressed 4K textures on low-tier devices.

The developer must profile on the user's actual target devices before claiming acceptable performance. Do not require a high-end GPU for the core game.

---

# 13. Visual Art Direction

## 13.1 Overall style

Premium, clean, cinematic, realistic-stylized 3D. The hero drone should be detailed and tactile; environments may use a carefully balanced realistic/stylized approach to keep performance manageable.

## 13.2 UI language

- dark graphite panels with cyan/teal active accents;
- white telemetry text;
- high-contrast warning states;
- rounded but restrained panels;
- compact typography;
- no cluttered generic game UI;
- consistent spacing and iconography;
- hover tooltips on desktop and accessible labels on touch;
- day/night accessibility option;
- UI scaling and safe-area handling.

## 13.3 Main screens

1. Splash / boot.
2. Main menu.
3. World selection.
4. World details and mission selection.
5. Flight HUD.
6. Pause menu.
7. Mission result.
8. Drone garage.
9. Coin wallet / rewards.
10. Player profile / progression.
11. Real Location Explorer.
12. Settings.
13. Controller calibration.
14. Training Academy.
15. Credits / licences / privacy.

Every visible control must have a defined action, state, disabled condition and error state. No decorative dead buttons.

---

# 14. Audio and Feedback

- motor spool-up and spool-down;
- propeller hum varies with RPM;
- wind ambience;
- location-specific ambience;
- coin pickup sound;
- mission start/checkpoint/complete;
- warning tones;
- UI navigation;
- collision and landing;
- optional music with volume controls.

Use original or properly licensed audio. Provide master, music, SFX and ambience volume sliders. Respect mute and mobile audio focus.

---

# 15. Save Data and Reliability

Save:
- settings and input calibration;
- selected drone and cosmetics;
- XP and level;
- coin balance;
- world unlocks;
- mission completion and medals;
- best times;
- achievements;
- tutorial progress.

Requirements:
- versioned save schema;
- atomic save writes where possible;
- backup previous valid save;
- validate data before loading;
- recover gracefully from corrupt saves;
- no reward duplication after crash/restart;
- migration tests for schema changes;
- explicit reset-progress action with confirmation.

---

# 16. Accessibility and Localization

- remappable controls;
- stick sensitivity and deadzone;
- invert axes;
- color-safe warning icons (not color alone);
- subtitles for tutorial voice cues;
- scalable HUD;
- reduced motion option;
- audio sliders;
- English-first, Nepali-ready localization;
- use Unicode-capable fonts and test Nepali glyph shaping before release.

---

# 17. Security, Privacy and Licensing

- no secrets or API keys committed to Git;
- map-provider keys restricted by platform/referrer/application where supported;
- backend proxy only where needed; never expose privileged server keys;
- no location collection without permission and purpose disclosure;
- no hidden analytics;
- no external executable downloads inside the game;
- sanitize custom map/mission imports;
- validate save files and imported content;
- maintain third-party asset licence register;
- use only original, public-domain, CC-compatible or purchased assets with explicit rights;
- preserve required attributions;
- review each provider's terms before release.

---

# 18. Phased Implementation Plan

The phases are ordered so the team proves the difficult core before building a large content catalogue.

## Phase 0 — Repository and feasibility audit

Deliverables:
- inspect existing repository (if any);
- identify current engine/tool versions;
- check target export support;
- inspect hardware and build environment;
- document constraints and risks;
- confirm asset licences;
- create technical decision record.

Acceptance:
- build environment reproducible;
- target platforms and minimum specs written;
- no implementation rewrite before audit if an existing project is supplied.

## Phase 1 — Playable flight vertical slice

Build:
- original hero drone blockout/model;
- four animated propellers;
- gimbal camera;
- one simple test arena;
- twin-stick controller HUD;
- keyboard and gamepad input;
- take-off, hover, move, yaw, land;
- camera chase and FPV;
- basic collisions and reset.

Acceptance:
- drone responds continuously to all four axes;
- no scripted-position fake flight;
- controller and keyboard do not double-apply input;
- stable hover can be achieved;
- take-off and landing state transitions work;
- performance measured on target hardware.

## Phase 2 — Flight model and camera polish

Build:
- flight modes;
- configurable sensitivity/deadzone/expo;
- altitude hold and RTH;
- camera transitions and gimbal;
- motor audio and rotor response;
- battery drain and warning states;
- collision feedback.

Acceptance:
- each flight mode has measurably different tuning;
- RTH returns to home through a valid path or reports blocked state;
- camera switching is smooth;
- telemetry reflects actual simulation state.

## Phase 3 — Core game loop

Build:
- world selection;
- mission framework;
- coin pickups;
- XP and rewards;
- result screen;
- local save system;
- unlock progression;
- pause/resume.

Acceptance:
- a player can start, complete, fail, retry and exit a mission;
- rewards are granted exactly once;
- save survives app restart;
- no dead mission or reward controls.

## Phase 4 — Launch worlds and content

Build first:
1. Training Valley.
2. Butwal-inspired City.
3. Mountain Lake.

Each world includes:
- spawn pads;
- safe boundaries;
- landmarks;
- free flight;
- coin route;
- ring race;
- delivery or precision landing;
- ambient audio;
- mini-map metadata;
- low/balanced/high visual tiers.

Acceptance:
- every world card opens a real playable scene;
- every advertised mission is playable and completable;
- no placeholder buildings or empty map zones presented as finished content.

## Phase 5 — Real Location Explorer

Build:
- search UI;
- location result list;
- 2D map;
- provider abstraction;
- optional 3D map preview;
- GPS permission and manual fallback;
- attribution and usage notices;
- preview-only vs playable-world state.

Acceptance:
- map provider failure does not crash the game;
- search works without GPS permission;
- provider attribution remains visible;
- user can tell map preview from playable game;
- no claim of real-time drone camera imagery;
- Google integration is disabled until a valid key and billing setup are configured.

## Phase 6 — More worlds and advanced gameplay

Add:
- Lumbini;
- Pokhara;
- Kathmandu;
- Chitwan;
- Himalayan Base Camp;
- Desert City;
- Metro City;
- Medieval Town;
- Canyon;
- Moon;
- stunt mode;
- photo scavenger;
- more drone cosmetics.

Acceptance:
- content quality and performance remain consistent;
- each world has a distinct identity and original assets;
- all missions pass repeatability tests.

## Phase 7 — Desktop/mobile hardening

Build:
- Android touch optimization;
- Windows/Linux export;
- controller calibration;
- graphics presets;
- safe areas and aspect ratios;
- crash recovery;
- packaging and update process.

Acceptance:
- install/uninstall/upgrade tested;
- input works on supported devices;
- save migration tested;
- low-end preset is usable;
- app handles pause/resume and backgrounding correctly.

## Phase 8 — Multiplayer and creator tools (post-launch)

Only after offline game is stable:
- account identity and cloud save;
- multiplayer races;
- lobby and matchmaking;
- authoritative race result validation;
- custom course editor;
- import/export of safe mission packages;
- moderation/reporting;
- anti-cheat and abuse controls.

Do not promise multiplayer until server architecture, operating cost and abuse controls are funded and tested.

---

# 19. QA and Acceptance Matrix

## Flight
- each axis independently;
- combined-axis diagonal movement;
- hover stability;
- mode transitions;
- take-off/landing;
- collision response;
- reset;
- RTH;
- low battery;
- out-of-bounds;
- wind;
- pause/resume.

## Controller
- touchscreen;
- mouse/keyboard;
- gamepad;
- supported USB joystick;
- calibration;
- deadzone;
- inverted axes;
- screen rotation;
- small and large aspect ratios;
- OS safe areas.

## Game loop
- collect coin;
- miss coin;
- collect same coin twice;
- mission completion;
- mission failure;
- retry;
- app crash during reward;
- restart after reward;
- save corruption;
- migration.

## Map explorer
- valid search;
- empty search;
- network offline;
- provider quota/error;
- GPS denied;
- GPS unavailable;
- low accuracy;
- missing 3D coverage;
- attribution visibility;
- map preview vs playable world labels.

## Performance
- cold boot;
- world load;
- sustained 10-minute flight;
- dense city scene;
- particle-heavy coin pickup;
- thermal throttling on mobile;
- memory growth across repeated world changes.

Release gates:
- no critical crash or data-loss defect;
- no unearned reward duplication;
- no unusable controller layout;
- no unlicensed asset;
- no secret in repository;
- all advertised features tested on the target platform.

---

# 20. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Flight model feels fake | Core product failure | Build and tune vertical slice before world content |
| 3D worlds too heavy | Low FPS / memory pressure | LOD, baked light, instancing, tiered quality |
| Google Maps cost/terms | Unexpected expense or compliance issue | Optional adapter, usage limits, open-first fallback |
| Map coverage gaps | Selected location not playable | Preview-only and approximate-world labels |
| Scope too large | Delayed release | Three polished launch worlds, staged catalogue |
| Mobile controls cramped | Poor usability | Landscape-first HUD, safe-area tests |
| Coin exploit | Progression corruption | Idempotent rewards and save validation |
| Third-party asset misuse | Legal risk | Asset register and licence review |
| Multiplayer complexity | Operational burden | Post-launch only |
| Device performance unknown | Release failure | Profile on actual hardware early |

---

# 21. Definition of Done

A feature is done only when:
- it has working behavior, not just a visual mockup;
- normal, empty, loading, error and disabled states are handled;
- input and accessibility are considered;
- persistence is correct if the feature changes saved state;
- performance is measured where relevant;
- licences and attribution are recorded;
- tests cover meaningful invariants;
- the feature works on the target build;
- documentation describes actual behavior, not intended future behavior.

Never report a feature as implemented or tested unless the code exists and the relevant verification was actually run.

---

# 22. Recommended First Release Scope

**Release 1.0 should contain:**
- one high-quality original drone;
- complete twin-stick HUD;
- stable playable flight physics;
- Cine / Normal / Sport / Arcade modes;
- chase and FPV cameras;
- take-off, land, RTH and reset;
- 3 handcrafted worlds;
- 9–15 complete missions;
- coin collection, XP and unlocks;
- garage with cosmetic selection;
- local save;
- keyboard, touchscreen and gamepad support;
- settings and controller calibration;
- real-location 2D map search and optional 3D preview, clearly separate from game flight;
- Windows, Linux and Android builds after platform verification.

**Do not put in Release 1.0:**
- online multiplayer;
- live real drone video;
- unrestricted user-generated maps;
- global photorealistic game-world generation;
- real-money purchases;
- complex cloud accounts unless needed.

---

# 23. External Technical References

Use these official references during implementation and re-check current versions/terms before release:

- Godot Engine: https://godotengine.org/
- Godot documentation: https://docs.godotengine.org/
- Blender: https://www.blender.org/
- glTF: https://www.khronos.org/gltf/
- MapLibre GL JS: https://maplibre.org/maplibre-gl-js/docs/
- CesiumJS: https://cesium.com/learn/cesiumjs/
- Google Photorealistic 3D Tiles: https://developers.google.com/maps/documentation/tile/3d-tiles
- Google Map Tiles API policies: https://developers.google.com/maps/documentation/tile/policies
- Google Maps Platform pricing: https://developers.google.com/maps/billing-and-pricing/pricing
- OpenStreetMap tile usage policy: https://operations.osmfoundation.org/policies/tiles/
- OpenStreetMap copyright/attribution: https://www.openstreetmap.org/copyright
- Lumipad simulator reference: https://simulator.lumipaddrones.com/play/drone/
- Real Drone Simulator reference: https://www.realdronesimulator.com/

---

# 24. Final Product Contract

The game must feel like a drone simulator first and a rewarding exploration game second. Flight controls and physics are the foundation; world content, coins and stunts build the game loop around that foundation. Real-location maps are a separate visualization capability, not a shortcut for generating unlimited playable worlds.

**Build the flight vertical slice first. Prove the controls, physics, camera, performance and persistence. Then expand the world catalogue.**
