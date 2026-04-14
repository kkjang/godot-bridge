# Plan: SpriteFrames Authoring (`sprite_frames_*`)

Part of the 2D game enablement series — see `docs/plans/2d-game-overview.md`.

## Context

Frame-based 2D animation (walk/idle/attack loops) in Godot uses `AnimatedSprite2D` pointed
at a `SpriteFrames` resource. The existing `animation_*` commands only touch
`AnimationPlayer` value tracks, which is the wrong tool for sprite sheets.

Today the agent has to hand-write `.tres` files in Godot's text-resource format — easy to
get subtly wrong, expensive in tokens. The asset-pipeline plan
(`docs/plans/asset-pipeline-integration.md`) lists this as an unresolved option for
spritesheet integration. This plan makes it first-class.

## Design

Three commands on the plugin, one CLI subcommand group.

- `sprite_frames_new` — create a new `SpriteFrames` resource at `res://<path>.tres`.
  - Args: `{path, animations: [{name, speed, loop, frames: [{texture, region?, duration?}]}]}`.
  - `frames[i].texture` is a `res://...` path.
  - If `region` is supplied (`{x, y, w, h}`), the command wraps the texture in an
    `AtlasTexture` automatically, so a spritesheet can be sliced in one call.
  - `duration` maps to the per-frame duration field added to `SpriteFrames` in Godot 4.x.
- `sprite_frames_get` — read an existing `.tres` back as JSON (same shape as above).
  Used to round-trip / inspect / diff.
- `sprite_frames_modify` — replace or merge animations on an existing resource.
  - Args: `{path, animations: [...], mode: "replace" | "merge"}`; default `merge`.

Assigning the resource to a node stays in `node_modify`:

```
godot-bridge node modify /root/Main/Player \
  --props '{"sprite_frames": "res://player_frames.tres"}'
```

Resource coercion in `_coerce_value_for_property` (`bridge_server.gd:1254`) already
handles this — no separate "assign to node" command needed.

### Example end-to-end

```
# Slice a spritesheet into two animations in a single call
godot-bridge sprite-frames new res://art/player.tres --data '{
  "animations": [
    {
      "name": "idle",
      "speed": 6,
      "loop": true,
      "frames": [
        {"texture": "res://art/player_sheet.png", "region": {"x": 0,  "y": 0, "w": 16, "h": 16}},
        {"texture": "res://art/player_sheet.png", "region": {"x": 16, "y": 0, "w": 16, "h": 16}}
      ]
    },
    {
      "name": "walk",
      "speed": 10,
      "loop": true,
      "frames": [
        {"texture": "res://art/player_sheet.png", "region": {"x": 0,  "y": 16, "w": 16, "h": 16}},
        {"texture": "res://art/player_sheet.png", "region": {"x": 16, "y": 16, "w": 16, "h": 16}},
        {"texture": "res://art/player_sheet.png", "region": {"x": 32, "y": 16, "w": 16, "h": 16}},
        {"texture": "res://art/player_sheet.png", "region": {"x": 48, "y": 16, "w": 16, "h": 16}}
      ]
    }
  ]
}'
```

## Critical files

| File | Change |
|------|--------|
| `godot-plugin/addons/godot_bridge/bridge_sprite_frames_codec.gd` | **new** — JSON↔`SpriteFrames` (de)serialization. Models the shape of `bridge_animation_codec.gd`. |
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | Three handlers (`_cmd_sprite_frames_new`, `_cmd_sprite_frames_get`, `_cmd_sprite_frames_modify`) + dispatch entries. |
| `cli/cmd/godot-bridge/commands_extra.go` | New `runSpriteFrames` subcommand group; spec entries. |
| `cli/cmd/godot-bridge/main.go` | Register the new subcommand group with the dispatcher. |
| `skills/godot-bridge/SKILL.md` | Example using `sprite-frames new` + `node modify`. |
| `docs/plans/asset-pipeline-integration.md` | Update the "Spritesheets / 2D frame animation" section — Option B now first-class. |

## Patterns to reuse

- `bridge_animation_codec.gd` is the direct structural template for
  `bridge_sprite_frames_codec.gd` (one file per resource codec).
- Resource coercion in `bridge_server.gd:1254` handles `AnimatedSprite2D.sprite_frames`
  assignment via `node_modify`. No extra wiring.
- `ResourceSaver.save(frames, path)` for writing `.tres`.
- `EditorInterface.get_resource_filesystem().update_file(path)` afterward so the editor
  picks up the new file without a rescan (same approach as `_cmd_resource_reimport`).

## Verification

1. Produce a 4-frame 32x16 spritesheet PNG under `res://art/sheet.png`.
   `godot-bridge resource reimport res://art/sheet.png`.
2. `godot-bridge sprite-frames new res://art/player.tres --data '…'` using the example
   above.
3. `godot-bridge sprite-frames get res://art/player.tres` — JSON round-trips to input.
4. `godot-bridge node add AnimatedSprite2D --parent /root/Main`.
5. `godot-bridge node modify /root/Main/AnimatedSprite2D
   --props '{"sprite_frames": "res://art/player.tres", "animation": "walk", "autoplay": "walk"}'`.
6. `godot-bridge scene run` + `godot-bridge game screenshot` (from
   `docs/plans/2d-game-screenshot.md`) — the animated frame is rendering.
7. `cd cli && go test ./...` and `cd godot-plugin && bash scripts/test.sh`.
8. `godot-bridge spec --markdown` lists the new commands.
