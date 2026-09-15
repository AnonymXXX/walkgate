import XCTest

@testable import WalkGateCore

final class SessionRefreshPolicyTests: XCTestCase {
  func testClosedMenuSuppressesSecondLevelWorkingUpdatesUntilDisplayedMinuteChanges() {
    let initial = snapshot(phase: .working, remainingSeconds: 3_000)
    var policy = SessionRefreshPolicy(initialSnapshot: initial)

    XCTAssertFalse(
      policy.shouldPublish(
        snapshot(phase: .working, remainingSeconds: 2_999),
        isRealtimePresentationVisible: false
      ))
    XCTAssertTrue(
      policy.shouldPublish(
        snapshot(phase: .working, remainingSeconds: 2_940),
        isRealtimePresentationVisible: false
      ))
  }

  func testVisibleRealtimePresentationPublishesEveryChangedSecond() {
    let initial = snapshot(phase: .working, remainingSeconds: 3_000)
    var policy = SessionRefreshPolicy(initialSnapshot: initial)

    XCTAssertTrue(
      policy.shouldPublish(
        snapshot(phase: .working, remainingSeconds: 2_999),
        isRealtimePresentationVisible: true
      ))
  }

  func testPhaseTransitionAlwaysPublishesWhenMenuIsClosed() {
    let initial = snapshot(phase: .working, remainingSeconds: 1)
    var policy = SessionRefreshPolicy(initialSnapshot: initial)

    XCTAssertTrue(
      policy.shouldPublish(
        snapshot(phase: .breakGate, remainingSeconds: 300),
        isRealtimePresentationVisible: false
      ))
  }

  private func snapshot(
    phase: SessionPhase,
    remainingSeconds: Int
  ) -> SessionSnapshot {
    SessionSnapshot(
      phase: phase,
      remainingSeconds: remainingSeconds,
      deferralUsed: false,
      completedBreaks: 0,
      skippedBreaks: 0
    )
  }
}
