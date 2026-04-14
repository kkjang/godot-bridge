# Plan: Deferred 2D Game Capabilities

Part of the 2D game enablement series — see `docs/plans/2d-game-overview.md`.

## Context

While scoping the five near-term additions
(`docs/plans/2d-game-screenshot.md`, `2d-sprite-frames.md`, `2d-input-actions.md`,
`2d-autoloads.md`, `2d-import-config.md`), several additional gaps surfaced that would be
useful for certain 2D games but are either (a) too large to fit into the first pass, or
(b) not needed for the generic "simple 2D game" target.

This file catalogs those deferrals so they don't get lost. Each item notes when we'd
actually need it and a rough design sketch.

---

## 1. TileMap / TileSet authoring and tile painting

**When needed:** any tile-based game — platformers, top-down RPGs, dungeon crawlers. If the
first real game target uses tilemaps, this moves to top priority.

**Rough sketch:**
- `tileset_new` — create a TileSet resource from a source atlas PNG, given
  `{path, texture, tile_size, first_tile_coords?, tile_count?}`.
- `tilemap_paint` — apply `{layer, cells: [{x, y, source_id, atlas_coords}, ...]}` to a
  TileMap node. Batch call, not one RPC per tile.
- `tilemap_fill` — rectangle fill for large regions.
- Optionally `tilemap_autotile` — use Godot's terrain/autotile to fill a region with a
  named terrain.

**Estimated effort:** larger than any single item in the current five; probably its own
PR. TileSet has a lot of surface area (physics layers, occlusion, navigation, terrain
sets) and we'd want to pick the minimum viable subset.

---

## 2. AnimationTree / AnimationNodeStateMachine

**When needed:** games with non-trivial character animation blending (e.g. blended
walk/run, state machines across dozens of states). Simple games use a handful of
`AnimatedSprite2D.play("name")` calls instead.

**Rough sketch:** a `anim_tree_*` command group paralleling `animation_*`, operating on
`AnimationTree` resources, with nested codec support for state machines and blend
spaces.

**Status:** not needed for generic 2D. Revisit when a target game hits the pain.

---

## 3. Advanced AnimationPlayer tracks

The current `animation_*` commands handle value tracks. The following are missing:

- Method-call tracks (fire a method at a timestamp).
- Signal tracks (emit a signal at a timestamp).
- Bezier interpolation tracks (curve handles).
- Audio / animation / sub-animation tracks.

**When needed:** polish passes, cutscenes, audio-sync'd events.

**Status:** method tracks are the most likely first add, because they're how a lot of
tutorials wire "spawn hitbox at frame N" / "play sfx at frame M". Defer until concrete
demand.

---

## 4. Physics layer naming and configuration

`ProjectSettings` path `layer_names/2d_physics/layer_<N>` and friends. Today accessible via
`project_set` if the agent knows the key naming.

**Rough sketch:** a `physics_layer_*` command group that names 2D/3D physics, navigation,
and render layers and reflects them back to the agent.

**Status:** low urgency — `project_set` already works for this, just clunky.

---

## 5. CollisionShape2D / CollisionPolygon2D shape authoring

Collision shapes today have to be created as separate `Shape2D` resources (`RectangleShape2D`,
`CircleShape2D`, `ConvexPolygonShape2D`) and assigned via `node_modify`. The resource
creation step is the awkward part — there's no bridge command to mint a `Shape2D`
resource and save it.

**Rough sketch:** either (a) a small `shape2d_new` command that writes a `.tres`, or
(b) special-case coercion in `node_modify` so `{"shape": {"type": "rect", "size": [32, 16]}}`
builds an inline `RectangleShape2D` on the fly. Option (b) is ergonomically nicer.

**Status:** revisit when the first real game hits collision pain.

---

## 6. Script creation templates + parse validation

Today the agent writes `.gd` files via the filesystem. That works, but:

- No bridge-side helper for "new script extending `CharacterBody2D` with boilerplate".
- No way to ask "does this file parse?" short of running the game.

**Rough sketch:**
- `script_new --extends CharacterBody2D --path res://player.gd [--template movement_2d]`
- `script_validate --path res://player.gd` returns parse errors using
  `GDScript.reload()` or the GDScript LSP.

**Status:** the LSP proxy handles most real-time feedback; the bigger gap is
push-based diagnostics (item 7 below). Templates are nice-to-have, not blocking.

---

## 7. Push-based LSP diagnostics

Called out in `AGENTS.md` as the outstanding gap: pushed error/debug events from the
running game/editor back to the agent. `debug watch` covers the runtime side; LSP
diagnostics from the editor don't currently stream to the agent.

**Rough sketch:** the `gdscript-lsp-proxy` subscribes to Godot's
`textDocument/publishDiagnostics` notifications and surfaces them to a `diagnostics watch`
command shaped like `debug watch`.

**Status:** significant feature, separate plan. Pair with a `script_validate` helper for
synchronous lookups.

---

## 8. Custom `.tres` resource authoring beyond SpriteFrames

`bridge_sprite_frames_codec.gd` will be the template. Other commonly-authored resources
that might deserve their own codecs:

- `Theme` (for UI)
- `Curve` / `Gradient` (for particles, visuals)
- `PhysicsMaterial2D`
- `Shortcut`

**Status:** case-by-case. Add codecs as real games demand them rather than speculatively.

---

## 9. Headless one-shot test run

Today: `scene run` + `debug watch` + `scene stop`, orchestrated by the agent.

A convenience: `scene run-headless --scene res://test.tscn --timeout 10s` that runs
headless Godot, captures stdout/stderr/exit code, returns structured output as a single
RPC. Useful for CI-style validation loops.

**Status:** useful, but `debug watch` covers most of the value. Defer.

---

## Intake process

When a deferred item's "when needed" condition is met during real game development:

1. Promote to its own file under `docs/plans/` (same naming as the 2D series).
2. Link from the overview (`docs/plans/2d-game-overview.md`).
3. Remove from this file.
