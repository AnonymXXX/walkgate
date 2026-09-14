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
      Label("休息已达标", systemImage: "checkmark.circle.fill")
        .font(.system(size: 15, weight: .semibold))
        .symbolRenderingMode(.hierarchical)
      Text("回来后，再开始下一轮工作。")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline) {
        Text(session.formattedBreakOvertime)
          .font(.system(size: 24, weight: .regular).monospacedDigit())
        Spacer()
        Text("额外休息")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      HStack(spacing: 7) {
        Image(systemName: "pause.circle.fill")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text("计时已停止")
        Spacer()
        Text("等待返回")
          .foregroundStyle(.tertiary)
      }
      .font(.caption)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: 32)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      Button {
        session.resumeWork()
      } label: {
        Text("进入工作模式")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .accessibilityHint("开始新的工作计时")
    }
  }

  private var activeBreakContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("起来走一走", systemImage: "figure.walk")
        .font(.system(size: 15, weight: .medium))
      Text("放下键鼠，走动一会儿。")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      HStack {
        Text(session.formattedRemaining)
          .font(.system(size: 24, weight: .regular).monospacedDigit())
        Spacer()
        Text("最低休息时长").font(.caption).foregroundStyle(.secondary)
      }
      ProgressView(value: session.progress).tint(.secondary)
      HStack {
        if !session.snapshot.deferralUsed {
          Button("延迟 5 分钟") { session.deferBreak() }
        }
        Button("紧急跳过") { session.skipBreak() }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }
}
