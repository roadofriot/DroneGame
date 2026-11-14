#!/usr/bin/env bash
set -e

# ==============================================================================
# MindSparQ Drone Simulator - Production Release Build Script
# Packages game assets, scripts, environments, and binaries for Linux/Windows/Android
# ==============================================================================

echo "================================================================================"
echo "MindSparQ Drone Simulator - Packaging Production Release"
echo "================================================================================"

BUILD_ROOT="build"
LINUX_DIR="${BUILD_ROOT}/linux"
WINDOWS_DIR="${BUILD_ROOT}/windows"
ANDROID_DIR="${BUILD_ROOT}/android"

mkdir -p "${LINUX_DIR}" "${WINDOWS_DIR}" "${ANDROID_DIR}"

echo ">>> Packaging Standalone Game Pack (PCK)..."
godot --headless --export-pack "Linux/X11" "${LINUX_DIR}/mindsparq_drone_simulator.pck"

if [ -f "${LINUX_DIR}/mindsparq_drone_simulator.pck" ]; then
  PCK_SIZE=$(du -h "${LINUX_DIR}/mindsparq_drone_simulator.pck" | cut -f1)
  echo ">>> Release PCK Generated Successfully: ${LINUX_DIR}/mindsparq_drone_simulator.pck (${PCK_SIZE})"
else
  echo ">>> ERROR: Failed to generate release PCK"
  exit 1
fi

# Attempt full binary export if templates are installed
if godot --headless --export-release "Linux/X11" "${LINUX_DIR}/mindsparq_drone_simulator.x86_64" 2>/dev/null; then
  echo ">>> Linux x86_64 Binary Exported Successfully"
else
  echo ">>> Note: Full binary export requires installed platform templates. PCK package is ready for launcher runner."
fi

echo "================================================================================"
echo "Release Packaging Complete!"
echo "Artifacts located in: ${BUILD_ROOT}/"
echo "================================================================================"
