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
  @Published private(set) var isUserAway = false
  @Published var notificationsEnabled: Bool
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
  }

  private var engine: SessionEngine
  private var timer: Timer?
  private var overlayCoordinator: BreakOverlayCoordinator?
  private let defaults: UserDefaults
  private let calendar: Calendar

  init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
    self.defaults = defaults
    self.calendar = calendar

    let settings = SessionSettings(
      workSeconds: defaults.object(forKey: Keys.workSeconds) as? Int ?? 50 * 60,
      breakSeconds: defaults.object(forKey: Keys.breakSeconds) as? Int ?? 2 * 60,
      preAlertSeconds: defaults.object(forKey: Keys.preAlertSeconds) as? Int ?? 3 * 60,
      deferralSeconds: 5 * 60
    )
    self.settings = settings

    let today = Self.dayKey(for: Date(), calendar: calendar)
    let storedDay = defaults.string(forKey: Keys.statsDay)
    let completed = storedDay == today ? defaults.integer(forKey: Keys.completedBreaks) : 0
    let skipped = storedDay == today ? defaults.integer(forKey: Keys.skippedBreaks) : 0
    self.engine = SessionEngine(
      settings: settings, completedBreaks: completed, skippedBreaks: skipped)
    self.snapshot = engine.snapshot

    self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

    defaults.set(today, forKey: Keys.statsDay)
    DispatchQueue.main.async { [weak self] in
      self?.start()
    }
  }

  deinit {
    timer?.invalidate()
  }

  var formattedRemaining: String {
    let minutes = snapshot.remainingSeconds / 60
    let seconds = snapshot.remainingSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  var menuBarTitle: String {
    snapshot.phase == .working
      ? "\(max(1, Int(ceil(Double(snapshot.remainingSeconds) / 60))))m" : "走一走"
  }

  var progress: Double {
    let total = snapshot.phase == .working ? settings.workSeconds : settings.breakSeconds
    guard total > 0 else { return 0 }
    return 1 - (Double(snapshot.remainingSeconds) / Double(total))
  }

  func startBreakNow() {
    engine.startBreakNow()
    publishSnapshot()
    overlayCoordinator?.show()
  }

  func deferBreak() {
    guard engine.deferBreak() else { return }
    publishSnapshot()
    overlayCoordinator?.hide()
  }

  func skipBreak() {
    engine.skipBreak()
    publishSnapshot()
    saveStats()
    overlayCoordinator?.hide()
  }

  func pauseForMeeting(minutes: Int) {
    engine.pauseForMeeting(seconds: minutes * 60)
    publishSnapshot()
    overlayCoordinator?.hide()
  }

  func applySettings(_ settings: SessionSettings) {
    self.settings = settings
    engine.updateSettings(settings)
    publishSnapshot()
    defaults.set(settings.workSeconds, forKey: Keys.workSeconds)
    defaults.set(settings.breakSeconds, forKey: Keys.breakSeconds)
    defaults.set(settings.preAlertSeconds, forKey: Keys.preAlertSeconds)
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    notificationsEnabled = enabled
    defaults.set(enabled, forKey: Keys.notificationsEnabled)
    if enabled {
      requestNotificationPermission()
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

  private func start() {
    guard timer == nil else { return }
    overlayCoordinator = BreakOverlayCoordinator(session: self)
    if notificationsEnabled {
      requestNotificationPermission()
    }

    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tick()
      }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func tick() {
    let idleSeconds = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: CGEventType(rawValue: UInt32.max)!
    )
    isUserAway = idleSeconds >= 5

    let event = engine.tick(isUserIdle: isUserAway)
    publishSnapshot()

    switch event {
    case .preBreakWarning:
      sendPreBreakNotification()
    case .breakBecameDue:
      overlayCoordinator?.show()
    case .breakCompleted:
      saveStats()
      overlayCoordinator?.hide()
      NSSound(named: "Glass")?.play()
    case .none:
      break
    }
  }

  private func publishSnapshot() {
    snapshot = engine.snapshot
  }

  private func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
}
