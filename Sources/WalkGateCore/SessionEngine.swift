import Foundation

public struct SessionSettings: Equatable, Sendable {
  public var workSeconds: Int
  public var breakSeconds: Int
  public var preAlertSeconds: Int
  public var deferralSeconds: Int

  public init(
    workSeconds: Int = 50 * 60,
    breakSeconds: Int = 2 * 60,
    preAlertSeconds: Int = 3 * 60,
    deferralSeconds: Int = 5 * 60
  ) {
    self.workSeconds = max(workSeconds, 1)
    self.breakSeconds = max(breakSeconds, 1)
    self.preAlertSeconds = max(preAlertSeconds, 0)
    self.deferralSeconds = max(deferralSeconds, 1)
  }
}

public enum SessionPhase: String, Equatable, Sendable {
  case working
  case breakGate
}

public enum SessionEvent: Equatable, Sendable {
  case none
  case preBreakWarning
  case breakBecameDue
  case breakCompleted
}

public struct SessionSnapshot: Equatable, Sendable {
  public let phase: SessionPhase
  public let remainingSeconds: Int
  public let deferralUsed: Bool
  public let completedBreaks: Int
  public let skippedBreaks: Int

  public init(
    phase: SessionPhase,
    remainingSeconds: Int,
    deferralUsed: Bool,
    completedBreaks: Int,
    skippedBreaks: Int
  ) {
    self.phase = phase
    self.remainingSeconds = remainingSeconds
    self.deferralUsed = deferralUsed
    self.completedBreaks = completedBreaks
    self.skippedBreaks = skippedBreaks
  }
}

public struct SessionEngine: Sendable {
  public private(set) var settings: SessionSettings
  public private(set) var snapshot: SessionSnapshot

  public init(
    settings: SessionSettings = SessionSettings(),
    completedBreaks: Int = 0,
    skippedBreaks: Int = 0
  ) {
    self.settings = settings
    self.snapshot = SessionSnapshot(
      phase: .working,
      remainingSeconds: settings.workSeconds,
      deferralUsed: false,
      completedBreaks: max(completedBreaks, 0),
      skippedBreaks: max(skippedBreaks, 0)
    )
  }

  @discardableResult
  public mutating func tick(isUserIdle: Bool) -> SessionEvent {
    switch snapshot.phase {
    case .working:
      let remaining = max(snapshot.remainingSeconds - 1, 0)
      if remaining == 0 {
        snapshot = replacing(phase: .breakGate, remainingSeconds: settings.breakSeconds)
        return .breakBecameDue
      }

      snapshot = replacing(remainingSeconds: remaining)
      if settings.preAlertSeconds > 0, remaining == settings.preAlertSeconds {
        return .preBreakWarning
      }
      return .none

    case .breakGate:
      guard isUserIdle else { return .none }
      let remaining = max(snapshot.remainingSeconds - 1, 0)
      if remaining == 0 {
        snapshot = SessionSnapshot(
          phase: .working,
          remainingSeconds: settings.workSeconds,
          deferralUsed: false,
          completedBreaks: snapshot.completedBreaks + 1,
          skippedBreaks: snapshot.skippedBreaks
        )
        return .breakCompleted
      }

      snapshot = replacing(remainingSeconds: remaining)
      return .none
    }
  }

  public mutating func startBreakNow() {
    snapshot = replacing(phase: .breakGate, remainingSeconds: settings.breakSeconds)
  }

  @discardableResult
  public mutating func deferBreak() -> Bool {
    guard snapshot.phase == .breakGate, !snapshot.deferralUsed else { return false }
    snapshot = replacing(
      phase: .working,
      remainingSeconds: settings.deferralSeconds,
      deferralUsed: true
    )
    return true
  }

  public mutating func skipBreak() {
    guard snapshot.phase == .breakGate else { return }
    snapshot = SessionSnapshot(
      phase: .working,
      remainingSeconds: settings.workSeconds,
      deferralUsed: false,
      completedBreaks: snapshot.completedBreaks,
      skippedBreaks: snapshot.skippedBreaks + 1
    )
  }

  public mutating func pauseForMeeting(seconds: Int) {
    snapshot = SessionSnapshot(
      phase: .working,
      remainingSeconds: max(seconds, 1),
      deferralUsed: snapshot.deferralUsed,
      completedBreaks: snapshot.completedBreaks,
      skippedBreaks: snapshot.skippedBreaks
    )
  }

  public mutating func updateSettings(_ settings: SessionSettings) {
    self.settings = settings
    let remaining = snapshot.phase == .working ? settings.workSeconds : settings.breakSeconds
    snapshot = replacing(remainingSeconds: remaining)
  }

  private func replacing(
    phase: SessionPhase? = nil,
    remainingSeconds: Int? = nil,
    deferralUsed: Bool? = nil
  ) -> SessionSnapshot {
    SessionSnapshot(
      phase: phase ?? snapshot.phase,
      remainingSeconds: remainingSeconds ?? snapshot.remainingSeconds,
      deferralUsed: deferralUsed ?? snapshot.deferralUsed,
      completedBreaks: snapshot.completedBreaks,
      skippedBreaks: snapshot.skippedBreaks
    )
  }
}
