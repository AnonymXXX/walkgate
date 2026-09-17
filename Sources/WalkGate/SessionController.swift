import AppKit
import Combine
import CoreGraphics
import Foundation
import ServiceManagement
import UserNotifications
import WalkGateCore

@MainActor
final class SessionController: ObservableObject {
  @Published private(set) var snapshot: SessionSnapshot
  @Published private(set) var settings: SessionSettings
  @Published private(set) var schedule: DailyWorkSchedule
  @Published private(set) var workdayState: WorkdayState
  @Published private(set) var isUserAway = false
  @Published var notificationsEnabled: Bool
  @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
  @Published var launchAtLoginEnabled: Bool
  @Published var settingsMessage: String?

  private enum Keys {
    static let workSeconds = "workSeconds"
    static let breakSeconds = "breakSeconds"
    static let preAlertSeconds = "preAlertSeconds"
    static let notificationsEnabled = "notificationsEnabled"
    static let statsDay = "statsDay"
    static let completedBreaks = "completedBreaks"
    static let skippedBreaks = "skippedBreaks"
    static let schedule = "dailyWorkSchedule"
  }

  private var engine: SessionEngine
  private var refreshPolicy: SessionRefreshPolicy
  private var timer: Timer?
  private var overlayCoordinator: BreakOverlayCoordinator?
  private var workspaceObservers: [NSObjectProtocol] = []
  private var sleepStartedAt: Date?
  private var needsFreshCycleAfterWake = false
  private var isMenuPresented = false
  private let defaults: UserDefaults
  private let calendar: Calendar

  init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
    self.defaults = defaults
    self.calendar = calendar

    let settings = SessionSettings(
      workSeconds: defaults.object(forKey: Keys.workSeconds) as? Int ?? 50 * 60,
      breakSeconds: defaults.object(forKey: Keys.breakSeconds) as? Int ?? 5 * 60,
      preAlertSeconds: defaults.object(forKey: Keys.preAlertSeconds) as? Int ?? 3 * 60,
      deferralSeconds: 5 * 60
    )
    self.settings = settings

    let storedSchedule = defaults.data(forKey: Keys.schedule)
      .flatMap { try? JSONDecoder().decode(DailyWorkSchedule.self, from: $0) }
    let schedule = (storedSchedule ?? .defaultSchedule).normalized()
    let initialWorkdayState = schedule.state(
      atMinute: Self.minuteOfDay(for: Date(), calendar: calendar))
    self.schedule = schedule
    self.workdayState = initialWorkdayState

    let today = Self.dayKey(for: Date(), calendar: calendar)
    let storedDay = defaults.string(forKey: Keys.statsDay)
    let completed = storedDay == today ? defaults.integer(forKey: Keys.completedBreaks) : 0
    let skipped = storedDay == today ? defaults.integer(forKey: Keys.skippedBreaks) : 0
    let engine = SessionEngine(
      settings: settings, completedBreaks: completed, skippedBreaks: skipped)
    self.engine = engine
    self.snapshot = engine.snapshot
    self.refreshPolicy = SessionRefreshPolicy(initialSnapshot: engine.snapshot)

    self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

    defaults.set(today, forKey: Keys.statsDay)
    DispatchQueue.main.async { [weak self] in
      self?.start()
    }
  }

  deinit {
    timer?.invalidate()
    for observer in workspaceObservers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
  }

  var formattedRemaining: String {
    let elapsedPastTarget = snapshot.remainingSeconds < 0
    let totalSeconds = abs(snapshot.remainingSeconds)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%@%02d:%02d", elapsedPastTarget ? "+" : "", minutes, seconds)
  }

  var formattedBreakOvertime: String {
    let totalSeconds = abs(min(snapshot.remainingSeconds, 0))
    return String(format: "+%02d:%02d", totalSeconds / 60, totalSeconds % 60)
  }

  var menuBarTitle: String {
    if isSchedulePaused {
      return workdayState == .resting ? "休息" : "下班"
    }
    return snapshot.phase == .working
      ? "\(max(1, Int(ceil(Double(snapshot.remainingSeconds) / 60))))m" : "走一走"
  }

  var progress: Double {
    engine.progress
  }

  var isSchedulePaused: Bool {
    schedule.isEnabled && workdayState != .working
  }

  var scheduleStatusTitle: String {
    workdayState == .resting ? "日程休息" : "工作时间外"
  }

  var scheduleStatusTime: String {
    let minute = Self.minuteOfDay(for: Date(), calendar: calendar)
    if workdayState == .resting,
      let period = schedule.activeRestPeriod(atMinute: minute)
    {
      return Self.formatMinute(period.endMinute)
    }
    return Self.formatMinute(schedule.workStartMinute)
  }

  var scheduleStatusSubtitle: String {
    if workdayState == .resting {
      return "结束后开始完整工作周期"
    }
    let minute = Self.minuteOfDay(for: Date(), calendar: calendar)
    return minute < schedule.workStartMinute ? "到点后自动开始计时" : "今天不再发送休息提醒"
  }

  func startBreakNow() {
    guard !isSchedulePaused else { return }
    engine.startBreakNow()
    publishSnapshot(force: true)
    overlayCoordinator?.show()
  }

  func deferBreak() {
    guard engine.deferBreak() else { return }
    publishSnapshot(force: true)
    overlayCoordinator?.hide()
  }

  func skipBreak() {
    engine.skipBreak()
    publishSnapshot(force: true)
    saveStats()
    overlayCoordinator?.hide()
  }

  var awaitingReturn: Bool {
    snapshot.phase == .breakGate && snapshot.remainingSeconds <= 0
  }

  func resumeWork() {
    guard engine.resumeWork() else { return }
    publishSnapshot(force: true)
    saveStats()
    overlayCoordinator?.hide()
  }

  func pauseForMeeting(minutes: Int) {
    guard !isSchedulePaused else { return }
    engine.pauseForMeeting(seconds: minutes * 60)
    publishSnapshot(force: true)
    overlayCoordinator?.hide()
  }

  func applySettings(_ settings: SessionSettings) {
    self.settings = settings
    engine.updateSettings(settings)
    publishSnapshot(force: true)
    defaults.set(settings.workSeconds, forKey: Keys.workSeconds)
    defaults.set(settings.breakSeconds, forKey: Keys.breakSeconds)
    defaults.set(settings.preAlertSeconds, forKey: Keys.preAlertSeconds)
  }

  func applySchedule(_ schedule: DailyWorkSchedule) {
    let normalized = schedule.normalized()
    self.schedule = normalized
    if let data = try? JSONEncoder().encode(normalized) {
      defaults.set(data, forKey: Keys.schedule)
      settingsMessage = nil
    } else {
      settingsMessage = "无法保存工作日程。"
    }
    _ = updateWorkdayState(at: Date())
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    notificationsEnabled = enabled
    defaults.set(enabled, forKey: Keys.notificationsEnabled)
    if enabled {
      synchronizeNotificationPermission()
    }
  }

  var notificationPermissionHint: String? {
    guard notificationsEnabled else { return nil }
    switch notificationAuthorization {
    case .denied:
      return "系统通知权限已关闭，提前提醒不会显示。请在“系统设置 → 通知 → WalkGate”中允许通知。"
    default:
      return nil
    }
  }

  func openNotificationSettings() {
    let urlString =
      "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.y0num.walkgate"
    if let url = URL(string: urlString) {
      NSWorkspace.shared.open(url)
    }
  }

  func setLaunchAtLoginEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
      settingsMessage = launchAtLoginEnabled == enabled ? nil : "系统尚未完成登录项状态更新。"
    } catch {
      launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
      settingsMessage = "无法更新登录启动：\(error.localizedDescription)"
    }
  }

  func setMenuPresented(_ presented: Bool) {
    guard isMenuPresented != presented else { return }
    isMenuPresented = presented
    if presented {
      publishSnapshot(force: true)
      if notificationsEnabled {
        refreshNotificationAuthorization()
      }
    }
  }

  func releaseFrontmostStatusIfNeeded() {
    guard NSApp.isActive else { return }
    NSApp.deactivate()
  }

  private func start() {
    overlayCoordinator = BreakOverlayCoordinator(session: self)
    if notificationsEnabled {
      synchronizeNotificationPermission()
    } else {
      refreshNotificationAuthorization()
    }
    observeSystemSleep()
    startTimer()
  }

  private func startTimer() {
    guard timer == nil else { return }
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tick()
      }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func tick() {
    let idleSeconds = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: CGEventType(rawValue: UInt32.max)!
    )
    let userIsAway = idleSeconds >= 5
    if isUserAway != userIsAway {
      isUserAway = userIsAway
    }

    let startedScheduledCycle = updateWorkdayState(at: Date())
    guard !isSchedulePaused else {
      overlayCoordinator?.hide()
      return
    }
    guard !startedScheduledCycle else { return }

    if needsFreshCycleAfterWake {
      guard !isUserAway else {
        overlayCoordinator?.hide()
        return
      }
      needsFreshCycleAfterWake = false
      engine.startFreshWorkCycle()
      publishSnapshot(force: true)
      return
    }

    let event = engine.tick(isUserIdle: isUserAway)
    publishSnapshot()

    switch event {
    case .preBreakWarning:
      sendPreBreakNotification()
    case .breakBecameDue:
      overlayCoordinator?.show()
    case .breakCompleted:
      break
    case .none:
      break
    }
  }

  private func publishSnapshot(force: Bool = false) {
    let currentSnapshot = engine.snapshot
    let isRealtimePresentationVisible =
      isMenuPresented || overlayCoordinator?.isVisible == true
    guard force
      || refreshPolicy.shouldPublish(
        currentSnapshot,
        isRealtimePresentationVisible: isRealtimePresentationVisible
      )
    else { return }

    refreshPolicy.markPublished(currentSnapshot)
    snapshot = currentSnapshot
  }

  @discardableResult
  private func updateWorkdayState(at date: Date) -> Bool {
    let currentState = schedule.state(atMinute: Self.minuteOfDay(for: date, calendar: calendar))
    let previousState = workdayState
    if previousState != currentState {
      workdayState = currentState
    }

    guard previousState != .working, currentState == .working else { return false }
    needsFreshCycleAfterWake = false
    engine.startFreshWorkCycle()
    publishSnapshot(force: true)
    overlayCoordinator?.hide()
    return true
  }

  private func observeSystemSleep() {
    guard workspaceObservers.isEmpty else { return }
    let center = NSWorkspace.shared.notificationCenter
    workspaceObservers.append(
      center.addObserver(
        forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.sleepStartedAt = Date()
          self?.stopTimer()
        }
      })
    workspaceObservers.append(
      center.addObserver(
        forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          defer { self.startTimer() }
          guard let sleepStartedAt = self.sleepStartedAt else { return }
          self.sleepStartedAt = nil
          if Date().timeIntervalSince(sleepStartedAt) >= Double(self.settings.breakSeconds) {
            self.needsFreshCycleAfterWake = true
            self.overlayCoordinator?.hide()
          }
        }
      })
  }

  private func synchronizeNotificationPermission() {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      let status = settings.authorizationStatus
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard status == .notDetermined else {
          self.notificationAuthorization = status
          return
        }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .sound])
        self.refreshNotificationAuthorization()
      }
    }
  }

  private func refreshNotificationAuthorization() {
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      let status = settings.authorizationStatus
      Task { @MainActor [weak self] in
        self?.notificationAuthorization = status
      }
    }
  }

  private func sendPreBreakNotification() {
    guard notificationsEnabled else { return }
    let content = UNMutableNotificationContent()
    let minutes = max(1, Int(ceil(Double(settings.preAlertSeconds) / 60)))
    content.title = "还有 \(minutes) 分钟"
    content.body = "先保存一下工作，下一轮休息马上开始。"
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  private func saveStats() {
    defaults.set(Self.dayKey(for: Date(), calendar: calendar), forKey: Keys.statsDay)
    defaults.set(snapshot.completedBreaks, forKey: Keys.completedBreaks)
    defaults.set(snapshot.skippedBreaks, forKey: Keys.skippedBreaks)
  }

  private static func dayKey(for date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }

  private static func minuteOfDay(for date: Date, calendar: Calendar) -> Int {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
  }

  private static func formatMinute(_ minute: Int) -> String {
    let minute = min(max(minute, 0), 24 * 60 - 1)
    return String(format: "%02d:%02d", minute / 60, minute % 60)
  }
}
