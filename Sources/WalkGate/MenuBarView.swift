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
      VStack(spacing: 14) {
        progressHero

        countdown

        if !session.isSchedulePaused {
          primaryAction
        }
        if !session.isSchedulePaused, session.snapshot.phase == .working {
          Menu {
            Button("安静 30 分钟") { session.pauseForMeeting(minutes: 30) }
            Button("安静 60 分钟") { session.pauseForMeeting(minutes: 60) }
            Button("安静 90 分钟") { session.pauseForMeeting(minutes: 90) }
          } label: {
            Label("会议模式", systemImage: "video")
              .font(.system(size: 13))
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
        }

      }
      .padding(.horizontal, 24)
      .padding(.top, 24)
      .padding(.bottom, 20)

      Divider()
        .opacity(0.24)

      footer
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    .frame(width: 320)
    .background(MenuPanelDismissal(shouldDismiss: session.snapshot.phase == .breakGate))
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .background {
      FrostedPanelBackground()
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .modifier(ClearWindowContainerBackground())
    .background(TransparentPanelWindowConfigurator())
  }

  private var progressHero: some View {
    ZStack {
      Circle()
        .stroke(Color(red: 0.25, green: 0.31, blue: 0.39), lineWidth: 9)

      Circle()
        .trim(from: 0, to: session.progress)
        .stroke(
          LinearGradient(
            colors: [Color(red: 0.16, green: 0.59, blue: 1), .blue], startPoint: .top,
            endPoint: .bottom),
          style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: session.progress)

      if session.isSchedulePaused {
        Image(systemName: "clock.badge")
          .font(.system(size: 38, weight: .medium))
          .foregroundStyle(.blue)
      } else if session.snapshot.phase == .working {
        CoffeeIllustration().frame(width: 52, height: 58)
      } else {
        Image(systemName: "figure.walk")
          .font(.system(size: 38, weight: .medium))
          .foregroundStyle(.blue)
      }
    }
    .frame(width: 128, height: 128)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("已完成 \(Int(session.progress * 100))%，剩余 \(session.formattedRemaining)")
  }

  private var countdown: some View {
    VStack(spacing: 7) {
      Text(
        session.isSchedulePaused
          ? session.scheduleStatusTitle
          : (session.snapshot.phase == .working ? "休息提醒" : "正在休息")
      )
      .font(.system(size: 18, weight: .semibold))

      Text(session.isSchedulePaused ? session.scheduleStatusTime : session.formattedRemaining)
        .font(.system(size: 42, weight: .bold).monospacedDigit())
        .contentTransition(.numericText())

      Text(countdownSubtitle)
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(Color(red: 0.66, green: 0.71, blue: 0.79))
    }
  }

  @ViewBuilder
  private var primaryAction: some View {
    if session.awaitingReturn {
      Button("进入工作模式") { session.resumeWork() }
        .buttonStyle(.bordered)
    } else if session.snapshot.phase == .working {
      Button {
        session.startBreakNow()
      } label: {
        Label("现在起来走走", systemImage: "figure.walk")
          .font(.system(size: 16, weight: .semibold))
          .frame(maxWidth: .infinity, minHeight: 42)
      }
      .buttonStyle(WalkActionStyle())
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
      .buttonStyle(WalkActionStyle())
      .buttonBorderShape(.capsule)
      .tint(.accentColor)
      .disabled(session.snapshot.deferralUsed)
    }
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
      .contextMenu {
        Button("会议模式 · 30 分钟") { session.pauseForMeeting(minutes: 30) }
        Button("会议模式 · 60 分钟") { session.pauseForMeeting(minutes: 60) }
        Button("会议模式 · 90 分钟") { session.pauseForMeeting(minutes: 90) }
      }

      Spacer(minLength: 8)

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        footerLabel("退出 WalkGate", systemImage: "power", action: .quit)
      }
      .buttonStyle(.plain)
      .onHover { updateHover(.quit, isHovering: $0) }
    }
  }

  private var countdownSubtitle: String {
    if session.isSchedulePaused { return session.scheduleStatusSubtitle }
    if session.awaitingReturn { return "回来后点击进入工作模式" }
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
      .font(.system(size: 12, weight: .regular))
      .foregroundStyle(hoveredFooterAction == action ? Color.white : Color.white.opacity(0.85))
      .frame(minHeight: 30)
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

private struct MenuPanelDismissal: NSViewRepresentable {
  let shouldDismiss: Bool

  func makeNSView(context: Context) -> NSView { NSView() }

  func updateNSView(_ view: NSView, context: Context) {
    guard shouldDismiss else { return }
    DispatchQueue.main.async { [weak view] in
      view?.window?.orderOut(nil)
    }
  }
}
