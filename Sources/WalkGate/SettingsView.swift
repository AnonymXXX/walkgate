import AppKit
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
      Section(L("节奏", "Rhythm")) {
        Picker(L("连续工作", "Work duration"), selection: settingBinding(\.workSeconds)) {
          Text(L("25 分钟", "25 min")).tag(25 * 60)
          Text(L("45 分钟", "45 min")).tag(45 * 60)
          Text(L("50 分钟", "50 min")).tag(50 * 60)
          Text(L("60 分钟", "60 min")).tag(60 * 60)
        }

        Picker(L("起身休息", "Break duration"), selection: settingBinding(\.breakSeconds)) {
          Text(L("2 分钟", "2 min")).tag(2 * 60)
          Text(L("3 分钟", "3 min")).tag(3 * 60)
          Text(L("5 分钟", "5 min")).tag(5 * 60)
        }

        Picker(L("提前提醒", "Advance reminder"), selection: settingBinding(\.preAlertSeconds)) {
          Text(L("1 分钟", "1 min")).tag(1 * 60)
          Text(L("3 分钟", "3 min")).tag(3 * 60)
          Text(L("5 分钟", "5 min")).tag(5 * 60)
        }
      }

      Section(L("工作日程", "Work Schedule")) {
        Toggle(L("启用工作时间表", "Enable work schedule"), isOn: $draftSchedule.isEnabled)

        Picker(L("时区", "Time zone"), selection: $draftSchedule.timeZoneIdentifier) {
          Text(
            L("跟随系统（%@）", "Follow System (%@)").replacingOccurrences(
              of: "%@", with: SessionController.timeZoneName(.autoupdatingCurrent)))
            .tag(String?.none)
          Divider()
          ForEach(Self.timeZoneOptions, id: \.identifier) { option in
            Text(option.label).tag(Optional(option.identifier))
          }
        }
        .disabled(!draftSchedule.isEnabled)

        LabeledContent(L("上班时间", "Start of work")) {
          DatePicker(
            L("上班时间", "Start of work"),
            selection: timeBinding(
              get: { draftSchedule.workStartMinute },
              set: { draftSchedule.workStartMinute = $0 }),
            displayedComponents: .hourAndMinute
          )
          .labelsHidden()
        }
        .disabled(!draftSchedule.isEnabled)

        LabeledContent(L("下班时间", "End of work")) {
          DatePicker(
            L("下班时间", "End of work"),
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
              Text(L("休息", "Break"))
              Spacer()
              DatePicker(
                L("开始", "Start"),
                selection: timeBinding(
                  get: { period.startMinute },
                  set: { period.startMinute = $0 }),
                displayedComponents: .hourAndMinute
              )
              .labelsHidden()
              Text(L("至", "to"))
                .foregroundStyle(.secondary)
              DatePicker(
                L("结束", "End"),
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
              .help(L("删除这个休息时段", "Remove this break period"))
            }
          }

          Button {
            draftSchedule.restPeriods.append(
              DailyRestPeriod(startMinute: 15 * 60 + 30, endMinute: 15 * 60 + 45))
          } label: {
            Label(L("添加休息时段", "Add break period"), systemImage: "plus")
          }
        }

        if let scheduleValidationMessage {
          Text(scheduleValidationMessage)
            .font(.caption)
            .foregroundStyle(.red)
        }

        HStack {
          Spacer()
          Button(L("保存日程", "Save Schedule")) {
            session.applySchedule(draftSchedule)
            draftSchedule = session.schedule
          }
          .disabled(scheduleValidationMessage != nil)
        }
      }

      Section(L("系统", "System")) {
        Toggle(
          L("允许提醒通知", "Allow notifications"),
          isOn: Binding(
            get: { session.notificationsEnabled },
            set: { session.setNotificationsEnabled($0) }
          )
        )

        if let hint = session.notificationPermissionHint {
          VStack(alignment: .leading, spacing: 6) {
            Text(hint)
              .font(.caption)
              .foregroundStyle(.orange)
            Button(L("打开系统通知设置", "Open Notification Settings")) {
              session.openNotificationSettings()
            }
            .controlSize(.small)
          }
        }

        Toggle(
          L("登录时自动启动", "Launch at login"),
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
        Text(
          L(
            "休息卡片弹出后立即计时；达到最低休息时长后继续显示额外休息时间，回来后手动进入工作模式。每轮最多延迟一次，并始终保留紧急跳过。",
            "The break timer starts as soon as the break card appears. After the minimum break, extra break time keeps counting until you return and resume work manually. Each round can be postponed once, and emergency skip is always available."
          ))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 440, height: 590)
    .background(InitialFocusResetter())
    .background(ClickAwayFocusResetter())
    .background(
      SettingsWindowObserver {
        draftSchedule = session.schedule
      }
    )
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
      return L("下班时间需要晚于上班时间。", "End of work must be later than start of work.")
    }
    if draftSchedule.restPeriods.contains(where: {
      $0.startMinute >= $0.endMinute
        || $0.startMinute < draftSchedule.workStartMinute
        || $0.endMinute > draftSchedule.workEndMinute
    }) {
      return L(
        "休息时段需要位于工作时间内，且结束时间晚于开始时间。",
        "Break periods must fall within work hours and end after they start.")
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

  private static let timeZoneOptions: [(identifier: String, label: String)] = {
    let now = Date()
    return TimeZone.knownTimeZoneIdentifiers
      .compactMap(TimeZone.init(identifier:))
      .sorted {
        let lhs = $0.secondsFromGMT(for: now)
        let rhs = $1.secondsFromGMT(for: now)
        return lhs == rhs ? $0.identifier < $1.identifier : lhs < rhs
      }
      .map { timeZone in
        let offset = timeZone.secondsFromGMT(for: now) / 60
        let label = String(
          format: "UTC%@%02d:%02d  %@", offset < 0 ? "-" : "+", abs(offset) / 60,
          abs(offset) % 60, timeZone.identifier)
        return (timeZone.identifier, label)
      }
  }()

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

private struct SettingsWindowObserver: NSViewRepresentable {
  let onWindowClose: () -> Void

  func makeNSView(context: Context) -> NSView {
    SettingsWindowObserverView(onWindowClose: onWindowClose)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    (nsView as? SettingsWindowObserverView)?.onWindowClose = onWindowClose
  }
}

private final class SettingsWindowObserverView: NSView {
  var onWindowClose: () -> Void

  init(onWindowClose: @escaping () -> Void) {
    self.onWindowClose = onWindowClose
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    NotificationCenter.default.removeObserver(self)
    if let window {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowWillClose),
        name: NSWindow.willCloseNotification,
        object: window
      )
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func windowWillClose() {
    onWindowClose()
  }
}

private struct ClickAwayFocusResetter: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    ClickAwayFocusResetView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ClickAwayFocusResetView: NSView {
  private var mouseMonitor: Any?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil {
      stopObserving()
    } else {
      startObserving()
    }
  }

  deinit {
    stopObserving()
  }

  private func startObserving() {
    guard mouseMonitor == nil else { return }
    mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
      [weak self] event in
      self?.clearFocusIfClickLandsOutsideFocusedControl(for: event)
      return event
    }
    if let window {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowDidResignKey),
        name: NSWindow.didResignKeyNotification,
        object: window
      )
    }
  }

  private func stopObserving() {
    if let monitor = mouseMonitor {
      NSEvent.removeMonitor(monitor)
      mouseMonitor = nil
    }
    NotificationCenter.default.removeObserver(self)
  }

  private func clearFocusIfClickLandsOutsideFocusedControl(for event: NSEvent) {
    guard let window, event.window === window,
      let contentView = window.contentView,
      let focusedView = focusedControl(in: window)
    else { return }

    let point = contentView.convert(event.locationInWindow, from: nil)
    if let hitView = contentView.hitTest(point),
      hitView === focusedView || hitView.isDescendant(of: focusedView)
    {
      return
    }
    window.makeFirstResponder(nil)
  }

  private func focusedControl(in window: NSWindow) -> NSView? {
    guard let responder = window.firstResponder as? NSView else { return nil }
    if let fieldEditor = responder as? NSTextView {
      return fieldEditor.superview ?? fieldEditor
    }
    return responder
  }

  @objc private func windowDidResignKey() {
    window?.makeFirstResponder(nil)
  }
}

private struct InitialFocusResetter: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    InitialFocusResetView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class InitialFocusResetView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window else { return }
    clearInitialFocus(in: window)
  }

  private func clearInitialFocus(in window: NSWindow) {
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window, self.window === window else { return }
      window.makeFirstResponder(nil)
    }
  }
}
