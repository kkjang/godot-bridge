# godot-bridge

AI-assisted Godot development with a small local toolchain:

- `gdscript-lsp-proxy` for GDScript LSP transport
- `godot-bridge` CLI for editor control through the Godot plugin
- a Godot editor plugin for scene and editor actions

This repository is meant to be used from actual game project repositories. The Godot editor can have a different project open than this repository checkout.

For coding-agent implementation guidance inside this repo, see `AGENTS.md`.

This README has two audiences:

- If you want to install Godot Bridge into your own game project, start at `Use In A Game Project`.
- If you are developing or releasing this repository itself, skip to `Develop The Bridge`.

## Use In A Game Project

### Bootstrap from a game project

These are the four setup steps an agent or user should follow when enabling Godot Bridge in a real game repository.

If you are working through an agent, you can point the agent directly at this section instead of manually performing each installation step yourself.

### 1. Install `gdscript-lsp-proxy`

Install the proxy onto `PATH`:

```bash
go install github.com/kkjang/godot-bridge/gdscript-lsp/cmd/gdscript-lsp-proxy@latest
gdscript-lsp-proxy --version
```

Notes:

- The proxy is an LSP stdio subprocess, not a background daemon.
- Your agent harness should launch it when `.gd` LSP support is needed.
- Godot must be running with the target game project open and its GDScript LSP exposed on port `6005` unless you override `GODOT_LSP_PORT`.

### 2. Install `godot-bridge`

Install the CLI onto `PATH`:

```bash
go install github.com/kkjang/godot-bridge/cli/cmd/godot-bridge@latest
godot-bridge version
```

The CLI talks to the Godot Bridge editor plugin over WebSocket on `127.0.0.1:6505` by default.

### 3. Install agent config and skills for your harness

Start with the included Claude and OpenCode integrations.

The reusable Godot Bridge skill lives in `skills/godot-bridge/SKILL.md`. Copy or adapt it into the target game project's harness-specific skill location however your agent expects skills to be loaded.

For safer live-editor workflows, process cleanup, and manual validation guidance, see `docs/godot-agent-workflow.md`.

**Claude Code**

Install the plugin from this repository checkout:

```bash
claude plugin install ./gdscript-lsp/integrations/claude
```

The Claude plugin now invokes `gdscript-lsp-proxy` from `PATH`.

**OpenCode**

Copy or merge `gdscript-lsp/integrations/opencode/opencode.json` into the root OpenCode config for your game project.

The repo-root `opencode.json` is also usable directly when working in this repository.

If your OpenCode setup uses skills, copy `skills/godot-bridge/SKILL.md` into one of OpenCode's discovered skill locations for the target game project.

### 4. Copy the Godot plugin into the game project

Copy `godot-plugin/addons/godot_bridge/` into the target game's `addons/` directory.

Example:

```bash
mkdir -p /path/to/game-project/addons
cp -R godot-plugin/addons/godot_bridge /path/to/game-project/addons/
```

Then enable **Godot Bridge** in **Project -> Project Settings -> Plugins**.

Wait until the bottom panel shows one of:

- `Bridge: Listening :6505`
- `Bridge: Connected (N)`
- `Bridge: Error (port 6505)`

If an agent is driving setup, it should pause here and wait for the user to confirm the plugin has been enabled.

Agents may optionally enable the plugin by editing `project.godot`, but that is less reliable than the UI flow and usually requires reopening the Godot editor before the plugin loads.

### Verify the setup

With Godot open on the game project and the plugin enabled:

```bash
godot-bridge status
godot-bridge editor state
```

If the plugin is reachable, `godot-bridge status` prints `connected`.

## Develop The Bridge

### Components

| Directory | What it is |
|-----------|------------|
| [`godot-plugin/`](godot-plugin/README.md) | Godot 4.x editor plugin exposing a WebSocket command server on `localhost:6505` |
| [`gdscript-lsp/`](gdscript-lsp/README.md) | Shared GDScript LSP bridge plus tool-specific integrations |
| [`cli/`](cli/README.md) | `godot-bridge` CLI (Go) for editor control through the plugin |

### Test all components

Run these from the repository root:

```bash
(cd cli && go test ./...)
(cd gdscript-lsp && go test ./...)
(cd godot-plugin && bash scripts/test.sh)
```

Notes:

- `cli/` uses Go unit tests.
- `gdscript-lsp/` uses Go unit tests.
- `godot-plugin/` uses a headless Godot test project in `godot-plugin/`.
- On macOS, if `godot` is not on `PATH`, point the plugin test runner at the app bundle binary:

```bash
(cd godot-plugin && GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/test.sh)
```

## Release The Bridge

### Release model

`cli/` and `gdscript-lsp/` are separate Go modules and should be versioned independently.

- CLI tags should use `cli/vX.Y.Z`
- Proxy tags should use `gdscript-lsp/vX.Y.Z`
- `go install ...@latest` works for bootstrap
- Pin `@vX.Y.Z` when you want a specific released version

### Release process

Releases are driven by `releases.yaml` on the default branch.

1. Open a small release PR.
2. Bump one or both versions in `releases.yaml`.
3. If the plugin release changes, update `godot-plugin/addons/godot_bridge/plugin.cfg` so its `version` matches `releases.yaml` without the leading `v`.
4. Merge only after the `CI` workflow passes.
5. After merge, the `Release` workflow runs only for successful `CI` runs on the default branch.
6. If a requested release does not already exist, the workflow creates:
    - a git tag for the module version
    - a GitHub Release with generated release notes

Examples:

- `cli: v0.2.0` produces tag `cli/v0.2.0`
- `gdscript-lsp: v0.1.1` produces tag `gdscript-lsp/v0.1.1`

The release workflow now generates component-scoped GitHub release notes from labeled PRs plus the previous same-component tag.

Release-note labels:

- `component: cli`
- `component: gdscript-lsp`
- `component: godot-plugin`

Shared PRs may carry more than one component label and can appear in more than one component release.

Recommended repository settings:

- Protect the default branch and require the `CI` workflow to pass before merging.
- Allow GitHub Actions to write repository contents so the release workflow can create tags and releases.

## Requirements

- Godot 4.3+
- Go 1.22+
