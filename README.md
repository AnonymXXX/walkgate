# WalkGate

一款原生、轻量的 macOS 菜单栏久坐提醒工具。

普通倒计时很容易被忽略。WalkGate 会在工作周期结束后开启“休息闸门”：用低调的右下角卡片提示起身，并暂时拦截桌面操作。只有真正离开键盘和鼠标，休息时间才会累计；达到最低休息时长后，由你回来手动进入下一轮工作。

> 当前版本：`0.2.0` · 支持 macOS 14 及以上版本

## 界面预览

<p align="center">
  <img src="docs/images/walkgate-menu.png" width="320" alt="WalkGate 菜单栏主界面"><br>
  <sub>菜单栏主界面</sub>
</p>

<p align="center">
  <img src="docs/images/walkgate-break-card.png" width="600" alt="WalkGate 休息提醒卡片"><br>
  <sub>右下角休息提醒卡片</sub>
</p>

## 核心体验

- **菜单栏常驻**：随时查看本轮剩余时间和进度，不占用 Dock 图标。
- **真正离开才计时**：键盘和鼠标连续 5 秒无操作后，休息倒计时才会前进。
- **低干扰休息卡片**：卡片显示在当前屏幕右下角、程序坞上方，不使用醒目的全屏界面。
- **休息操作限制**：休息期间覆盖所有显示器并拦截桌面点击；程序坞保持显示，系统应急能力仍可使用。
- **手动恢复工作**：达到最低休息时长后不会自行开始下一轮，回来点击“进入工作模式”才重新计时。
- **合理的例外**：每轮可延迟一次，也始终保留“紧急跳过”。
- **会议模式**：需要持续专注时，可选择安静 30、60 或 90 分钟。
- **原生系统集成**：支持提前通知、登录时自动启动，以及跟随 macOS 的深色材质效果。

## 工作流程

```text
工作倒计时
   ↓ 到期
休息闸门（离开键鼠后才累计）
   ↓ 达到最低休息时长
等待你回来
   ↓ 点击“进入工作模式”
开始新的工作周期
```

默认工作节奏为 50 分钟工作、5 分钟休息、提前 3 分钟提醒；可在设置中将休息调整为 2、3 或 5 分钟。设置会保存在本机。

## 安装

项目目前没有提供经过 Developer ID 公证的安装包。可以从源码构建本机临时签名版本：

```bash
git clone https://github.com/AnonymXXX/walkgate.git
cd walkgate
./scripts/build-app.sh
open dist/WalkGate.app
```

如需安装到“应用程序”目录：

```bash
ditto dist/WalkGate.app /Applications/WalkGate.app
open /Applications/WalkGate.app
```

首次启用通知或登录启动时，macOS 可能要求确认。由于当前是临时签名构建，更换构建版本后，部分系统授权可能需要重新确认。

## 本地开发

### 环境要求

- macOS 14 Sonoma 或更高版本
- Xcode 15 或更高版本
- Swift 5.9 或更高版本

直接运行：

```bash
swift run WalkGate
```

运行测试与生产构建：

```bash
swift test
swift build -c release
```

生成 `.app`：

```bash
./scripts/build-app.sh release
```

构建脚本会生成经过 ad-hoc 签名的 `dist/WalkGate.app`。

## 项目结构

```text
Sources/WalkGate/          SwiftUI 与 AppKit 应用层
Sources/WalkGateCore/      可测试的计时状态机
Tests/WalkGateCoreTests/   核心行为测试
scripts/build-app.sh       本地应用打包脚本
```

WalkGate 使用 SwiftUI 构建菜单栏和设置界面，并用 AppKit 管理跨显示器的休息窗口。项目不依赖第三方运行时库。

## 数据与隐私

WalkGate 不需要账户，也不会上传使用数据。节奏设置和每日完成/跳过次数仅保存在本机 `UserDefaults` 中。键鼠空闲时间通过 macOS 系统接口读取，不记录按键、鼠标内容或应用内容。

## 当前限制

- 尚未提供正式签名、公证和自动更新。
- 当前统计仅展示当天完成与跳过次数，不提供历史趋势。
- 工作或休息中的剩余时间不会在应用退出后恢复。
