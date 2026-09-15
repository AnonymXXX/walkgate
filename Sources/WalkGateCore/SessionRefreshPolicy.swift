import Foundation

/// Limits background UI publication while preserving live countdowns when a presentation is visible.
public struct SessionRefreshPolicy: Sendable {
  private var lastPublishedSnapshot: SessionSnapshot

  public init(initialSnapshot: SessionSnapshot) {
    self.lastPublishedSnapshot = initialSnapshot
  }

  public mutating func shouldPublish(
    _ snapshot: SessionSnapshot,
    isRealtimePresentationVisible: Bool
  ) -> Bool {
    guard snapshot != lastPublishedSnapshot else { return false }

    let shouldPublish =
      isRealtimePresentationVisible
      || hasSignificantStateChange(from: lastPublishedSnapshot, to: snapshot)
      || displayedWorkingMinute(for: lastPublishedSnapshot)
        != displayedWorkingMinute(for: snapshot)

    if shouldPublish {
      lastPublishedSnapshot = snapshot
    }
    return shouldPublish
  }

  public mutating func markPublished(_ snapshot: SessionSnapshot) {
    lastPublishedSnapshot = snapshot
  }

  private func hasSignificantStateChange(
    from previous: SessionSnapshot,
    to current: SessionSnapshot
  ) -> Bool {
    previous.phase != current.phase
      || previous.deferralUsed != current.deferralUsed
      || previous.completedBreaks != current.completedBreaks
      || previous.skippedBreaks != current.skippedBreaks
      || (previous.remainingSeconds > 0) != (current.remainingSeconds > 0)
  }

  private func displayedWorkingMinute(for snapshot: SessionSnapshot) -> Int? {
    guard snapshot.phase == .working else { return nil }
    return max(1, Int(ceil(Double(snapshot.remainingSeconds) / 60)))
  }
}
