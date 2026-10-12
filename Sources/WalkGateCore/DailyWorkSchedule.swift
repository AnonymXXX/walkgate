import Foundation

public enum WorkdayState: String, Codable, Equatable, Sendable {
  case working
  case resting
  case offHours
}

public struct DailyRestPeriod: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var startMinute: Int
  public var endMinute: Int

  public init(id: UUID = UUID(), startMinute: Int, endMinute: Int) {
    self.id = id
    self.startMinute = startMinute
    self.endMinute = endMinute
  }
}

public struct DailyWorkSchedule: Codable, Equatable, Sendable {
  public var isEnabled: Bool
  public var workStartMinute: Int
  public var workEndMinute: Int
  public var restPeriods: [DailyRestPeriod]
  /// IANA identifier the schedule times are interpreted in; `nil` follows the system time zone.
  public var timeZoneIdentifier: String?

  public init(
    isEnabled: Bool,
    workStartMinute: Int,
    workEndMinute: Int,
    restPeriods: [DailyRestPeriod],
    timeZoneIdentifier: String? = nil
  ) {
    self.isEnabled = isEnabled
    self.workStartMinute = workStartMinute
    self.workEndMinute = workEndMinute
    self.restPeriods = restPeriods
    self.timeZoneIdentifier = timeZoneIdentifier
  }

  public var timeZone: TimeZone {
    timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
  }

  public var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }

  public func minuteOfDay(for date: Date) -> Int {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
  }

  public func dayKey(for date: Date) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }

  public static let defaultSchedule = DailyWorkSchedule(
    isEnabled: true,
    workStartMinute: 8 * 60 + 30,
    workEndMinute: 17 * 60 + 30,
    restPeriods: [DailyRestPeriod(startMinute: 12 * 60, endMinute: 13 * 60 + 30)]
  )

  public func state(atMinute minute: Int) -> WorkdayState {
    guard isEnabled else { return .working }
    let normalized = normalized()
    let minute = min(max(minute, 0), 24 * 60 - 1)
    guard minute >= normalized.workStartMinute, minute < normalized.workEndMinute else {
      return .offHours
    }
    return normalized.restPeriods.contains {
      minute >= $0.startMinute && minute < $0.endMinute
    } ? .resting : .working
  }

  public func activeRestPeriod(atMinute minute: Int) -> DailyRestPeriod? {
    guard isEnabled else { return nil }
    return normalized().restPeriods.first {
      minute >= $0.startMinute && minute < $0.endMinute
    }
  }

  public func normalized() -> DailyWorkSchedule {
    let start = min(max(workStartMinute, 0), 24 * 60 - 1)
    let end = min(max(workEndMinute, start + 1), 24 * 60)
    let candidates = restPeriods.compactMap { period -> DailyRestPeriod? in
      let periodStart = min(max(period.startMinute, start), end)
      let periodEnd = min(max(period.endMinute, start), end)
      guard periodStart < periodEnd else { return nil }
      return DailyRestPeriod(id: period.id, startMinute: periodStart, endMinute: periodEnd)
    }.sorted {
      if $0.startMinute == $1.startMinute { return $0.endMinute < $1.endMinute }
      return $0.startMinute < $1.startMinute
    }
    let periods = candidates.reduce(into: [DailyRestPeriod]()) { merged, period in
      guard let last = merged.last, period.startMinute <= last.endMinute else {
        merged.append(period)
        return
      }
      merged[merged.count - 1].endMinute = max(last.endMinute, period.endMinute)
    }

    return DailyWorkSchedule(
      isEnabled: isEnabled,
      workStartMinute: start,
      workEndMinute: end,
      restPeriods: periods,
      timeZoneIdentifier: timeZoneIdentifier.flatMap(TimeZone.init(identifier:))?.identifier
    )
  }
}
