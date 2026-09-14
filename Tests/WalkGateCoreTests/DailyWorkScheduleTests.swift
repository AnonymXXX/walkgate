import XCTest

@testable import WalkGateCore

final class DailyWorkScheduleTests: XCTestCase {
  private let schedule = DailyWorkSchedule(
    isEnabled: true,
    workStartMinute: 8 * 60 + 30,
    workEndMinute: 18 * 60,
    restPeriods: [
      DailyRestPeriod(startMinute: 12 * 60, endMinute: 13 * 60 + 30),
      DailyRestPeriod(startMinute: 15 * 60 + 30, endMinute: 15 * 60 + 45),
    ]
  )

  func testMultipleRestPeriodsAndWorkBoundaries() {
    XCTAssertEqual(schedule.state(atMinute: 8 * 60 + 29), .offHours)
    XCTAssertEqual(schedule.state(atMinute: 8 * 60 + 30), .working)
    XCTAssertEqual(schedule.state(atMinute: 12 * 60), .resting)
    XCTAssertEqual(schedule.state(atMinute: 13 * 60 + 29), .resting)
    XCTAssertEqual(schedule.state(atMinute: 13 * 60 + 30), .working)
    XCTAssertEqual(schedule.state(atMinute: 15 * 60 + 30), .resting)
    XCTAssertEqual(schedule.state(atMinute: 15 * 60 + 45), .working)
    XCTAssertEqual(schedule.state(atMinute: 18 * 60), .offHours)
  }

  func testDisabledScheduleAlwaysAllowsWork() {
    var disabled = schedule
    disabled.isEnabled = false

    XCTAssertEqual(disabled.state(atMinute: 0), .working)
    XCTAssertEqual(disabled.state(atMinute: 12 * 60 + 30), .working)
    XCTAssertEqual(disabled.state(atMinute: 23 * 60 + 59), .working)
  }

  func testNormalizationSortsAndDropsInvalidRestPeriods() {
    let schedule = DailyWorkSchedule(
      isEnabled: true,
      workStartMinute: 8 * 60 + 30,
      workEndMinute: 18 * 60,
      restPeriods: [
        DailyRestPeriod(startMinute: 16 * 60, endMinute: 15 * 60),
        DailyRestPeriod(startMinute: 15 * 60, endMinute: 15 * 60 + 10),
        DailyRestPeriod(startMinute: 12 * 60, endMinute: 13 * 60 + 30),
      ]
    ).normalized()

    XCTAssertEqual(schedule.restPeriods.map(\.startMinute), [12 * 60, 15 * 60])
  }

  func testNormalizationMergesOverlappingRestPeriods() {
    let schedule = DailyWorkSchedule(
      isEnabled: true,
      workStartMinute: 8 * 60 + 30,
      workEndMinute: 18 * 60,
      restPeriods: [
        DailyRestPeriod(startMinute: 12 * 60, endMinute: 13 * 60),
        DailyRestPeriod(startMinute: 12 * 60 + 30, endMinute: 13 * 60 + 30),
      ]
    ).normalized()

    XCTAssertEqual(schedule.restPeriods.count, 1)
    XCTAssertEqual(schedule.restPeriods[0].startMinute, 12 * 60)
    XCTAssertEqual(schedule.restPeriods[0].endMinute, 13 * 60 + 30)
  }
}
