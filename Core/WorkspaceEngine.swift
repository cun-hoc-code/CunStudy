import Foundation

enum WorkspaceEngine {
  static func freeSlots(
    _ state: StudyState, on day: Date, minutes: Int = 25, now: Date = Date(),
    calendar: Calendar = ScheduleEngine.calendar()
  ) -> [DateInterval] {
    guard (5...240).contains(minutes),
      let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day),
      let end = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)
    else { return [] }
    let yesterday = calendar.date(byAdding: .day, value: -1, to: day) ?? day
    var busy = ScheduleEngine.occurrences(
      state.lessons, from: yesterday, days: 2, calendar: calendar
    ).map { DateInterval(start: $0.start, end: $0.end) }
    busy += state.studio.blocks.map { DateInterval(start: $0.start, end: $0.end) }
    busy += state.studio.calendarRecords.filter { $0.end > $0.start }.map {
      DateInterval(start: $0.start, end: $0.end)
    }
    busy = busy.filter { $0.start < end && $0.end > start }.sorted { $0.start < $1.start }
    var cursor = max(start, now)
    var slots: [DateInterval] = []
    let length = Double(minutes * 60)
    for item in busy {
      if item.start.timeIntervalSince(cursor) >= length {
        slots.append(DateInterval(start: cursor, end: min(item.start, end)))
      }
      cursor = max(cursor, item.end)
    }
    if end.timeIntervalSince(cursor) >= length {
      slots.append(DateInterval(start: cursor, end: end))
    }
    return slots
  }
  static func finalScore(_ c: AcademicCourse) -> Double? {
    guard abs(c.components.reduce(0, { $0 + $1.weight }) - 100) < 0.001, !c.components.isEmpty,
      c.components.allSatisfy({ $0.score != nil })
    else { return nil }
    return c.components.reduce(0) { $0 + ($1.score ?? 0) * $1.weight / 100 }
  }
  static func requiredScore(_ c: AcademicCourse, target: Double) -> Double? {
    guard abs(c.components.reduce(0, { $0 + $1.weight }) - 100) < 0.001 else { return nil }
    let remaining = c.components.filter { $0.score == nil }.reduce(0) { $0 + $1.weight }
    guard remaining > 0 else { return nil }
    let earned = c.components.reduce(0) { $0 + ($1.score ?? 0) * $1.weight / 100 }
    return max(0, (target - earned) * 100 / remaining)
  }
  static func gpa(_ courses: [AcademicCourse]) -> Double? {
    let items = courses.filter { $0.officialGrade4 != nil }
    let credits = items.reduce(0) { $0 + $1.credits }
    return credits == 0
      ? nil
      : items.reduce(0) { $0 + ($1.officialGrade4 ?? 0) * Double($1.credits) } / Double(credits)
  }
  static func goalProgress(_ goal: LearningGoal, state: StudyState) -> Int {
    switch goal.unit {
    case .chapters: return goal.manualProgress
    case .tasks:
      return state.tasks.filter {
        $0.done && ($0.completedAt.map { $0 >= goal.start && $0 < goal.end } ?? false)
      }.count
    case .cards:
      return Set(state.reviews.filter { $0.date >= goal.start && $0.date < goal.end }.map(\.cardID))
        .count
    case .minutes:
      return Int(
        state.sessions.flatMap(\.segments).reduce(0.0) {
          $0 + max(0, min($1.end, goal.end).timeIntervalSince(max($1.start, goal.start)))
        } / 60)
    }
  }
  static func shares(_ bill: SharedBill) -> [(name: String, amount: Int64)] {
    guard !bill.members.isEmpty, bill.amount >= 0 else { return [] }
    let count = Int64(bill.members.count)
    return bill.members.enumerated().map {
      ($0.element, bill.amount / count + (Int64($0.offset) < bill.amount % count ? 1 : 0))
    }
  }
  static func links(in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\[\]\n]+)\]\]"#) else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
      Range($0.range(at: 1), in: text).map { String(text[$0]).trimmingCharacters(in: .whitespaces) }
    }
  }
  static func questions(from cards: [Flashcard]) -> [PracticeQuestion] {
    let valid = cards.filter { $0.hasValidContent && !$0.suspended }
    return valid.compactMap { card in
      let distractors = Array(
        Set(valid.filter { $0.id != card.id && $0.deck == card.deck }.map(\.answer))
      ).filter { $0 != card.answer }
      guard !distractors.isEmpty else { return nil }
      let options = (Array(distractors.shuffled().prefix(3)) + [card.answer]).shuffled()
      return PracticeQuestion(
        subject: card.deck, chapter: "Flashcard", prompt: card.question, options: options,
        correctIndex: options.firstIndex(of: card.answer) ?? 0,
        explanation: card.example.isEmpty ? card.answer : card.example, sourceCardID: card.id)
    }
  }
  static func cardDrafts(from text: String, deck: String) -> [Flashcard] {
    text.components(separatedBy: .newlines).compactMap { source in
      let line = source.trimmingCharacters(in: .whitespacesAndNewlines)
      guard (4...4000).contains(line.count) else { return nil }
      var card = Flashcard()
      card.deck = deck.isEmpty ? "Từ ghi chú" : deck
      if line.range(of: Flashcard.clozePattern, options: .regularExpression) != nil {
        card.kind = .cloze
        card.front = line
        return card
      }
      guard let separator = line.firstIndex(of: ":") else { return nil }
      card.front = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
      card.back = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
      return card.hasValidContent ? card : nil
    }
  }
}
enum WorkspaceValidation {
  static func safeFilename(_ name: String) -> Bool {
    !name.isEmpty && name.count < 160 && !name.hasPrefix(".") && !name.contains("/")
      && !name.contains("\\") && !name.contains("\0")
  }
  static func validate(_ state: StudyState) throws {
    let s = state.studio
    func require(_ yes: Bool, _ message: String) throws {
      if !yes { throw StudyError.invalid(message) }
    }
    func unique<T: Identifiable>(_ array: [T]) -> Bool where T.ID: Hashable {
      Set(array.map(\.id)).count == array.count
    }
    try require(
      unique(s.documents) && unique(s.blocks) && unique(s.journals) && unique(s.questions)
        && unique(s.attempts) && unique(s.courses) && unique(s.goals) && unique(s.expenses)
        && unique(s.bills) && unique(s.calendarRecords), "Mã bản ghi Góc học tập bị trùng.")
    try require(
      s.documents.count <= 10000 && s.questions.count <= 30000 && s.attempts.count <= 10000,
      "Quá nhiều tài liệu hoặc đề ôn tập.")
    try require(
      ["vi", "en"].contains(s.settings.language) && (0...23).contains(s.settings.streakHour)
        && (1...1000).contains(s.settings.graduationCredits)
        && (0...1_000_000_000_000).contains(s.settings.monthlyBudget), "Thiết lập không hợp lệ.")
    try require(unique(s.readingRoom.books), "Mã sách bị trùng.")
    let documentIDs = Set(s.documents.map(\.id))
    for book in s.readingRoom.books {
      try require(
        documentIDs.contains(book.documentID)
          && !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && book.textOffset >= 0 && book.pdfPage >= 0
          && book.bookmarks.allSatisfy { $0 >= 0 }
          && book.pdfBookmarks.allSatisfy { $0 >= 0 }
          && (12...36).contains(book.preferences.size)
          && (0...16).contains(book.preferences.lineSpacing),
        "Vị trí đọc hoặc cỡ chữ không hợp lệ.")
    }
    try require(
      (0...0.5).contains(s.interaction.volume) && (0...1).contains(s.interaction.strength),
      "Mức phản hồi không hợp lệ.")
    for t in state.tasks {
      try require((0...10080).contains(t.reminderLeadMinutes ?? 0), "Nhắc trước tối đa 7 ngày.")
    }
    for d in s.documents {
      try require(d.filename.map(safeFilename) ?? true, "Tên tệp không hợp lệ.")
      try require(
        d.extractedText.count <= 2_000_000 && d.bookmarks.allSatisfy { $0 >= 0 },
        "Nội dung tài liệu không hợp lệ.")
      if let link = d.link {
        try require(
          ["https", "http"].contains(URL(string: link)?.scheme?.lowercased() ?? "")
            && !(URL(string: link)?.host ?? "").isEmpty,
          "Link cần bắt đầu bằng https:// hoặc http://.")
      }
    }
    for n in state.notes { try require(unique(n.details.checklist), "Checklist có mã trùng.") }
    for b in s.blocks {
      try require(
        !b.title.isEmpty && b.end > b.start && b.end.timeIntervalSince(b.start) <= 86400
          && (0...10080).contains(b.reminderMinutes ?? 0), "Khung học không hợp lệ.")
    }
    for e in s.calendarRecords { try require(e.end >= e.start, "Sự kiện không hợp lệ.") }
    for j in s.journals {
      try require(
        (0...1440).contains(j.minutes) && (1...5).contains(j.mood), "Nhật ký không hợp lệ.")
    }
    func question(_ q: PracticeQuestion) throws {
      try require(
        !q.prompt.isEmpty && (2...8).contains(q.options.count)
          && q.options.indices.contains(q.correctIndex)
          && q.options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
        "Câu hỏi cần ít nhất hai lựa chọn và một đáp án đúng.")
    }
    func answers(_ values: [PracticeAnswer]) throws {
      try require(unique(values) && values.count <= 500, "Đề có câu trùng hoặc quá 500 câu.")
      for a in values {
        try question(a.question)
        try require(
          a.selectedIndex.map { a.question.options.indices.contains($0) } ?? true,
          "Đáp án chọn không hợp lệ.")
      }
    }
    for q in s.questions { try question(q) }
    for a in s.attempts {
      try answers(a.answers)
      try require(a.finishedAt >= a.startedAt, "Thời gian thi không hợp lệ.")
    }
    if let r = s.runningTest {
      try answers(r.answers)
      try require(
        !r.answers.isEmpty && r.answers.indices.contains(r.position) && r.deadline > r.startedAt
          && !s.attempts.contains { $0.id == r.id }, "Phiên thi không hợp lệ.")
    }
    for c in s.courses {
      try require(
        (1...100).contains(c.credits) && (c.officialGrade4.map { (0...4).contains($0) } ?? true)
          && unique(c.components), "Điểm hoặc tín chỉ không hợp lệ.")
      try require(c.components.reduce(0, { $0 + $1.weight }) <= 100.001, "Trọng số vượt 100%.")
      for p in c.components {
        try require(
          (0...100).contains(p.weight) && (p.score.map { (0...10).contains($0) } ?? true),
          "Điểm thành phần không hợp lệ.")
      }
    }
    for g in s.goals {
      try require(
        g.end > g.start && (1...100000).contains(g.target)
          && (0...100000).contains(g.manualProgress), "Mục tiêu không hợp lệ.")
    }
    for e in s.expenses {
      try require((0...1_000_000_000_000).contains(e.amount), "Số tiền không hợp lệ.")
    }
    for b in s.bills {
      try require(
        (0...1_000_000_000_000).contains(b.amount) && (1...100).contains(b.members.count)
          && Set(b.members).count == b.members.count
          && b.members.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
          && b.members.contains(b.payer) && b.settledMembers.allSatisfy { b.members.contains($0) },
        "Thành viên hoặc khoản chia không hợp lệ.")
    }
  }
}
