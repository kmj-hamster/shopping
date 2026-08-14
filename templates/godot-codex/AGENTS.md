# Godot project agent instructions

## Project contract

- Read `godot-codex.json` before Godot or MCP work. Treat it as the source of truth for the engine path, expected version, MCP endpoint, language, dimension, and test runner.
- Follow the project's declared language and 2D/3D direction unless the user explicitly changes them.
- Preserve user changes, inspect `git status` before editing, and never edit `.godot/`.
- If the project supports multiple locales, use translation keys and verify every supported locale after changing player-facing text.
- Treat save backward compatibility as an explicit product requirement, not an assumption. Do not invent migrations, legacy fixtures, or compatibility tests unless the project contract or user requires them.

## Authoring and assets

- Prefer text edits for scripts, shaders, configuration, tests, and simple scenes/resources. Use Godot MCP for complex scene trees, Inspector properties, signals, animations, runtime input, and focused log reads.
- Treat `.tscn` and `.tres` files as source and inspect their Git diff after editor or MCP writes.
- Keep deterministic gameplay rules separate from presentation where practical.
- For image work, first inspect source dimensions, pixel format, alpha/corner pixels, references, and target size. Use deterministic SVG/source edits for flat colors, geometry, recolors, and vector art. Use image generation only for a changed raster subject, with one constrained request and an explicit flat chroma background when transparency is required. Validate the generated pixels before processing, key and resize deterministically, inspect the final asset once, remove intermediates, then run the import gate.

## Validation workflow

1. Inspect relevant files, the active editor session, and the current scene before editing.
2. Make one coherent change at a time and validate by risk:
   - Documentation-only edits: review the diff; no engine run is required.
   - Resource paths, asset imports, and small presentation-only edits: run the configured import gate and the single affected test when one exists.
   - Gameplay rules, runtime state, persistence, broad refactors, and release checkpoints: run targeted tests during iteration and the configured full check before handoff.
3. Use MCP only for editor-specific information that tests or text inspection cannot provide efficiently. Give a failed or unhelpful query one focused attempt rather than expanding into long exploratory sequences.
4. Launch the game only when the change needs a runtime error check. Read editor and game logs afterward, stop the game, and capture screenshots only when the user explicitly requests visual evidence.
5. A task is incomplete while its selected import, parse, test, or runtime check fails. Review `git diff --check`, the scoped diff, and `git status` before handoff.

## Collaboration boundary

- Codex validates imports, code, deterministic behavior, and the absence of parse/load/runtime errors.
- The user owns final visual composition, image quality, animation timing, and physical interaction feel.
