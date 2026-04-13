# Debug Watch Error Metadata Plan

## Goal

Add richer `error` events to `godot-bridge debug watch` so agents receive structured runtime failure context such as script path, line number, and error classification when available.

## Current State

- `debug watch` now receives runtime output through `ScriptEditorDebugger.output`.
- `error` events are currently inferred from output level and only include:
  - `message`
  - `script` = `""`
  - `line` = `0`
  - `timestamp`
- `EditorDebuggerPlugin._capture()` does not receive built-in `output` / `error` messages in the Godot 4.6 path used here.

## Questions To Answer

1. Which editor-side Godot object exposes structured runtime error information?
2. Is there a signal on `ScriptEditorDebugger`, `EditorDebuggerNode`, or a child error tree that includes file and line?
3. If no structured API exists, can the plugin reliably extract metadata from debugger UI state or message payloads without fragile UI scraping?
4. What error levels map cleanly to `output` vs `error` for this bridge?

## Investigation Steps

1. Inspect Godot source for:
   - `ScriptEditorDebugger::_msg_error`
   - `ADD_SIGNAL(...)` declarations near debugger error handling
   - any exposed error-selection, error-tree, or debug-data signals
2. Inspect the live editor object tree from plugin code to locate:
   - `ScriptEditorDebugger`
   - error list/tree widgets
   - methods or metadata attached to error rows
3. Confirm whether runtime script errors and warnings arrive on:
   - `output(msg, level)`
   - a separate `debug_data(msg, data)` signal
   - another accessible debugger node/signal
4. Reproduce three cases in `foobar`:
   - plain `print()`
   - runtime script error with file/line
   - warning-level message if available

## Implementation Plan

1. Prefer a structured signal/API path if available.
2. Extend plugin event payload shape for `error`:
   - `message`
   - `script`
   - `line`
   - `column` if available
   - `severity`
   - `timestamp`
3. Preserve existing output streaming behavior.
4. Keep fallback behavior when metadata is unavailable:
   - emit `message`
   - use empty/default metadata fields

## Tests

1. Add plugin tests for any new parsing/helper logic.
2. Add an end-to-end manual repro script or documented commands for:
   - scene run
   - runtime error trigger
   - `debug watch --events error --json`
3. Verify no regression to plain output streaming.

## Risks

- Godot may not expose structured error metadata to plugins.
- UI-tree scraping may be brittle across Godot versions.
- Error and warning semantics may differ across platforms and editor launch modes.

## Deliverable

A plugin change that emits structured `error` events when available, with a clear fallback path when not.
