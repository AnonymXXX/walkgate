import SwiftUI

struct MenuBarView: View {
  @ObservedObject var session: SessionController
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.openSettings) private var openSettings
  @State private var hoveredFooterAction: FooterAction?

  private enum FooterAction {
    case settings
    case quit
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(16)

      Divider()

      actionSection
        .padding(16)

      Divider()

      footer
        .padding(6)
    }
    .frame(width: 260)
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .stroke(Color.secondary.opacity(0.16), lineWidth: 6)
        Circle()
          .trim(from: 0, to: max(0.015, session.progress))
          .stroke(
            Color.accentColor,
            style: StrokeStyle(lineWidth: 6, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        Image(systemName: session.snapshot.phase == .working ? "laptopcomputer" : "figure.walk")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(Color.accentColor)
      }
      .frame(width: 58, height: 58)

      VStack(alignment: .leading, spacing: 5) {
        Text(session.snapshot.phase == .working ? "保持节奏" : "休息闸门已开启")
          .font(.headline)
        Text(session.formattedRemaining)
          .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
          .contentTransition(.numericText())
        Text(session.snapshot.phase == .working ? "距离下一次起身" : "离开键盘后开始倒计时")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var actionSection: some View {
    VStack(spacing: 10) {
      if session.snapshot.phase == .working {
        Button {
          session.startBreakNow()
        } label: {
          Label("现在起来走走", systemImage: "figure.walk.motion")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Menu {
          Button("安静 30 分钟") { session.pauseForMeeting(minutes: 30) }
          Button("安静 60 分钟") { session.pauseForMeeting(minutes: 60) }
          Button("安静 90 分钟") { session.pauseForMeeting(minutes: 90) }
        } label: {
          Label("会议模式", systemImage: "video")
            .frame(maxWidth: .infinity)
        }
        .menuStyle(.borderlessButton)
      } else {
        Button {
          session.deferBreak()
        } label: {
          Label("延迟 5 分钟", systemImage: "clock.arrow.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(session.snapshot.deferralUsed)
      }

      HStack {
        Label("完成 \(session.snapshot.completedBreaks)", systemImage: "checkmark.circle")
        Spacer()
        Label("跳过 \(session.snapshot.skippedBreaks)", systemImage: "exclamationmark.circle")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.top, 4)
    }
  }

  private var footer: some View {
    VStack(spacing: 2) {
      Button {
        showSettings()
      } label: {
        footerLabel("设置…", systemImage: "gearshape", action: .settings)
      }
      .buttonStyle(.plain)
      .onHover { updateHover(.settings, isHovering: $0) }

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        footerLabel("退出 WalkGate", systemImage: "power", action: .quit)
      }
      .buttonStyle(.plain)
      .onHover { updateHover(.quit, isHovering: $0) }
    }
  }

  private func footerLabel(
    _ title: String,
    systemImage: String,
    action: FooterAction
  ) -> some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(hoveredFooterAction == action ? Color.white : Color.primary)
      .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
      .padding(.horizontal, 10)
      .background {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(hoveredFooterAction == action ? Color.accentColor : Color.clear)
      }
      .contentShape(Rectangle())
  }

  private func updateHover(_ action: FooterAction, isHovering: Bool) {
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
      if isHovering {
        hoveredFooterAction = action
      } else if hoveredFooterAction == action {
        hoveredFooterAction = nil
      }
    }
  }

  private func showSettings() {
    openSettings()
    NSApplication.shared.activate(ignoringOtherApps: true)

    DispatchQueue.main.async {
      let application = NSApplication.shared
      application.activate(ignoringOtherApps: true)

      let settingsWindow = application.windows.first { window in
        window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
          || window.title.localizedCaseInsensitiveContains("设置")
      }
      settingsWindow?.makeKeyAndOrderFront(nil)
    }
  }
}
