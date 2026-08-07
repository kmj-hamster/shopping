# Shopping project agent instructions

## Project contract

- Read `godot-codex.json` before running Godot or MCP diagnostics. It is the source of truth for the engine path, expected version, MCP endpoint, language, dimension, and test runner.
- Use Godot 4.7.1 and GDScript unless the user explicitly changes the technical direction.
- Keep the game strictly 2D unless a task explicitly calls for 3D.
- Every player-facing screen must support live Chinese (`zh_CN`) and English (`en`) switching. Use translation keys and `TranslationServer`; do not hardcode display text in gameplay or UI scripts.
- Preserve user changes and inspect `git status` before editing. Do not discard unrelated work.
- For art collaboration or work performed on macOS, read `ARTIST_AI.md` and `docs/cross-platform-art-collaboration.md` before editing assets or scenes.

## Authoring policy

- Prefer text edits for GDScript, shaders, configuration, tests, and simple scenes/resources.
- Prefer the Godot AI MCP for complex scene trees, Inspector properties, signals, animations, runtime input, and focused log reads. Capture screenshots only when the user explicitly requests Codex-side visual evidence.
- Treat Godot-generated `.tscn` and `.tres` files as source. Inspect their Git diff after editor or MCP changes.
- Never edit `.godot/`; it is generated cache state.
- Keep gameplay rules separate from presentation where practical so deterministic logic can be tested without rendering.
- Verify both locale key sets after changing UI copy, item names, dialogue, or validation messages. The user owns visual review of wrapping, overflow, composition, and final presentation in both languages.

## Player-facing UI

- The archived `PuzzleLab`/Polyomino prototype exists only at tag `polyomino-demo-v1`; do not reintroduce its toolbox presentation or runtime classes into the slot-card branch.
- Player-facing screens should evoke a quiet, dreamlike shopping mall at night: deep blue-green shadows, isolated warm or fluorescent light, translucent layers, and restrained accent colors.
- Prefer spatial composition, object shapes, price tags, icons, and short status lines over instructional paragraphs. Keep persistent instructions to one short line at most; move secondary detail into tooltips or contextual feedback.
- Avoid developer-facing terms such as “实验室”, “工具箱”, “验证” and raw rule explanations in the formal game UI.
- Preserve full `zh_CN` / `en` support while checking that both languages keep the same sparse visual hierarchy.

## Required workflow

1. Inspect the relevant files, active Godot session, and current scene before changing anything.
2. Make one coherent, reviewable change at a time.
3. Choose validation by risk. Resource-path, asset-import, documentation, and small presentation-only edits use the fast gate: `tools/check.ps1 -ImportOnly` plus the single affected GUT file when one exists. Gameplay rules, runtime state, persistence, and release checkpoints use targeted tests during iteration and one full `tools/check.ps1` before handoff.
4. Use `tools/check-mcp.ps1` or native Godot MCP reads when editor state, scene structure, Inspector state, or runtime logs provide information that tests cannot provide efficiently.
5. Codex validates code, imports, deterministic behavior, and absence of parse/load/runtime errors. The user performs all visual composition, image quality, animation-timing, and interaction-feel validation.
6. Launch the game only when the changed behavior requires a runtime error check. Read editor/game logs after a Codex-driven run, then stop the test game. Skip screenshots and visual tree inspection unless the user asks for them.
7. Review `git diff --check`, the scoped Git diff, and `git status` before handoff.
8. On macOS, use `tools/check.sh`; use `tools/export-macos.sh` only on a clean, tested commit when a playable build is requested.

## Efficiency guardrails

- For a path or asset-reference change, search for the old path, edit references, run `tools/check.ps1 -ImportOnly`, then run the focused environment or portability test. A successful fast gate is sufficient for that change.
- During gameplay iteration, use `tools/check.ps1 -ImportOnly` for an early parse/import gate, then `tools/check.ps1 -SkipImport -TestPath <test.gd>` for the affected GUT file. Reserve the unfiltered `tools/check.ps1` for gameplay/state/save changes, broad refactors, release checkpoints, or an explicit user request.
- When one imported image fails, inspect that file once, preserve the source under `ref/` when conversion is appropriate, convert it to a Godot-supported runtime format, and rerun only the import gate. Stop and ask the user when the source is damaged or conversion changes visual content.
- If the Codex sandbox reports `CreateProcessAsUser`, duplicate `Path`/`PATH`, or denied Godot/GUT user-cache access, retry the exact project script once with sandbox escalation. Do not improvise alternate PowerShell, .NET process, or user-data paths.
- Use Godot MCP `api_manage` for engine API discovery before web search, and query a known runtime node or `game_eval` before dumping the complete UI tree.
- Synthetic MCP mouse dragging gets one probe. If `gui_is_dragging()` remains false, stop sending longer input sequences; validate state transitions with focused GUT tests or `game_eval`, then leave physical drag feel to the user.
- Give MCP one focused attempt for the desired information. When it returns no useful state, disconnects, or requires a long interaction sequence, stop and hand the remaining visual or physical check to the user.
- Discover deferred tools by filtering `ALL_TOOLS` by exact tool name first. Do not print descriptions for broad keyword matches.

## Quality gates

- A task is incomplete while its selected import, parsing, focused GUT, or relevant runtime error checks fail.
- Add focused GUT tests under `tests/` for deterministic gameplay and scene behavior.
- Do not treat a clean game log as sufficient when the editor log contains parse/load errors.
- Report the automated code checks that passed, then hand visual quality and interaction feel to the user without attempting a parallel visual verdict.

## MCP lifecycle

- Launch the editor with `tools/start-editor.ps1`; it disables Godot AI telemetry and keeps MCP loopback-only.
- If Godot AI is configured but tools are absent, verify port 8000 and the editor plugin first. Start Godot before starting a new Codex task; Codex may need one restart to rediscover tools.
- Activate the intended editor session before writes when multiple Godot projects are open.
- After driving a running game, always read both editor and game logs.

## Vendored tooling

- Godot AI MCP: 3.0.5, commit `2313b6441ae605ee6cf49dd69f74cab30231da39`.
- GUT Godot 4.7 branch: 9.7.1, commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`.
- Migration documentation and a reusable copy template live in `docs/godot-codex-workflow.md` and `templates/godot-codex/`.
