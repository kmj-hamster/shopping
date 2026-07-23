# Godot + Codex workflow template

复制本目录内容到一个 Godot 4.7.1 项目根目录（不要复制父目录
`templates/.gdignore`），然后：

1. 修改 `godot-codex.json`。
2. 运行 `pwsh -File tools/install-addons.ps1`。
3. 合并 `project.godot.fragment` 和 `gitignore.fragment`。
4. 运行 `pwsh -File tools/check.ps1`。
5. 运行 `pwsh -File tools/start-editor.ps1`，再运行 `pwsh -File tools/check-mcp.ps1`。

完整设计、日常循环和故障恢复见项目中的 `docs/godot-codex-workflow.md`。

日常固定顺序是：编辑 → `tools/check.ps1` → MCP 运行目标场景 →
运行时树/截图/editor+game 日志 → 停止游戏 → Git diff → 人工体验。
