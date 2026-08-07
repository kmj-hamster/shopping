# Millennium Shopping Guide / 千禧年购物指南

A Godot 4.7.1 2D game prototype. The repository is designed for gameplay
development on Windows and art review/export on macOS without sharing Godot's
generated cache.

## Quick start

- Install **Godot 4.7.1**. Do not open the project with another engine version.
- Clone the repository and open `project.godot` in Godot.
- Wait for the first import to finish, then run the main scene with F6/F5.
- Windows verification: `pwsh -File tools/check.ps1`
- macOS verification: `./tools/check.sh`

## Collaboration documents

- Current and only gameplay/UI feature specification: [`docs/game-feature-design.md`](docs/game-feature-design.md)
- Human workflow: [`docs/cross-platform-art-collaboration.md`](docs/cross-platform-art-collaboration.md)
- Instructions for an artist's AI assistant: [`ARTIST_AI.md`](ARTIST_AI.md)
- Codex/Godot automation workflow: [`docs/godot-codex-workflow.md`](docs/godot-codex-workflow.md)
- Project-wide agent contract: [`AGENTS.md`](AGENTS.md)

Runtime art lives under `resources/`; visual references and source presentations
live under `ref/`. Godot scenes and resources are text source and are reviewed
through Git; `.godot/`, test reports, and exported builds are local-only.
