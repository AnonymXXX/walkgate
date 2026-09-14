import SwiftUI
import WalkGateCore

struct SettingsView: View {
  @ObservedObject var session: SessionController

  var body: some View {
    Form {
      Section("节奏") {
        Picker("连续工作", selection: settingBinding(\.workSeconds)) {
          Text("25 分钟").tag(25 * 60)
          Text("45 分钟").tag(45 * 60)
          Text("50 分钟").tag(50 * 60)
          Text("60 分钟").tag(60 * 60)
        }

        Picker("起身休息", selection: settingBinding(\.breakSeconds)) {
          Text("2 分钟").tag(2 * 60)
          Text("3 分钟").tag(3 * 60)
          Text("5 分钟").tag(5 * 60)
        }

        Picker("提前提醒", selection: settingBinding(\.preAlertSeconds)) {
          Text("1 分钟").tag(1 * 60)
          Text("3 分钟").tag(3 * 60)
          Text("5 分钟").tag(5 * 60)
        }
      }

      Section("系统") {
        Toggle(
          "允许提醒通知",
          isOn: Binding(
            get: { session.notificationsEnabled },
            set: { session.setNotificationsEnabled($0) }
          )
        )

        Toggle(
          "登录时自动启动",
          isOn: Binding(
            get: { session.launchAtLoginEnabled },
            set: { session.setLaunchAtLoginEnabled($0) }
          )
        )

        if let message = session.settingsMessage {
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section {
        Text("休息倒计时只会在键盘和鼠标连续 5 秒无操作后前进。每轮最多延迟一次，并始终保留紧急跳过。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 440, height: 390)
  }

  private func settingBinding(_ keyPath: WritableKeyPath<SessionSettings, Int>) -> Binding<Int> {
    Binding(
      get: { session.settings[keyPath: keyPath] },
      set: { newValue in
        var updated = session.settings
        updated[keyPath: keyPath] = newValue
        session.applySettings(updated)
      }
    )
  }
}
