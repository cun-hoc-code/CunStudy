import Foundation

struct StudyDay: Identifiable, Equatable {
  var date: Date
  var focusSeconds = 0.0
  var reviewCount = 0
  var rememberedCount = 0
  var cardIDs: Set<UUID> = []
  var completedSessions = 0
  var tasksDone = 0
  var id: Date { date }
  var minutes: Double { focusSeconds / 60 }
  var uniqueCards: Int { cardIDs.count }
  // A small, consistent action counts; repeated grading of one card cannot farm a streak.
  var qualifies: Bool { focusSeconds >= 300 || uniqueCards >= 5 }
  var xp: Int { min(120, Int(minutes)) * 2 + min(100, uniqueCards) * 5 }
}

struct ProgressSummary {
  let days: [StudyDay]
  let today: StudyDay
  let currentStreak: Int
  let bestStreak: Int
  var xp: Int { days.reduce(0) { $0 + $1.xp } }
  var level: Int { xp / 250 + 1 }
  var levelProgress: Double { Double(xp % 250) / 250 }
  var levelTitle: String {
    switch level {
    case 1...2: return "Hạt giống"
    case 3...5: return "Mầm non"
    case 6...10: return "Tán lá"
    default: return "Khu vườn"
    }
  }
  var completedSessions: Int { days.reduce(0) { $0 + $1.completedSessions } }
  var reviews: Int { days.reduce(0) { $0 + $1.reviewCount } }
}

struct StudyBadge: Identifiable {
  let id: String
  let title: String
  let detail: String
  let symbol: String
  let unlocked: Bool
}

enum StudyProgress {
  /// Calendar-day buckets, including time split across midnight and DST.
  /// Only persisted work up to `now` counts. Nothing is inferred from a running timer.
  static func summary(
    _ state: StudyState, at now: Date,
    calendar: Calendar = ScheduleEngine.calendar()
  ) -> ProgressSummary {
    var buckets: [Date: StudyDay] = [:]
    for session in state.sessions {
      for segment in session.segments {
        var cursor = segment.start
        let end = min(segment.end, now)
        while cursor < end {
          let day = calendar.startOfDay(for: cursor)
          guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > cursor else {
            break
          }
          let stop = min(next, end)
          buckets[day, default: StudyDay(date: day)].focusSeconds += stop.timeIntervalSince(cursor)
          cursor = stop
        }
      }
      if session.completed && session.finishedAt <= now {
        let day = calendar.startOfDay(for: session.finishedAt)
        buckets[day, default: StudyDay(date: day)].completedSessions += 1
      }
    }
    for log in state.reviews where log.date <= now {
      let day = calendar.startOfDay(for: log.date)
      buckets[day, default: StudyDay(date: day)].reviewCount += 1
      buckets[day, default: StudyDay(date: day)].cardIDs.insert(log.cardID)
      if log.rating != .again { buckets[day, default: StudyDay(date: day)].rememberedCount += 1 }
    }
    for task in state.tasks where task.done {
      guard let date = task.completedAt, date <= now else { continue }
      let day = calendar.startOfDay(for: date)
      buckets[day, default: StudyDay(date: day)].tasksDone += 1
    }
    let today = calendar.startOfDay(for: now)
    let todayValue = buckets[today] ?? StudyDay(date: today)
    let qualified = Set(buckets.values.filter(\.qualifies).map(\.date))
    var cursor =
      todayValue.qualifies ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
    var current = 0
    while qualified.contains(cursor) {
      current += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    var best = 0
    var run = 0
    var previous: Date?
    for day in qualified.sorted() {
      let consecutive = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } == day
      run = consecutive ? run + 1 : 1
      best = max(best, run)
      previous = day
    }
    return ProgressSummary(
      days: buckets.values.sorted { $0.date < $1.date }, today: todayValue,
      currentStreak: current, bestStreak: best)
  }

  static func recentDays(
    _ summary: ProgressSummary, count: Int, at now: Date,
    calendar: Calendar = ScheduleEngine.calendar()
  ) -> [StudyDay] {
    guard count > 0 else { return [] }
    let buckets = Dictionary(uniqueKeysWithValues: summary.days.map { ($0.date, $0) })
    let today = calendar.startOfDay(for: now)
    return (0..<count).reversed().compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
      return buckets[date] ?? StudyDay(date: date)
    }
  }

  static func badges(_ value: ProgressSummary) -> [StudyBadge] {
    [
      .init(
        id: "first", title: "Mầm đầu tiên", detail: "Hoàn thành 1 phiên", symbol: "leaf",
        unlocked: value.completedSessions >= 1),
      .init(
        id: "three", title: "Bắt nhịp", detail: "Streak 3 ngày", symbol: "flame",
        unlocked: value.bestStreak >= 3),
      .init(
        id: "week", title: "Một tuần xanh", detail: "Streak 7 ngày", symbol: "sun.max",
        unlocked: value.bestStreak >= 7),
      .init(
        id: "month", title: "Bền bỉ", detail: "Streak 30 ngày", symbol: "tree",
        unlocked: value.bestStreak >= 30),
      .init(
        id: "cards", title: "Gom kiến thức", detail: "100 lượt ôn thẻ", symbol: "rectangle.stack",
        unlocked: value.reviews >= 100),
      .init(
        id: "garden", title: "Vườn nhỏ", detail: "Hoàn thành 20 phiên", symbol: "leaf.circle",
        unlocked: value.completedSessions >= 20),
    ]
  }
}
