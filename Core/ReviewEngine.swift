import Foundation

struct ReviewUndo {
  let before: Flashcard
  let after: Flashcard
  let logID: UUID
  func canRestore(in state: StudyState) -> Bool {
    state.cards.first(where: { $0.id == after.id }) == after
      && state.reviews.contains(where: { $0.id == logID })
  }
  func restored(_ state: StudyState) -> StudyState? {
    guard canRestore(in: state), let index = state.cards.firstIndex(where: { $0.id == before.id })
    else { return nil }
    var copy = state
    copy.cards[index] = before
    copy.reviews.removeAll { $0.id == logID }
    return copy
  }
}

/// Small, transparent SM-2-inspired scheduler with two learning steps.
/// It is not Anki's FSRS engine and does not claim personalized memory predictions.
enum ReviewEngine {
  static func graded(_ card: Flashcard, rating: RecallRating, at now: Date) -> Flashcard {
    var c = card
    c.reviews += 1
    if rating == .again {
      if card.intervalDays > 0 { c.lapses += 1 }
      c.learningStep = 0
      c.repetitions = 0
      c.intervalDays = 0
      c.ease = max(1.3, c.ease - 0.2)
      c.due = now.addingTimeInterval(60)
      return c
    }
    if card.intervalDays == 0 {
      switch rating {
      case .hard: c.due = now.addingTimeInterval(6 * 60)
      case .good:
        if card.learningStep == 0 {
          c.learningStep = 1
          c.due = now.addingTimeInterval(10 * 60)
        } else {
          c.intervalDays = 1
          c.repetitions = 1
          c.due = now.addingTimeInterval(86400)
        }
      case .easy:
        c.intervalDays = 4
        c.repetitions = 1
        c.due = now.addingTimeInterval(4 * 86400)
      case .again: break
      }
      return c
    }
    let old = card.intervalDays
    switch rating {
    case .hard:
      c.ease = max(1.3, c.ease - 0.15)
      c.intervalDays = max(old + 1, old * 1.2)
    case .good:
      c.intervalDays = card.repetitions == 1 ? max(old + 1, 6) : max(old + 1, old * c.ease)
    case .easy:
      c.ease = min(3.0, c.ease + 0.15)
      c.intervalDays = max(old + 2, old * c.ease * 1.3)
    case .again: break
    }
    c.intervalDays = min(3650, c.intervalDays.rounded())
    c.repetitions += 1
    c.due = now.addingTimeInterval(c.intervalDays * 86400)
    return c
  }

  static func queue(
    _ state: StudyState, deck: String? = nil, at now: Date,
    calendar: Calendar = ScheduleEngine.calendar()
  ) -> [Flashcard] {
    let pool = state.cards.filter { !$0.suspended && (deck == nil || $0.deck == deck) }
    let learnedToday = Set(
      state.reviews.filter { $0.wasNew && calendar.isDate($0.date, inSameDayAs: now) }.map(\.cardID)
    ).count
    let remaining = max(0, state.preferences.newCardsPerDay - learnedToday)
    let due = pool.filter { !$0.isNew && $0.due <= now }.sorted {
      $0.due == $1.due ? $0.id.uuidString < $1.id.uuidString : $0.due < $1.due
    }
    let new = pool.filter { $0.isNew && $0.due <= now }.sorted {
      $0.createdAt == $1.createdAt
        ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
    }.prefix(remaining)
    return due + new
  }

  static func intervalLabel(_ card: Flashcard, rating: RecallRating, at now: Date) -> String {
    let seconds = graded(card, rating: rating, at: now).due.timeIntervalSince(now)
    if seconds < 3600 { return "\(Int(seconds / 60)) phút" }
    if seconds < 86400 { return "\(Int(seconds / 3600)) giờ" }
    return "\(Int(seconds / 86400)) ngày"
  }

  static func importTSV(_ text: String, deck: String) throws -> [Flashcard] {
    var cards: [Flashcard] = []
    let normalized = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    let lines = normalized.replacingOccurrences(of: "\r\n", with: "\n").split(
      separator: "\n", omittingEmptySubsequences: false)
    for (index, raw) in lines.enumerated() {
      let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
      if line.isEmpty || line.hasPrefix("#") { continue }
      let fields = String(raw).components(separatedBy: "\t").map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      guard (2...3).contains(fields.count), !fields[0].trimmingCharacters(in: .whitespaces).isEmpty,
        !fields[1].trimmingCharacters(in: .whitespaces).isEmpty
      else {
        throw StudyError.invalid(
          "Dòng \(index + 1): cần 2 hoặc 3 cột: câu hỏi, đáp án và ví dụ (tùy chọn), ngăn bằng Tab."
        )
      }
      if fields[0].lowercased() == "front" && fields[1].lowercased() == "back" { continue }
      var c = Flashcard()
      c.deck = deck
      c.front = fields[0]
      c.back = fields[1]
      c.example = fields.count > 2 ? fields[2] : ""
      cards.append(c)
      guard cards.count <= 5000 else { throw StudyError.invalid("Mỗi lần nhập tối đa 5.000 thẻ.") }
    }
    guard !cards.isEmpty else { throw StudyError.invalid("Không có thẻ nào để nhập.") }
    return cards
  }
}
