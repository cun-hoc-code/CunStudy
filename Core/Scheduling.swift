import Foundation

enum ScheduleEngine {
  static func calendar(_ zone: TimeZone = .current) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = zone
    c.firstWeekday = 2
    return c
  }

  static func occurrences(
    _ lessons: [Lesson], from start: Date, days: Int = 14,
    calendar: Calendar = calendar()
  ) -> [LessonOccurrence] {
    let first = calendar.startOfDay(for: start)
    guard days > 0 else { return [] }
    var result: [LessonOccurrence] = []
    for offset in -1..<days {
      guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
      for lesson in lessons where lesson.enabled {
        let matches =
          lesson.weekly
          ? lesson.weekdays.contains(calendar.component(.weekday, from: day))
          : calendar.isDate(day, inSameDayAs: lesson.date)
        guard matches, (0..<1440).contains(lesson.startMinute), lesson.durationMinutes > 0,
          let date = calendar.date(
            bySettingHour: lesson.startMinute / 60,
            minute: lesson.startMinute % 60, second: 0, of: day)
        else { continue }
        let end = date.addingTimeInterval(Double(lesson.durationMinutes) * 60)
        if offset == -1 && end <= first { continue }
        result.append(.init(lesson: lesson, start: date, end: end))
      }
    }
    return result.sorted {
      $0.start == $1.start ? $0.lesson.title < $1.lesson.title : $0.start < $1.start
    }
  }

  static func next(_ lessons: [Lesson], at now: Date, calendar: Calendar = calendar())
    -> LessonOccurrence?
  {
    // Include one-off events beyond two weeks, as well as weekly occurrences.
    let recurring = occurrences(lessons, from: now, days: 8, calendar: calendar)
    let later = lessons.filter { !$0.weekly && $0.date > now }.flatMap {
      occurrences([$0], from: $0.date, days: 1, calendar: calendar)
    }
    return (recurring + later).filter { $0.end > now }.min { $0.start < $1.start }
  }

  static func overlaps(_ first: LessonOccurrence, _ second: LessonOccurrence) -> Bool {
    first.start < second.end && second.start < first.end
  }

  /// Shifts a local weekly time backwards, including through midnight or Sunday/Monday.
  static func shifted(weekday: Int, minute: Int, lead: Int) -> (weekday: Int, minute: Int) {
    let week = 7 * 1440
    let raw = (weekday - 1) * 1440 + minute - lead
    let value = ((raw % week) + week) % week
    return (value / 1440 + 1, value % 1440)
  }

  static func oneOffFire(_ lesson: Lesson, calendar: Calendar = calendar()) -> Date? {
    occurrences([lesson], from: lesson.date, days: 1, calendar: calendar).first?.leaveAt
  }
}

enum StudyStats {
  static func seconds(_ sessions: [FocusSession], from start: Date, to end: Date) -> Double {
    sessions.reduce(0) { total, session in
      total
        + session.segments.reduce(0) { value, segment in
          value + max(0, min(end, segment.end).timeIntervalSince(max(start, segment.start)))
        }
    }
  }

  static func daily(
    _ sessions: [FocusSession], ending now: Date, days: Int,
    calendar: Calendar = ScheduleEngine.calendar()
  ) -> [(date: Date, minutes: Double)] {
    guard days > 0 else { return [] }
    let today = calendar.startOfDay(for: now)
    return (0..<days).reversed().compactMap { distance in
      guard let start = calendar.date(byAdding: .day, value: -distance, to: today),
        let end = calendar.date(byAdding: .day, value: 1, to: start)
      else { return nil }
      return (start, seconds(sessions, from: start, to: end) / 60)
    }
  }

  static func insight(
    _ sessions: [FocusSession], at now: Date,
    calendar: Calendar = ScheduleEngine.calendar()
  ) -> String {
    let values = daily(sessions, ending: now, days: 14, calendar: calendar)
    let recent = values.suffix(7).reduce(0) { $0 + $1.minutes }
    let previous = values.prefix(7).reduce(0) { $0 + $1.minutes }
    let active = values.suffix(7).filter { $0.minutes > 0 }.count
    guard active >= 3 else {
      return "Thêm vài ngày học để thấy nhịp học của bạn. Một phiên ngắn cũng là một bước tiến."
    }
    guard previous > 0 else {
      return
        "Bạn đã tập trung \(Int(recent)) phút trong \(active) ngày gần đây. Hãy giữ nhịp học phù hợp với mình."
    }
    let change = Int(((recent - previous) / previous * 100).rounded())
    return
      "7 ngày gần đây: \(Int(recent)) phút, \(change >= 0 ? "tăng" : "giảm") \(abs(change))% so với 7 ngày trước. Đây là thời gian hẹn giờ, không phải thước đo mức hiểu bài."
  }
}
