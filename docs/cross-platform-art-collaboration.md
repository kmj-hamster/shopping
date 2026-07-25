# Windows + macOS 美术协作流程

本项目允许程序开发者在 Windows 上工作，美术在 macOS 上直接打开同一份
Godot 工程。双方只通过 Git 共享源文件，不共享 `.godot/` 导入缓存，也不把
导出的应用包提交进仓库。

## 1. 固定环境

- 引擎：Godot **4.7.1**。
- 项目语言：GDScript，纯 2D。
- 仓库：`https://github.com/kmj-hamster/shopping.git`。
- Mac 建议安装官方 Universal 版 Godot 及同版本 Export Templates；Steam 版也
  可以，但仍须确认完整版本号为 4.7.1。
- Mac 第一次打开 `project.godot` 时会重建 `.godot/`，这是正常过程。

Mac 终端快速检查：

```bash
git clone https://github.com/kmj-hamster/shopping.git
cd shopping
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
./tools/check.sh
```

`tools/common.sh` 也会自动寻找官方安装、用户 Applications 目录和 Steam 的
常见安装位置。如果仍找不到，再设置 `GODOT_BIN`。仓库中的
`godot-codex.json` 保留 Windows 开发机路径；它不会被游戏加载，Mac 不需要
修改它。

## 2. 分支与文件所有权

每次视觉任务使用独立分支，例如：

```bash
git switch -c art/flower-shop-lighting
```

开始前约定场景所有权：同一时间只让一人修改某个大型 `.tscn`。推荐把视觉
内容拆成独立子场景、Theme 或资源文件，再由程序侧接入。这样可以避免把
Godot 文本场景冲突变成“二选一”。

一个安全的美术提交通常包含：

- 新增或修改的 PNG/SVG/字体/音频；
- 对应的 Godot `.import` 元数据；
- 美术负责的 `.tscn`、`.tres` 或动画；
- 必要的双语布局调整；
- 一张中文截图和一张英文截图用于审查。

不要提交 `.godot/`、`.DS_Store`、`._*`、`test-reports/`、`builds/` 或导出
ZIP。大型 PSD/Krita/Blender 源文件在启用 Git LFS 前先协调；GitHub 单文件
上限为 100 MB。

## 3. 跨平台路径约束

游戏代码、场景和资源只使用 `res://...`。以下形式禁止进入项目源文件：

- `D:\...` 等 Windows 盘符；
- `/Users/name/...` 或 `/home/name/...`；
- `file://...`；
- 在 `res://` 后使用反斜杠。

文件名一律按大小写敏感处理。需要只改变大小写时：

```bash
git mv pic/OldName.png pic/__rename_tmp.png
git mv pic/__rename_tmp.png pic/oldname.png
```

当前审计结果：游戏脚本、场景、资源和本地化文件中没有机器绝对路径；唯一的
Windows 绝对路径位于开发工具配置 `godot-codex.json`，Mac 脚本通过
`GODOT_BIN` 或自动探测绕过它。`tests/test_portability.gd` 会持续检查机器路径
与 `res://` 引用的真实大小写。

## 4. 日常协作循环

```text
拉取约定分支
  → 确认本次负责的资产/场景
  → 在 Godot 4.7.1 中修改
  → 中英文各运行一次
  → ./tools/check.sh
  → 审查 git diff 与截图
  → 小提交
  → 推送并通知另一方合并
```

美术只判断视觉目标，程序测试只判断工程是否仍可加载和运行。出现以下情况时
应停止并沟通：

- 同一个 `.tscn` 同时被双方修改；
- Godot 自动重写大量无关 `.import` 文件；
- 资源名称发生大小写或目录迁移；
- 需要改变节点名、信号、脚本导出变量或数据结构；
- 需要引入 Git LFS、字体许可证或第三方插件。

## 5. Mac 可玩包

Mac 是本项目 macOS 构建的权威环境。安装 4.7.1 Export Templates 后执行：

```bash
./tools/export-macos.sh
```

脚本会先运行完整检查，再使用仓库中的 `macOS` Universal 预设导出
`builds/macos/MillenniumShoppingGuide-macOS.zip`，检查 `.app` 结构并打印
SHA-256。内部测试包采用 ad-hoc 签名；只对自己或可信协作者构建的应用使用
Control-click → Open。正式公开发布仍应由 Apple Developer 账号完成签名和
notarization。

## 6. AI 助手交接

让美术的 AI 编程助手首先阅读根目录 `ARTIST_AI.md`。该文件明确限定美术侧
可以修改的范围、路径规则、验证命令、双语要求与冲突停止条件。不要只给助手
一张截图而不提供仓库状态和目标场景；每次任务至少说明：负责文件、参考图、
期望效果、不可改动范围和人工验收点。
