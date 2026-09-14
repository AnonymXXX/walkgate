import SwiftUI

struct BreakOverlayView: View {
  @ObservedObject var session: SessionController

  var body: some View {
    ZStack {
      Color.black.opacity(0.10).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 14) {
        Label(session.awaitingReturn ? "休息已达标" : "起来走一走", systemImage: "figure.walk")
          .font(.system(size: 15, weight: .medium))
        Text(session.awaitingReturn ? "不用急，回来后再开始工作。" : "放下键鼠，走动一会儿。")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        if session.awaitingReturn {
          Button("进入工作模式") { session.resumeWork() }
            .buttonStyle(.bordered)
        } else {
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
      .padding(20)
      .frame(width: 300, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
      .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
  }
}
