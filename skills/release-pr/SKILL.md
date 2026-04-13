---
name: release-pr
description: Draft small release PRs with strict path-only component changelog sections
---

## What I do

- Prepare small release PRs driven by `releases.yaml`.
- Draft PR descriptions using strict path-only changelog sections for each bumped component.
- Keep release PRs focused on intentional version bumps and release-related notes.

## When to use me

Use this skill when the user asks to:

- cut a release PR
- prepare a release PR
- bump a component version in `releases.yaml`
- draft release notes for `cli`, `gdscript-lsp`, or `godot-plugin`

## Workflow

1. Read `releases.yaml` and identify the bumped component versions.
2. For each bumped component, find the previous same-component tag:
   - `cli/vX.Y.Z`
   - `gdscript-lsp/vX.Y.Z`
   - `godot-plugin/vX.Y.Z`
3. Build a changelog range from the previous same-component tag to `HEAD`.
4. Draft changelog sections using only commits that touched the component path:
   - `cli/**`
   - `gdscript-lsp/**`
   - `godot-plugin/**`
5. Open a small PR that contains the version bump and a concise release summary.

## Changelog rules

- Use strict path-only filtering for v1.
- Do not include shared-file changes such as `.github/**`, root `README.md`, root `AGENTS.md`, or `skills/**` unless the user explicitly asks for them.
- Prefer concise summary bullets over raw commit dumps.
- If a component has no path-matching commits since its last tag, call that out explicitly instead of inventing release notes.

## Output shape

Use a PR body like this:

```md
## Summary
- bump `godot-plugin` to `v0.1.1`
- describe the user-visible reason for the release

## Changelog
### godot-plugin v0.1.1
- concise bullet summarizing path-scoped changes under `godot-plugin/**`
- concise bullet summarizing path-scoped changes under `godot-plugin/**`

## Testing
- release manifest bump only
```

For multi-component release PRs, include one changelog subsection per bumped component.

## Notes

- This skill improves release PR drafting only.
- The GitHub `Release` workflow may still publish repo-wide generated notes until the release automation is upgraded separately.
