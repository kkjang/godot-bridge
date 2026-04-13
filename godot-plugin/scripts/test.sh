#!/usr/bin/env bash
set -euo pipefail

: "${GODOT_BIN:=$(command -v godot4 || command -v godot)}"

"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd --quit
