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
    VStack(spacing: 0) {
      VStack(spacing: 18) {
        progressHero

        countdown

        primaryAction

        if session.snapshot.phase == .working {
          meetingMenu
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 26)
      .padding(.bottom, 20)

      Divider()

      footer
        .padding(8)
    }
    .frame(width: 280)
    .background {
      ZStack {
        Rectangle().fill(.regularMaterial)
        LinearGradient(
          colors: [
            Color.accentColor.opacity(0.12),
            Color.clear,
            Color.accentColor.opacity(0.04),
          ],
          startPoint: .topTrailing,
          endPoint: .bottomLeading
        )
      }
    }
  }

  private var progressHero: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.16), lineWidth: 11)

      Circle()
        .trim(from: 0, to: remainingProgress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: 11, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: session.progress)

      Circle()
        .fill(.ultraThinMaterial)
        .frame(width: 84, height: 84)
        .shadow(color: Color.accentColor.opacity(0.16), radius: 14)

      Image(systemName: heroSymbol)
        .font(.system(size: 40, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(Color.accentColor)
    }
    .frame(width: 154, height: 154)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("剩余时间进度，\(session.formattedRemaining)")
  }

  private var countdown: some View {
    VStack(spacing: 7) {
      Text(session.snapshot.phase == .working ? "休息提醒" : "正在休息")
        .font(.system(size: 22, weight: .semibold, design: .rounded))

      Text(session.formattedRemaining)
        .font(.system(size: 45, weight: .bold, design: .rounded).monospacedDigit())
        .contentTransition(.numericText())

      Text(countdownSubtitle)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var primaryAction: some View {
    if session.snapshot.phase == .working {
      Button {
        session.startBreakNow()
      } label: {
        Label("现在起来走走", systemImage: "figure.walk.motion")
          .font(.system(size: 17, weight: .semibold))
          .frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .tint(.accentColor)
    } else {
      Button {
        session.deferBreak()
      } label: {
        Label("延迟 5 分钟", systemImage: "clock.arrow.circlepath")
          .font(.system(size: 17, weight: .semibold))
          .frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .tint(.accentColor)
      .disabled(session.snapshot.deferralUsed)
    }
  }

  private var meetingMenu: some View {
    Menu {
      Button("安静 30 分钟") { session.pauseForMeeting(minutes: 30) }
      Button("安静 60 分钟") { session.pauseForMeeting(minutes: 60) }
      Button("安静 90 分钟") { session.pauseForMeeting(minutes: 90) }
    } label: {
      Label("会议模式", systemImage: "video")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private var footer: some View {
    HStack(spacing: 4) {
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

  private var remainingProgress: Double {
    max(0.015, 1 - session.progress)
  }

  private var heroSymbol: String {
    session.snapshot.phase == .working ? "cup.and.heat.waves.fill" : "figure.walk.motion"
  }

  private var countdownSubtitle: String {
    if session.snapshot.phase == .working {
      return "距离下次休息"
    }
    return session.isUserAway ? "保持离开键盘" : "离开键盘后继续倒计时"
  }

  private func footerLabel(
    _ title: String,
    systemImage: String,
    action: FooterAction
  ) -> some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(hoveredFooterAction == action ? Color.white : Color.primary)
      .frame(maxWidth: .infinity, minHeight: 34)
      .padding(.horizontal, 7)
      .background {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
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
