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

  func testExplicitTimeZoneDrivesMinuteOfDayAndDayKey() {
    var shanghai = schedule
    shanghai.timeZoneIdentifier = "Asia/Shanghai"
    var losAngeles = schedule
    losAngeles.timeZoneIdentifier = "America/Los_Angeles"
    // 2026-10-12 05:57 UTC = 13:57 Shanghai (Mon) = 22:57 Los Angeles (Sun)
    let date = Date(timeIntervalSince1970: 1_791_784_620)

    XCTAssertEqual(shanghai.minuteOfDay(for: date), 13 * 60 + 57)
    XCTAssertEqual(shanghai.state(atMinute: shanghai.minuteOfDay(for: date)), .working)
    XCTAssertEqual(shanghai.dayKey(for: date), "2026-10-12")
    XCTAssertEqual(losAngeles.minuteOfDay(for: date), 22 * 60 + 57)
    XCTAssertEqual(losAngeles.state(atMinute: losAngeles.minuteOfDay(for: date)), .offHours)
    XCTAssertEqual(losAngeles.dayKey(for: date), "2026-10-11")
  }

  func testNormalizationKeepsValidTimeZoneAndDropsUnknownOne() {
    var schedule = schedule
    schedule.timeZoneIdentifier = "Asia/Shanghai"
    XCTAssertEqual(schedule.normalized().timeZoneIdentifier, "Asia/Shanghai")

    schedule.timeZoneIdentifier = "Mars/Olympus"
    XCTAssertNil(schedule.normalized().timeZoneIdentifier)
    XCTAssertEqual(schedule.normalized().timeZone, .autoupdatingCurrent)
  }

  func testDecodingLegacyScheduleWithoutTimeZoneFollowsSystem() throws {
    let json = Data(
      #"{"isEnabled":true,"workStartMinute":510,"workEndMinute":1050,"restPeriods":[]}"#.utf8)
    let decoded = try JSONDecoder().decode(DailyWorkSchedule.self, from: json)
    XCTAssertNil(decoded.timeZoneIdentifier)
  }
}
