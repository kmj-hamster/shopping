# Shopping project instructions

## Engine and language

- Use Godot 4.7.1 and GDScript for gameplay code unless the user explicitly requests another language.
- The default Windows editor binary is `D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.
- If `GODOT_BIN` is set, use that executable instead of the default path.
- Keep this game strictly 2D unless a task explicitly calls for 3D.

## Editing

- Prefer text edits for GDScript, shaders, configuration, and simple scenes/resources.
- Prefer the Godot AI MCP for complex scene-tree changes, Inspector properties, signals, animations, runtime input, logs, and screenshots.
- Treat Godot-generated `.tscn` and `.tres` files as source: inspect their Git diff after editor or MCP changes.
- Do not edit files under `.godot/`; they are generated cache files.

## Validation

- Run `pwsh -File tools/check.ps1` after code, scene, resource, or project-setting changes.
- When the Godot editor is expected to be open, run `pwsh -File tools/check-mcp.ps1` to verify the live editor bridge.
- A task is not complete while the import step, GUT tests, or relevant runtime checks fail.
- For visual or interaction changes, run the project, inspect logs and screenshots, then ask the user to judge subjective appearance and feel.
- Add focused GUT tests under `tests/` for deterministic gameplay logic and scene behavior.

## Tooling

- Godot AI MCP is vendored at version 3.0.5, commit `2313b6441ae605ee6cf49dd69f74cab30231da39`.
- GUT is vendored from its Godot 4.7 branch at version 9.7.1, commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`.
- Keep the MCP loopback-only and launch the editor with telemetry disabled via `tools/start-editor.ps1`.
