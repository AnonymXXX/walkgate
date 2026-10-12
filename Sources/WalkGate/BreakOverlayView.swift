import SwiftUI

struct BreakOverlayView: View {
  @ObservedObject var session: SessionController

  var body: some View {
    Group {
      if session.awaitingReturn {
        completedContent
      } else {
        activeBreakContent
      }
    }
    .padding(20)
    .frame(width: 300, height: 210, alignment: .topLeading)
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .background {
      FrostedPanelBackground(materialOpacity: 0.9)
        .overlay(Color.black.opacity(0.08))
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
    }
  }

  private var completedContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(L("休息已达标", "Break Complete"), systemImage: "checkmark.circle.fill")
        .font(.system(size: 15, weight: .semibold))
        .symbolRenderingMode(.hierarchical)
      Text(L("回来后，再开始下一轮工作。", "Start the next round when you’re back."))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline) {
        Text(session.formattedBreakOvertime)
          .font(.system(size: 24, weight: .regular).monospacedDigit())
        Spacer()
        Text(L("额外休息", "Extra break"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      HStack(spacing: 7) {
        Image(systemName: "pause.circle.fill")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text(L("计时已停止", "Timer stopped"))
        Spacer()
        Text(L("等待返回", "Waiting for you"))
          .foregroundStyle(.tertiary)
      }
      .font(.caption)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: 32)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      Button {
        session.resumeWork()
      } label: {
        Text(L("进入工作模式", "Resume Work"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .accessibilityHint(L("开始新的工作计时", "Start a new work timer"))
    }
  }

  private var activeBreakContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(L("起来走一走", "Get Up and Walk"), systemImage: "figure.walk")
        .font(.system(size: 15, weight: .medium))
      Text(L("放下键鼠，走动一会儿。", "Step away from the keyboard and move around."))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      HStack {
        Text(session.formattedRemaining)
          .font(.system(size: 24, weight: .regular).monospacedDigit())
        Spacer()
        Text(L("最低休息时长", "Minimum break")).font(.caption).foregroundStyle(.secondary)
      }
      ProgressView(value: session.progress)
        .tint(
          LinearGradient(
            colors: [Color(red: 0.16, green: 0.59, blue: 1), .blue],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
      HStack {
        if !session.snapshot.deferralUsed {
          Button(L("延迟 5 分钟", "Postpone 5 min")) { session.deferBreak() }
        }
        Button(L("紧急跳过", "Emergency Skip")) { session.skipBreak() }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }
}
