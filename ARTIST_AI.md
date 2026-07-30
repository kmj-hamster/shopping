# Instructions for the artist's AI assistant

This file is the handoff contract for any AI assistant helping the artist on
macOS. Read `AGENTS.md`, `godot-codex.json`, and
`docs/cross-platform-art-collaboration.md` before changing the repository.

## Your role

- Help with imported artwork, 2D composition, UI Theme resources, animation,
  visual scene assembly, localization layout checks, and macOS playtesting.
- Preserve the established quiet, dreamlike night-mall direction: deep
  blue-green shadow, isolated warm/fluorescent light, translucent layers, and
  sparse text.
- Ask the human artist to judge composition, color, animation timing, and
  interaction feel. Automated success is not visual approval.
- Do not change gameplay rules, economy, task masks, item data, or state
  progression unless the user explicitly includes those changes in the task.

## Before editing

1. Run `git status --short --branch`. Never discard or overwrite changes you
   did not create.
2. Confirm Godot reports version **4.7.1**.
3. Pull the latest agreed branch before starting a new visual pass.
4. Determine which asset files and scenes you own for this pass. Do not edit a
   `.tscn` that another collaborator is actively modifying.
5. On macOS, do not replace the Windows path in `godot-codex.json`. Set a local
   executable instead:

   ```bash
   export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
   ```

## Asset and path rules

- Use `res://...` paths in Godot. Never write `/Users/...`, `file://...`, a
  Windows drive path, or a path containing backslashes into project source.
- Treat names as case-sensitive even if the current disk is not. `Map.png` and
  `map.png` are different resources. For a case-only rename, rename through a
  temporary filename with `git mv`.
- Keep runtime images in `pic/` or a deliberately agreed subfolder. Do not
  embed machine-local paths in scenes or resources.
- Commit a newly added source asset and the corresponding Godot `.import`
  metadata when Godot creates it. Never commit `.godot/`.
- Do not add `.DS_Store`, `._*`, exported apps, ZIPs, or `builds/`.
- Do not introduce Git LFS rules alone. Coordinate first; once LFS is enabled
  for everyone, use it for large PSD/Krita/Blender source files. GitHub rejects
  individual files above 100 MB.
- Preserve alpha, color profile, intended filtering, and pixel dimensions.
  Record intentional import-setting changes in the commit message.

## Scene and UI rules

- Prefer a dedicated visual child scene or resource over editing a large
  shared gameplay scene. This keeps text `.tscn` conflicts reviewable.
- Do not rename nodes that scripts access by name without coordinating with
  the gameplay developer.
- Keep all player-facing text behind translation keys. Check both `zh_CN` and
  `en`; English must not overflow a layout tuned for Chinese.
- The retired `PuzzleLab`/Polyomino prototype exists only at tag
  `polyomino-demo-v1`. Do not reintroduce its toolbox presentation into the
  player-facing game.

## Validation and handoff

Run before every commit:

```bash
./tools/check.sh
git diff --check
git diff
git status --short
```

For a visual change, also run the affected scene, capture screenshots in both
languages, inspect Godot's editor and game logs, stop the game, and ask the
artist for subjective approval.

Use a focused branch such as `art/shop-lighting` or `art/task-cards`. Make
small commits that describe the visual change. If Git reports a conflict in a
scene or resource, stop and coordinate instead of accepting one side wholesale.

For an internal macOS build, use:

```bash
./tools/export-macos.sh
```

Do not claim a build is publicly distributable merely because it launches.
Public distribution requires an Apple Developer identity and notarization.
