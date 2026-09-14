import XCTest

@testable import WalkGateCore

final class SessionEngineTests: XCTestCase {
  func testProgressUsesCurrentPhaseDuration() {
    var engine = SessionEngine(
      settings: SessionSettings(workSeconds: 100, breakSeconds: 4, deferralSeconds: 2))
    XCTAssertEqual(engine.progress, 0)
    engine.pauseForMeeting(seconds: 200)
    for _ in 0..<100 { engine.tick(isUserIdle: false) }
    XCTAssertEqual(engine.progress, 0.5)
    engine.startBreakNow()
    XCTAssertEqual(engine.progress, 0)
    engine.tick(isUserIdle: false)
    XCTAssertEqual(engine.progress, 0)
    engine.tick(isUserIdle: true)
    XCTAssertEqual(engine.progress, 0.25)
    XCTAssertTrue(engine.deferBreak())
    XCTAssertEqual(engine.progress, 0)
    engine.tick(isUserIdle: false)
    XCTAssertEqual(engine.progress, 0.5)
    engine.tick(isUserIdle: false)
    XCTAssertEqual(engine.progress, 0)
  }
  private let settings = SessionSettings(
    workSeconds: 3,
    breakSeconds: 2,
    preAlertSeconds: 1,
    deferralSeconds: 2
  )

  func testWorkCountdownWarnsThenOpensBreakGate() {
    var engine = SessionEngine(settings: settings)

    XCTAssertEqual(engine.tick(isUserIdle: false), .none)
    XCTAssertEqual(engine.tick(isUserIdle: false), .preBreakWarning)
    XCTAssertEqual(engine.tick(isUserIdle: false), .breakBecameDue)
    XCTAssertEqual(engine.snapshot.phase, .breakGate)
    XCTAssertEqual(engine.snapshot.remainingSeconds, 2)
  }

  func testBreakCountdownOnlyAdvancesWhileUserIsIdle() {
    var engine = SessionEngine(settings: settings)
    engine.startBreakNow()

    XCTAssertEqual(engine.tick(isUserIdle: false), .none)
    XCTAssertEqual(engine.snapshot.remainingSeconds, 2)
    XCTAssertEqual(engine.tick(isUserIdle: true), .none)
    XCTAssertEqual(engine.snapshot.remainingSeconds, 1)
    XCTAssertEqual(engine.tick(isUserIdle: true), .breakCompleted)
    XCTAssertEqual(engine.snapshot.phase, .working)
    XCTAssertEqual(engine.snapshot.completedBreaks, 1)
  }

  func testBreakCanOnlyBeDeferredOncePerCycle() {
    var engine = SessionEngine(settings: settings)
    engine.startBreakNow()

    XCTAssertTrue(engine.deferBreak())
    XCTAssertEqual(engine.snapshot.phase, .working)
    XCTAssertEqual(engine.snapshot.remainingSeconds, 2)

    _ = engine.tick(isUserIdle: false)
    _ = engine.tick(isUserIdle: false)
    XCTAssertEqual(engine.snapshot.phase, .breakGate)
    XCTAssertFalse(engine.deferBreak())
  }

  func testEmergencySkipIsRecorded() {
    var engine = SessionEngine(settings: settings)
    engine.startBreakNow()
    engine.skipBreak()

    XCTAssertEqual(engine.snapshot.phase, .working)
    XCTAssertEqual(engine.snapshot.skippedBreaks, 1)
    XCTAssertEqual(engine.snapshot.completedBreaks, 0)
  }
}
