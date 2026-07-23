# Shopping project agent instructions

## Project contract

- Read `godot-codex.json` before running Godot or MCP diagnostics. It is the source of truth for the engine path, expected version, MCP endpoint, language, dimension, and test runner.
- Use Godot 4.7.1 and GDScript unless the user explicitly changes the technical direction.
- Keep the game strictly 2D unless a task explicitly calls for 3D.
- Every player-facing screen must support live Chinese (`zh_CN`) and English (`en`) switching. Use translation keys and `TranslationServer`; do not hardcode display text in gameplay or UI scripts.
- Preserve user changes and inspect `git status` before editing. Do not discard unrelated work.

## Authoring policy

- Prefer text edits for GDScript, shaders, configuration, tests, and simple scenes/resources.
- Prefer the Godot AI MCP for complex scene trees, Inspector properties, signals, animations, runtime input, logs, and screenshots.
- Treat Godot-generated `.tscn` and `.tres` files as source. Inspect their Git diff after editor or MCP changes.
- Never edit `.godot/`; it is generated cache state.
- Keep gameplay rules separate from presentation where practical so deterministic logic can be tested without rendering.
- Check both locales after changing UI copy, layouts, item names, dialogue, or validation messages; English text must not overflow layouts designed around Chinese copy.

## Required workflow

1. Inspect the relevant files, active Godot session, and current scene before changing anything.
2. Make one coherent, reviewable change at a time.
3. Run `pwsh -File tools/check.ps1` after code, scene, resource, or project-setting changes.
4. When the editor should be open, run `pwsh -File tools/check-mcp.ps1` or use the equivalent native Godot MCP reads.
5. For runtime changes, launch the relevant scene, inspect the runtime tree, capture a game screenshot, and read editor/game logs before declaring success.
6. Stop the test game after automated runtime checks.
7. Review `git diff --check`, `git diff`, and `git status` before handoff.

## Efficiency guardrails

- During iteration, use `tools/check.ps1 -ImportOnly` for an early parse/import gate, then `tools/check.ps1 -SkipImport -TestPath <test.gd>` for the affected GUT file. Run the unfiltered `tools/check.ps1` once before commit or handoff.
- If the Codex sandbox reports `CreateProcessAsUser`, duplicate `Path`/`PATH`, or denied Godot/GUT user-cache access, retry the exact project script once with sandbox escalation. Do not improvise alternate PowerShell, .NET process, or user-data paths.
- Use Godot MCP `api_manage` for engine API discovery before web search, and query a known runtime node or `game_eval` before dumping the complete UI tree.
- Synthetic MCP mouse dragging gets one probe. If `gui_is_dragging()` remains false, stop sending longer input sequences; validate state transitions with focused GUT tests or `game_eval`, then leave physical drag feel to the user.
- Discover deferred tools by filtering `ALL_TOOLS` by exact tool name first. Do not print descriptions for broad keyword matches.

## Quality gates

- A task is incomplete while import, parsing, GUT tests, or relevant runtime checks fail.
- Add focused GUT tests under `tests/` for deterministic gameplay and scene behavior.
- Do not treat a clean game log as sufficient when the editor log contains parse/load errors.
- Ask the user to judge subjective visual quality and interaction feel after automated checks pass.

## MCP lifecycle

- Launch the editor with `tools/start-editor.ps1`; it disables Godot AI telemetry and keeps MCP loopback-only.
- If Godot AI is configured but tools are absent, verify port 8000 and the editor plugin first. Start Godot before starting a new Codex task; Codex may need one restart to rediscover tools.
- Activate the intended editor session before writes when multiple Godot projects are open.
- After driving a running game, always read both editor and game logs.

## Vendored tooling

- Godot AI MCP: 3.0.5, commit `2313b6441ae605ee6cf49dd69f74cab30231da39`.
- GUT Godot 4.7 branch: 9.7.1, commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`.
- Migration documentation and a reusable copy template live in `docs/godot-codex-workflow.md` and `templates/godot-codex/`.
