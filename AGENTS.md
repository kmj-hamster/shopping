# Shopping project agent instructions

## Project contract

- Read `godot-codex.json` before running Godot or MCP diagnostics. It is the source of truth for the engine path, expected version, MCP endpoint, language, dimension, and test runner.
- Use Godot 4.7.2 and GDScript, and keep the game strictly 2D, unless the user explicitly changes the technical direction.
- Every player-facing screen must support live Chinese (`zh_CN`) and English (`en`) switching. Use translation keys and `TranslationServer`; do not hardcode display text in gameplay or UI scripts.
- Preserve user changes and inspect `git status` before editing. Never discard unrelated work.
- Before art collaboration or asset/scene work on macOS, read `ARTIST_AI.md` and `docs/cross-platform-art-collaboration.md`.

## Current prototype policy

- The current implementation, executable tests, current data under `data/quest_arc/`, and the user's latest direction are authoritative. Archived design documents are historical reference, not requirements.
- This is a self-test prototype: old saves are disposable. Do not add save migrations, compatibility aliases/loaders, legacy save fixtures, or backward-compatibility tests. Update current data and tests directly; clear the development save before runtime checks and isolate/erase test saves before and after each test. Reintroduce compatibility work only when the user explicitly requests it.
- The archived `PuzzleLab`/Polyomino prototype exists only at tag `polyomino-demo-v1`; do not reintroduce its toolbox presentation or runtime classes into the slot-card branch.

## Authoring and assets

- Prefer text edits for GDScript, shaders, configuration, tests, and simple scenes/resources. Use Godot MCP for complex scene trees, Inspector properties, signals, animations, runtime input, and focused log reads.
- Treat Godot-generated `.tscn` and `.tres` files as source and inspect their Git diff. Never edit `.godot/`.
- Keep deterministic gameplay rules separate from presentation where practical.
- After changing player-facing copy, item names, dialogue, or validation messages, verify both locale key sets. The user owns final visual review of wrapping, composition, image quality, animation timing, and interaction feel.

### Image generation and placement

1. Before editing, inspect the source image's dimensions, pixel format, real alpha/corner pixels, existing references, and intended runtime size/import path.
2. For flat swatches, geometric icons, recolors, and repo-native vector art, use deterministic SVG or source edits. Do not call image generation.
3. Use image generation only when the raster subject or illustration must change. View the input first and make one constrained edit request that states the subject, composition, dimensions, and background requirement. When transparency is needed, request a flat chroma background from the start rather than a checkerboard or transparency-like background.
4. Put the generated result in a project-local temporary path and verify its actual dimensions, format, and corner pixels before processing it. Remove a chroma key with an installed deterministic helper, inspect the keyed result, then resize once to the final dimensions. If soft matte/despill damages complementary subject colors, stop and retry with a sampled hard key; do not regenerate the artwork.
5. Inspect the final asset once, move only the final runtime file into `resources/`, remove intermediates, update references, and run the import gate. Keep source material and Godot import metadata intact.

## Player-facing UI

- Preserve the quiet, dreamlike night-mall direction: deep blue-green shadows, isolated warm or fluorescent light, translucent layers, and restrained accents.
- Prefer spatial composition, object shapes, price tags, icons, and short status lines over instructional paragraphs. Keep persistent instructions to one short line at most.
- Avoid developer-facing terms such as “实验室”, “工具箱”, “验证”, and raw rule explanations in formal game UI.
- Keep the same sparse visual hierarchy in both supported languages.

## Validation workflow

1. Inspect the relevant files, active Godot session, and current scene before changing anything.
2. Make one coherent, reviewable change at a time and choose validation by risk:
   - Documentation-only edits: review the diff; no engine run is required.
   - Resource paths, asset imports, and small presentation-only edits: run `tools/check.ps1 -ImportOnly`, plus the single affected GUT file when one exists.
   - Gameplay rules, runtime state, persistence, broad refactors, and release checkpoints: run targeted tests during iteration and one full `tools/check.ps1` before handoff.
3. Use MCP only when editor state, scene structure, Inspector state, runtime input, or logs provide information more efficiently than tests. Give it one focused attempt; give synthetic mouse dragging one probe, then hand physical interaction feel to the user.
4. Launch the game only when the changed behavior needs a runtime error check. After a Codex-driven run, read editor and game logs and stop the game. Capture screenshots only when the user explicitly requests Codex-side visual evidence.
5. If the sandbox reports `CreateProcessAsUser`, duplicate `Path`/`PATH`, or denied Godot/GUT cache access, retry the exact project script once with sandbox escalation.
6. A task is incomplete while its selected import, parse, focused GUT, runtime, or full-suite check fails. Before handoff, review `git diff --check`, the scoped diff, and `git status`.
7. On macOS use `tools/check.sh`; use `tools/export-macos.sh` only for a requested playable build from a clean, tested commit.
