# Asset Licenses & Open Source Attribution

All assets, shaders, audio, scripts, and procedural generators utilized in **MindSparQ Drone Simulator** adhere strictly to open-source licenses (MIT, CC0, Apache 2.0, ODbL). Zero proprietary, pirated, or unlicensed third-party assets are incorporated.

---

## 1. Codebase & Simulation Scripts
* **License:** MIT License
* **Copyright:** © 2026 MindSparQ Development Team
* **Description:** 60Hz quadcopter flight physics, PID controllers, aerodynamic drag equations, input router abstraction, mission state machine, progression service, save service, stunt engine, and procedural location generator.

---

## 2. 3D Meshes, Models & Materials
* **Fuselage, Arms, Rotors & Gimbal:** Original procedural BoxMesh, CylinderMesh, PrismMesh, and TorusMesh constructs designed in Godot 4.3.
* **License:** Creative Commons Zero (CC0) / Public Domain.
* **Environment Geometry:** Original terrain plane meshes, architectural towers, highway bridges, launch helipads, and flight gate hoops.

---

## 3. Audio & SFX Waveforms
* **Synthesis Engine:** `scripts/audio/AudioDirector.gd`
* **Source:** 100% offline procedural mathematical PCM waveform synthesis (sine, square, pink noise, and exponential decay envelopes).
* **License:** Creative Commons Zero (CC0) / MIT.
* **Files:** Zero external MP3/WAV dependencies required; synthesized dynamically at runtime into 16-bit 22,050 Hz PCM streams.

---

## 4. Geographical Data & Map Context
* **Provider:** OpenStreetMap (OSM)
* **License:** Open Database License (ODbL) 1.0 (https://www.openstreetmap.org/copyright)
* **Attribution:** "Map data © OpenStreetMap contributors, ODbL 1.0. Cartographic offline rendering by MindSparQ."
* **Usage Policy Compliance:** Follows OSM caching, attribution, and usage policies. Does not bulk-download tile servers; uses offline landmark geocache and local procedural vector cartography.

---

## 5. Global Antigravity Skills Integration
* **threejs-game-skills:** MIT License (majidmanzarpour)
* **scenario-labs skills:** Apache 2.0 / MIT License (Scenario Labs)
* **3d-games skills:** MIT License (diegosouzapw)
* **GDevelop architecture:** MIT License (4ian/GDevelop)
* **GameDev-Resources directory:** CC0 / MIT License (Kavex)
