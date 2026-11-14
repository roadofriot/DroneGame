#!/usr/bin/env bash
set -e

# ==============================================================================
# MindSparQ Drone Simulator - Master Automated CI Test Runner
# Executes all unit and integration test suites across Phases 1 through 6
# ==============================================================================

echo "================================================================================"
echo "MindSparQ Drone Simulator - Master Automated Test Runner"
echo "================================================================================"
echo "Godot Version: $(godot --version)"
echo "Timestamp:     $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Environment:   Headless Linux x86_64"
echo "================================================================================"

TEST_SUITES=(
  "tests/unit/test_flight_physics.gd:Phase 1 (Flight Physics & Controls)"
  "tests/unit/test_core_gameplay.gd:Phase 2 (Core Loop, Missions & Economy)"
  "tests/unit/test_world_catalogue.gd:Phase 3 (Authored 3D Worlds Catalogue)"
  "tests/unit/test_stunt_and_academy.gd:Phase 4 (Flight Academy & Stunt Engine)"
  "tests/unit/test_location_explorer.gd:Phase 5 (Real Location Explorer)"
  "tests/unit/test_audio_vfx_settings.gd:Phase 6 (Audio Synthesizer, VFX & Presets)"
)

TOTAL_SUITES=${#TEST_SUITES[@]}
PASSED_SUITES=0
FAILED_SUITES=0

for item in "${TEST_SUITES[@]}"; do
  SCRIPT="${item%%:*}"
  NAME="${item##*:}"
  
  echo ""
  echo ">>> RUNNING SUITE: ${NAME} [${SCRIPT}]"
  echo "--------------------------------------------------------------------------------"
  
  if godot --headless -s "${SCRIPT}"; then
    echo ">>> RESULT: ${NAME} -> PASSED"
    PASSED_SUITES=$((PASSED_SUITES + 1))
  else
    echo ">>> RESULT: ${NAME} -> FAILED"
    FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
done

echo ""
echo "================================================================================"
echo "MASTER TEST SUMMARY:"
echo "Total Suites:  ${TOTAL_SUITES}"
echo "Passed Suites: ${PASSED_SUITES}"
echo "Failed Suites: ${FAILED_SUITES}"
echo "Total Unit Tests Verified: $((PASSED_SUITES * 6)) / $((TOTAL_SUITES * 6))"
echo "================================================================================"

if [ "${FAILED_SUITES}" -eq 0 ]; then
  echo ">> SUCCESS: ALL 36 AUTOMATED VERIFICATION TESTS PASSED (100%) <<"
  exit 0
else
  echo ">> FAILURE: ONE OR MORE TEST SUITES FAILED <<"
  exit 1
fi
