import SwiftUI
import WalkGateCore

struct SettingsView: View {
  @ObservedObject var session: SessionController
  @State private var draftSchedule: DailyWorkSchedule

  init(session: SessionController) {
    self.session = session
    _draftSchedule = State(initialValue: session.schedule)
  }

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

      Section("工作日程") {
        Toggle("启用工作时间表", isOn: $draftSchedule.isEnabled)

        LabeledContent("上班时间") {
          DatePicker(
            "上班时间",
            selection: timeBinding(
              get: { draftSchedule.workStartMinute },
              set: { draftSchedule.workStartMinute = $0 }),
            displayedComponents: .hourAndMinute
          )
          .labelsHidden()
        }
        .disabled(!draftSchedule.isEnabled)

        LabeledContent("下班时间") {
          DatePicker(
            "下班时间",
            selection: timeBinding(
              get: { draftSchedule.workEndMinute },
              set: { draftSchedule.workEndMinute = $0 }),
            displayedComponents: .hourAndMinute
          )
          .labelsHidden()
        }
        .disabled(!draftSchedule.isEnabled)

        if draftSchedule.isEnabled {
          ForEach($draftSchedule.restPeriods) { $period in
            HStack(spacing: 8) {
              Text("休息")
              Spacer()
              DatePicker(
                "开始",
                selection: timeBinding(
                  get: { period.startMinute },
                  set: { period.startMinute = $0 }),
                displayedComponents: .hourAndMinute
              )
              .labelsHidden()
              Text("至")
                .foregroundStyle(.secondary)
              DatePicker(
                "结束",
                selection: timeBinding(
                  get: { period.endMinute },
                  set: { period.endMinute = $0 }),
                displayedComponents: .hourAndMinute
              )
              .labelsHidden()
              Button {
                draftSchedule.restPeriods.removeAll { $0.id == period.id }
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.plain)
              .foregroundStyle(.secondary)
              .help("删除这个休息时段")
            }
          }

          Button {
            draftSchedule.restPeriods.append(
              DailyRestPeriod(startMinute: 15 * 60 + 30, endMinute: 15 * 60 + 45))
          } label: {
            Label("添加休息时段", systemImage: "plus")
          }
        }

        if let scheduleValidationMessage {
          Text(scheduleValidationMessage)
            .font(.caption)
            .foregroundStyle(.red)
        }

        HStack {
          Spacer()
          Button("保存日程") {
            session.applySchedule(draftSchedule)
            draftSchedule = session.schedule
          }
          .disabled(scheduleValidationMessage != nil)
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
    .frame(width: 440, height: 590)
    .onReceive(session.$schedule) { schedule in
      draftSchedule = schedule
    }
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

  private var scheduleValidationMessage: String? {
    guard draftSchedule.isEnabled else { return nil }
    guard draftSchedule.workStartMinute < draftSchedule.workEndMinute else {
      return "下班时间需要晚于上班时间。"
    }
    if draftSchedule.restPeriods.contains(where: {
      $0.startMinute >= $0.endMinute
        || $0.startMinute < draftSchedule.workStartMinute
        || $0.endMinute > draftSchedule.workEndMinute
    }) {
      return "休息时段需要位于工作时间内，且结束时间晚于开始时间。"
    }
    return nil
  }

  private func timeBinding(
    get: @escaping () -> Int,
    set: @escaping (Int) -> Void
  ) -> Binding<Date> {
    Binding(
      get: { Self.date(forMinute: get()) },
      set: { set(Self.minute(from: $0)) }
    )
  }

  private static func date(forMinute minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let start = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .minute, value: min(max(minute, 0), 24 * 60 - 1), to: start)
      ?? start
  }

  private static func minute(from date: Date) -> Int {
    let calendar = Calendar.current
    return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }
}
