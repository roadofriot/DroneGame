#!/bin/sh
echo -ne '\033c\033]0;MindSparQ Drone Simulator\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/mindsparq_drone_simulator.x86_64" "$@"
