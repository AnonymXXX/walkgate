import SwiftUI

struct MenuBarView: View {
  @ObservedObject var session: SessionController
  let onOpenSettings: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            Button(L("安静 30 分钟", "Quiet for 30 min")) { session.pauseForMeeting(minutes: 30) }
            Button(L("安静 60 分钟", "Quiet for 60 min")) { session.pauseForMeeting(minutes: 60) }
            Button(L("安静 90 分钟", "Quiet for 90 min")) { session.pauseForMeeting(minutes: 90) }
          } label: {
            Label(L("会议模式", "Meeting Mode"), systemImage: "video")
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
      FrostedPanelBackground(material: .popover, materialOpacity: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .background(
      MenuPanelVisibilityObserver { isVisible in
        session.setMenuPresented(isVisible)
      }
    )
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
    .accessibilityLabel(progressAccessibilityLabel)
  }

  private var countdown: some View {
    VStack(spacing: 7) {
      Text(
        session.isSchedulePaused
          ? session.scheduleStatusTitle
          : (session.snapshot.phase == .working ? L("休息提醒", "Break Reminder") : L("正在休息", "On Break"))
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
      Button(L("进入工作模式", "Resume Work")) { session.resumeWork() }
        .buttonStyle(.bordered)
    } else if session.snapshot.phase == .working {
      Button {
        session.startBreakNow()
      } label: {
        Label(L("现在起来走走", "Take a Walk Now"), systemImage: "figure.walk")
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
        Label(L("延迟 5 分钟", "Postpone 5 min"), systemImage: "clock.arrow.circlepath")
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
        footerLabel(L("设置…", "Settings…"), systemImage: "gearshape", action: .settings)
      }
      .buttonStyle(.plain)
      .onHover { updateHover(.settings, isHovering: $0) }
      .contextMenu {
        Button(L("会议模式 · 30 分钟", "Meeting Mode · 30 min")) { session.pauseForMeeting(minutes: 30) }
        Button(L("会议模式 · 60 分钟", "Meeting Mode · 60 min")) { session.pauseForMeeting(minutes: 60) }
        Button(L("会议模式 · 90 分钟", "Meeting Mode · 90 min")) { session.pauseForMeeting(minutes: 90) }
      }

      Spacer(minLength: 8)

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        footerLabel(L("退出 WalkGate", "Quit WalkGate"), systemImage: "power", action: .quit)
      }
      .buttonStyle(.plain)
      .onHover { updateHover(.quit, isHovering: $0) }
    }
  }

  private var countdownSubtitle: String {
    if session.isSchedulePaused { return session.scheduleStatusSubtitle }
    if session.awaitingReturn { return L("回来后点击进入工作模式", "Click Resume Work when you’re back") }
    if session.snapshot.phase == .working {
      return L("距离下次休息", "Until next break")
    }
    return L("休息计时进行中", "Break in progress")
  }

  private var progressAccessibilityLabel: String {
    if session.awaitingReturn {
      return L("休息已达标，额外休息 ", "Break complete, extra ") + session.formattedBreakOvertime
    }
    let percent = Int(session.progress * 100)
    return L(
      "已完成 \(percent)%，剩余 \(session.formattedRemaining)",
      "\(percent)% done, \(session.formattedRemaining) left")
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
    onOpenSettings()
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
