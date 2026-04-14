# Plan: Bridge Additions to Enable Full 2D Game Creation

## Context

The godot-bridge has a solid foundation: scene/node CRUD, signal wiring, AnimationPlayer
value-track animation, project settings, resource list+reimport, debug watch (structured
output/error events), and a 2D editor-viewport screenshot. The asset pipeline
(`docs/plans/asset-pipeline-integration.md`) is also in place for getting external art
into the project.

The next step is to actually build a real 2D game through the bridge with a coding agent
driving. After exploring the plugin, CLI, LSP bridge, and existing plan docs, the high-level
picture is:

- **Art ingest is mostly covered.** Agents generate PNGs/.glb externally, write to `res://`,
  call `resource reimport`, and assign via `node_modify` with resource coercion.
- **Animation is half-covered.** `animation_*` handles AnimationPlayer value tracks. The
  dominant 2D pattern — `AnimatedSprite2D` + `SpriteFrames` — is not addressed.
- **Game logic plumbing is mostly missing.** Input actions, autoloads, and physics-layer
  config nominally work through `project_get/set`, but the schemas are nested enough that
  doing it through raw `project_set` burns tokens and invites mistakes.
- **The feedback loop is weak for visuals.** `screenshot` only captures the editor's 2D
  viewport, not the running game — so agents can't visually verify gameplay.

## The five additions

Rather than a broad wish list, we're landing the five highest-leverage additions that
unlock "make a generic 2D game" from the current state. Each has its own detailed plan:

1. **`docs/plans/2d-game-screenshot.md`** — Running-game screenshot (`game_screenshot`).
   Visual verification of the actual running game, not just the editor viewport.
2. **`docs/plans/2d-sprite-frames.md`** — SpriteFrames authoring (`sprite_frames_*`).
   Frame-based animation resources for `AnimatedSprite2D`.
3. **`docs/plans/2d-input-actions.md`** — Input actions (`input_action_*`). Typed CRUD for
   InputMap entries so controls don't go through raw nested `project_set`.
4. **`docs/plans/2d-autoloads.md`** — Autoload management (`autoload_*`). Add/remove
   singleton autoloads without round-tripping through `ProjectSettings` keys.
5. **`docs/plans/2d-import-config.md`** — Import config helper (`import_config_*`).
   Principally for `filter=false` on pixel-art textures; works for any `.import` setting.

And a companion survey of things we're intentionally not doing yet:

6. **`docs/plans/2d-game-deferred.md`** — Deferred capabilities (TileMap painting, animation
   state machines, push LSP diagnostics, etc.). Parked for later investigation.

## Suggested ordering

The five additions are independent enough to land in any order, but the useful prototyping
order is:

1. `game_screenshot` — lands a visual feedback loop first; every later plan verifies with it.
2. `sprite_frames` — unlocks frame animation, the most commonly needed 2D art piece.
3. `input_actions` + `autoloads` — these are small and independent; pair them.
4. `import_config` — lowest urgency; matters once the art starts looking wrong.

## Patterns to reuse across all five

- `bridge_animation_codec.gd` is the template for new resource codecs.
- `BridgeProjectSettings.read_settings` (`bridge_project_settings.gd:6`) for prefix scans.
- Resource coercion in `_coerce_value_for_property` (`bridge_server.gd:1254`) already
  assigns `.tres` resources via `node_modify`, so authoring plans don't need separate
  "assign to node" commands.
- `_send_ok` / `_send_error` dispatch in `bridge_server.gd`.
- `reorderFlags` + `flag.NewFlagSet` pattern in `cli/cmd/godot-bridge/commands_extra.go:44`
  for each new CLI subcommand group.
- `godot-bridge spec` auto-documents new subcommands when registered through the spec
  table — every new CLI command must add a spec entry.
