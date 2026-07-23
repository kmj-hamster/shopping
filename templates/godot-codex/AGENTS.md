# Godot project agent instructions

## Project contract

- Read `godot-codex.json` before running Godot or MCP diagnostics. It is the source of truth for engine path, expected version, MCP endpoint, language, dimension, tests, and addon pins.
- Follow the configured language and dimension unless the user explicitly changes direction.
- Inspect `git status` before editing and preserve unrelated user changes.

## Authoring policy

- Prefer text edits for scripts, shaders, configuration, tests, and simple scenes/resources.
- Prefer Godot AI MCP for complex scene trees, Inspector properties, signals, animations, runtime input, logs, and screenshots.
- Treat `.tscn` and `.tres` as source and inspect their diff after editor/MCP changes.
- Never edit `.godot/`; it is generated cache state.
- Keep deterministic gameplay rules separate from presentation where practical.

## Required workflow

1. Inspect relevant files, the active Godot session, and current scene.
2. Make one coherent, reviewable change.
3. Run `pwsh -File tools/check.ps1` after source, scene, resource, or settings changes.
4. Verify the live bridge with `pwsh -File tools/check-mcp.ps1` or equivalent native MCP reads.
5. For runtime changes, run the relevant scene, inspect the runtime tree, capture a game screenshot, and read both editor and game logs.
6. Stop the test game after automated runtime checks.
7. Review `git diff --check`, `git diff`, and `git status` before handoff.

## Quality gates

- A task is incomplete while import, parsing, tests, or relevant runtime checks fail.
- Add focused GUT tests under `tests/` for deterministic logic and scene behavior.
- Ask the user to judge subjective visual quality and interaction feel after automated checks pass.

## MCP lifecycle

- Launch the editor through `tools/start-editor.ps1` to disable telemetry and keep MCP loopback-only.
- If MCP tools are absent, start Godot first and verify `tools/check-mcp.ps1`; Codex may need one restart to rediscover tools.
- Activate the intended editor session before writes when multiple projects are open.
