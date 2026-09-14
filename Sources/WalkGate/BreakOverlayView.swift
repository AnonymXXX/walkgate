import SwiftUI

struct BreakOverlayView: View {
  @ObservedObject var session: SessionController
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isBreathing = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.48)
        .ignoresSafeArea()

      VStack(spacing: 26) {
        ZStack {
          Circle()
            .fill(Color.accentColor.opacity(0.14))
            .frame(width: 112, height: 112)
            .scaleEffect(isBreathing ? 1.08 : 0.96)

          Image(systemName: "figure.walk.motion")
            .font(.system(size: 48, weight: .medium))
            .foregroundStyle(Color.accentColor)
        }

        VStack(spacing: 10) {
          Text("起来走一走")
            .font(.system(size: 34, weight: .semibold, design: .rounded))

          Text(session.isUserAway ? "很好，保持离开键盘" : "离开键盘 5 秒后，休息计时才会开始")
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }

        Text(session.formattedRemaining)
          .font(.system(size: 54, weight: .medium, design: .rounded).monospacedDigit())
          .contentTransition(.numericText())

        ProgressView(value: session.progress)
          .progressViewStyle(.linear)
          .tint(.accentColor)
          .frame(width: 300)

        HStack(spacing: 12) {
          if !session.snapshot.deferralUsed {
            Button("再给我 5 分钟") {
              session.deferBreak()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
          }

          Button("紧急跳过") {
            session.skipBreak()
          }
          .buttonStyle(.bordered)
          .controlSize(.large)
        }

        Text("今天已完成 \(session.snapshot.completedBreaks) 次 · 跳过 \(session.snapshot.skippedBreaks) 次")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(42)
      .frame(width: 510)
      .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .strokeBorder(.white.opacity(0.14), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.28), radius: 36, y: 18)
    }
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
        isBreathing = true
      }
    }
  }
}
