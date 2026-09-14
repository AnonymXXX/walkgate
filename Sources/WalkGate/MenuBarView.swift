import SwiftUI

struct MenuBarView: View {
  @ObservedObject var session: SessionController

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(20)

      Divider()

      actionSection
        .padding(20)

      Divider()

      footer
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    .frame(width: 340)
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(spacing: 18) {
      ZStack {
        Circle()
          .stroke(Color.secondary.opacity(0.16), lineWidth: 7)
        Circle()
          .trim(from: 0, to: max(0.015, session.progress))
          .stroke(
            Color.accentColor,
            style: StrokeStyle(lineWidth: 7, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))

        Image(systemName: session.snapshot.phase == .working ? "laptopcomputer" : "figure.walk")
          .font(.system(size: 21, weight: .medium))
          .foregroundStyle(Color.accentColor)
      }
      .frame(width: 70, height: 70)

      VStack(alignment: .leading, spacing: 5) {
        Text(session.snapshot.phase == .working ? "保持节奏" : "休息闸门已开启")
          .font(.headline)
        Text(session.formattedRemaining)
          .font(.system(size: 29, weight: .semibold, design: .rounded).monospacedDigit())
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
    HStack {
      SettingsLink {
        Label("设置", systemImage: "gearshape")
      }
      .buttonStyle(.plain)

      Spacer()

      Button("退出 WalkGate") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
    }
    .font(.caption)
  }
}
