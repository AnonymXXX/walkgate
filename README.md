# WalkGate

一个原生 macOS 菜单栏久坐提醒工具。连续工作到期后，它会在所有屏幕上开启休息闸门；只有离开键盘和鼠标后，休息倒计时才会继续。

## 当前功能

- 菜单栏倒计时与今日完成记录
- 工作前 3 分钟原生通知
- 覆盖所有屏幕和全屏空间的休息闸门
- 连续 5 秒无键鼠操作后才累计休息时间
- 每轮一次延迟、紧急跳过和会议模式
- 工作、休息、提前提醒时长设置
- 登录时自动启动

## 开发运行

要求 macOS 14 或更高版本，以及 Xcode 15 或更高版本。

```bash
swift run WalkGate
```

## 构建应用

```bash
./scripts/build-app.sh
open dist/WalkGate.app
```

脚本会生成经过临时签名的 `dist/WalkGate.app`，用于本机试用。首次启用通知或登录启动时，macOS 可能要求确认。

## 验证

```bash
swift test
swift build
```
