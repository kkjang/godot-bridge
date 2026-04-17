#!/usr/bin/env bash
set -euo pipefail

: "${GODOT_BIN:=$(command -v godot4 || command -v godot || true)}"

if [ -z "$GODOT_BIN" ]; then
  printf 'Godot binary not found; set GODOT_BIN\n' >&2
  exit 1
fi

editor_log=$(mktemp)
project_backup=$(mktemp)
cleanup() {
  if [ -n "${editor_pid:-}" ] && kill -0 "$editor_pid" 2>/dev/null; then
    kill "$editor_pid" 2>/dev/null || true
    wait "$editor_pid" 2>/dev/null || true
  fi
  if [ -f "$project_backup" ]; then
    cp "$project_backup" project.godot
  fi
  rm -f "$editor_log"
  rm -f "$project_backup"
}
trap cleanup EXIT

cp project.godot "$project_backup"

"$GODOT_BIN" --headless --editor --path . --quit-after 2400 >"$editor_log" 2>&1 &
editor_pid=$!

rc=0
output=$("$GODOT_BIN" --headless --path . --script res://tests/run_editor_integration.gd 2>&1) || rc=$?
printf '%s\n' "$output"

if [ "$rc" -ne 0 ]; then
  printf '%s\n' "--- editor log ---"
  cat "$editor_log"
  exit "$rc"
fi

if printf '%s\n' "$output" | grep -qE '^(ERROR|SCRIPT ERROR):'; then
  printf 'Godot errors detected in editor integration output — treating as failure\n' >&2
  printf '%s\n' "--- editor log ---"
  cat "$editor_log"
  exit 1
fi
