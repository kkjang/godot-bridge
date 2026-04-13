#!/usr/bin/env bash
set -euo pipefail

: "${GODOT_BIN:=$(command -v godot4 || command -v godot)}"

rc=0
output=$("$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd 2>&1) || rc=$?
printf '%s\n' "$output"

if [ "$rc" -ne 0 ]; then
  exit "$rc"
fi

# Fail if Godot printed any script or engine errors even though the test
# runner exited 0 (e.g. broken preloads whose load() still returned
# non-null, or runtime "Invalid call" messages that the harness missed).
if printf '%s\n' "$output" | grep -qE '^(ERROR|SCRIPT ERROR):'; then
  printf 'Godot errors detected in test output — treating as failure\n' >&2
  exit 1
fi
