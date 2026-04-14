# Plan: Input Actions (`input_action_*`)

Part of the 2D game enablement series — see `docs/plans/2d-game-overview.md`.

## Context

Every game needs input. `InputMap` is stored under `input/<action_name>` keys in
`ProjectSettings` as nested dictionaries containing `InputEvent` objects. Driving this
through the existing `project_set` command requires the agent to know the exact
serialization of `InputEventKey`, `InputEventJoypadButton`, `InputEventMouseButton`, etc.,
and to get deadzone/events-list wiring right.

A dedicated command collapses it to a clean schema and keeps the fragile serialization
inside GDScript.

## Design

Four commands, one CLI subcommand group.

- `input_action_list` — returns `[{name, deadzone, events: [...]}]` covering every
  `input/*` action currently defined.
- `input_action_add` — args: `{name, deadzone?, events: [...]}`. Errors if the action
  already exists (use `modify` to replace).
- `input_action_modify` — same shape as `add`, replaces the existing action in place.
- `input_action_delete` — args: `{name}`.

### Event schema

Compact, type-tagged JSON. The plugin translates to real `InputEvent*` instances.

| Type | JSON shape |
|------|------------|
| Key | `{"type": "key", "keycode": "Space", "physical": false?, "ctrl": false?, "shift": false?, "alt": false?, "meta": false?}` |
| Mouse button | `{"type": "mouse_button", "button_index": 1}` |
| Joypad button | `{"type": "joy_button", "button_index": 0}` |
| Joypad axis | `{"type": "joy_motion", "axis": 0, "axis_value": 1.0}` |
| Mouse motion | (not supported in v1) |

`keycode` is a `Key` enum name (`"Space"`, `"W"`, `"Enter"`). The plugin parses via
`OS.find_keycode_from_string()` with a fallback to direct enum lookup.

### Writeback semantics

- Uses `ProjectSettings.set_setting("input/<name>", {"deadzone": ..., "events": [...]})`
  with real `InputEvent` instances inside `events` — exactly the shape that Godot itself
  writes when the InputMap UI is edited.
- Calls `ProjectSettings.save()` after each mutation.
- Also refreshes the live `InputMap` so a running game (if any) reflects the change
  without a restart: `InputMap.erase_action(name)` + `add_action` + `action_add_event`.

## Critical files

| File | Change |
|------|--------|
| `godot-plugin/addons/godot_bridge/bridge_input_actions.gd` | **new** — InputEvent (de)serialization + `InputMap` refresh helper. |
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | Four handlers + dispatch entries. |
| `cli/cmd/godot-bridge/commands_extra.go` | New `runInputAction` subcommand group and spec entries. |
| `cli/cmd/godot-bridge/main.go` | Register the subcommand group. |
| `skills/godot-bridge/SKILL.md` | Short example: defining `jump`, `move_left`, `move_right`. |

## Patterns to reuse

- `BridgeProjectSettings.read_settings` (`bridge_project_settings.gd:6`) for the
  `input/` prefix scan inside `input_action_list`.
- `_send_ok` / `_send_error` dispatch shape.
- `reorderFlags` + `flag.NewFlagSet` pattern from `commands_extra.go:44`.

## Verification

1. `godot-bridge input action add --data '{
     "name": "jump",
     "events": [{"type": "key", "keycode": "Space"}]
   }'`
2. `godot-bridge input action list` includes `jump`.
3. `godot-bridge project get --keys input/jump` shows a dictionary with a single key event.
4. Write a tiny script using `Input.is_action_pressed("jump")` and wire it to a node.
5. `godot-bridge scene run` + manual keypress verification (or automated via a test scene
   that exits on `jump`).
6. `godot-bridge input action modify --data '{
     "name": "jump",
     "events": [
       {"type": "key", "keycode": "Space"},
       {"type": "joy_button", "button_index": 0}
     ]
   }'` — both bindings register.
7. `godot-bridge input action delete --name jump` — `input/jump` disappears from
   ProjectSettings.
8. `cd cli && go test ./...` and `cd godot-plugin && bash scripts/test.sh`.
9. `godot-bridge spec --markdown` lists the new commands.
