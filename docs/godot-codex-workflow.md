# Godot + Codex 可迁移工作流

这套工作流把 Godot 项目自动化分成四层，避免把可靠性押在单一 MCP 插件上：

1. **文本与 Git**：GDScript、Shader、配置、简单场景均作为普通源文件编辑和审查。
2. **Godot CLI**：负责版本校验、资源导入、脚本解析和无头测试。
3. **Godot AI MCP**：负责实时场景树、Inspector 属性、信号、动画、输入模拟、截图和日志。
4. **人工体验**：人只判断视觉、节奏、反馈强度和操作手感等主观指标。

## 目录约定

- `AGENTS.md`：项目内代理执行契约。
- `godot-codex.json`：机器和项目相关参数的唯一配置源。
- `tools/common.ps1`：配置加载与 Godot 路径解析。
- `tools/check.ps1`：版本、导入、解析和 GUT 测试总入口。
- `tools/start-editor.ps1`：关闭遥测后启动 Godot 编辑器。
- `tools/check-mcp.ps1`：不依赖 Codex 工具发现的 MCP 协议级健康检查。
- `tests/`：GUT 单元、场景和环境测试。
- `test-reports/`：运行产物，不提交 Git。

## 迁移到另一个项目

模板位于 `templates/godot-codex/`。迁移时：

1. 将模板中的 `AGENTS.md`、`godot-codex.json`、`.gutconfig.json`、`tools/` 和 `tests/` 复制到新项目根目录。
2. 编辑 `godot-codex.json`：至少填写 `project_name`、`godot.binary` 和 `godot.expected_version`。也可以将 `godot.binary` 留空，改用环境变量 `GODOT_BIN`。
3. 在新项目运行 `pwsh -File tools/install-addons.ps1`，安装模板固定的 Godot AI 与 GUT 版本。
4. 将 `project.godot.fragment` 的配置合并到项目的 `project.godot`。如果已有 `[autoload]` 或 `[editor_plugins]`，只合并键，不能创建重复 section。
5. 将 `gitignore.fragment` 合并进 `.gitignore`。
6. 在 Codex 全局配置中确认存在：

   ```toml
   [mcp_servers."godot-ai"]
   url = "http://127.0.0.1:8000/mcp"
   enabled = true
   ```

7. 执行 `pwsh -File tools/check.ps1`。
8. 执行 `pwsh -File tools/start-editor.ps1`，等待编辑器和插件启动。
9. 执行 `pwsh -File tools/check-mcp.ps1`。如果此时 Codex 任务中仍没有 Godot 工具，保持 Godot 开启并重启一次 Codex。

## 每次开发的固定循环

```text
检查 Git/场景/会话
  → 做一个可审查的小改动
  → CLI 导入与 GUT
  → MCP 启动目标场景
  → 读取运行时树并模拟输入
  → 截图
  → 同时检查 editor/game 日志
  → 停止游戏
  → 审查 Git diff
  → 交给用户判断视觉和手感
```

## 验证矩阵

| 变化类型 | 最低验证 |
|---|---|
| GDScript/配置 | `tools/check.ps1` |
| 场景/资源 | CLI 导入 + GUT 场景实例化测试 |
| 输入/交互 | MCP 运行场景 + 输入模拟 + 运行时树 |
| 视觉/UI | MCP 游戏截图 + editor/game 日志 + 人工体验 |
| 导出相关 | 上述全部 + 目标平台 debug export |

## 快速反馈回路

完整检查仍是提交前的质量门，但开发中不必每次都重复全部步骤：

```powershell
# 先确认资源导入和脚本解析
pwsh -File tools/check.ps1 -ImportOnly

# 只运行正在修改的测试文件，不重复导入
pwsh -File tools/check.ps1 -SkipImport -TestPath tests/test_example.gd

# 提交或交付前仍执行完整检查
pwsh -File tools/check.ps1
```

- 沙箱若出现 `CreateProcessAsUser`、`Path`/`PATH` 冲突或 GUT 用户缓存拒绝访问，立即用相同脚本申请一次沙箱外执行，不再尝试临时 PowerShell、进程封装或替代用户目录。
- Godot API 优先通过已连接编辑器的 MCP API 查询；运行时优先读取已知节点或使用 `game_eval`，不要默认导出完整 UI 树。
- MCP 合成鼠标只做一次拖动探测。若 Godot 没有进入 GUI drag 状态，改用聚焦的 GUT／`game_eval` 验证状态机，把真实鼠标手感交给用户。

## 故障恢复顺序

1. `tools/check.ps1` 失败：先修解析、导入或测试，不启动运行时调试。
2. 8000 端口未监听：确认 Godot 编辑器已用 `tools/start-editor.ps1` 启动且 Godot AI 插件已启用。
3. MCP 服务存在但无编辑器 session：重载插件或重启 Godot。
4. Codex 看不到工具但 `tools/check-mcp.ps1` 成功：保持 Godot 开启，重启 Codex 任务/应用。
5. 游戏日志干净但无法启动：检查 editor 日志；启动期解析错误可能早于游戏 logger。
6. 截图过期或超时：让游戏窗口恢复前台后重试。

## 升级原则

- Godot、Godot AI 和 GUT 都固定版本与 commit；升级必须单独提交。
- 升级后依次执行 CLI 检查、MCP 连接、场景写入、运行、截图和日志检查。
- 不在功能开发提交里顺便升级工具。
- `addons/` 中的第三方代码不做项目定制；定制逻辑放在项目自己的脚本和工具中。
