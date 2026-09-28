import Foundation

enum StudyError: LocalizedError {
  case invalid(String)
  var errorDescription: String? {
    if case let .invalid(message) = self { return message }
    return nil
  }
}

enum StateCodec {
  static func encode(_ state: StudyState) throws -> Data {
    let encoder = JSONEncoder()
    let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(format.format(date))
    }
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    guard data.count <= 25 * 1024 * 1024 else {
      throw StudyError.invalid("Dữ liệu vượt 25 MB. Hãy rút gọn các ghi chú hoặc bộ thẻ quá lớn.")
    }
    return data
  }
  static func decode(_ data: Data) throws -> StudyState {
    guard data.count <= 25 * 1024 * 1024 else {
      throw StudyError.invalid("Bản sao lưu lớn hơn 25 MB.")
    }
    let decoder = JSONDecoder()
    let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    let legacy = Date.ISO8601FormatStyle()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let text = try container.decode(String.self)
      if let date = try? fractional.parse(text) { return date }
      if let date = try? legacy.parse(text) { return date }
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid ISO-8601 date")
    }
    let state = try decoder.decode(StudyState.self, from: data)
    try validate(state)
    return state
  }

  /// Freeze the exported copy, without stopping the timer running in the app.
  static func backupSnapshot(_ state: StudyState, at now: Date) -> StudyState {
    var copy = state
    if var active = copy.activeFocus {
      active.pause(at: now)
      if active.savedSeconds >= active.plannedSeconds {
        if !copy.sessions.contains(where: { $0.id == active.id }) {
          copy.sessions.append(active.finish(at: now))
        }
        copy.activeFocus = nil
      } else {
        copy.activeFocus = active
      }
    }
    return copy
  }

  /// A historical timer must never count the time between backup and restore.
  static func restoredSnapshot(_ state: StudyState) -> StudyState {
    var copy = state
    copy.activeFocus?.runningSince = nil
    return copy
  }
  static func validate(_ state: StudyState) throws {
    try WorkspaceValidation.validate(state)
    guard (1...2).contains(state.schemaVersion) else {
      throw StudyError.invalid("Phiên bản dữ liệu chưa được hỗ trợ.")
    }
    guard state.lessons.count <= 2000, state.cards.count <= 30000 else {
      throw StudyError.invalid("Dữ liệu vượt giới hạn nhập.")
    }
    func unique<T: Identifiable>(_ values: [T]) -> Bool where T.ID: Hashable {
      Set(values.map(\.id)).count == values.count
    }
    guard unique(state.lessons), unique(state.tasks), unique(state.notes), unique(state.cards),
      unique(state.sessions), unique(state.reviews)
    else {
      throw StudyError.invalid("Bản sao lưu có mã bản ghi trùng.")
    }
    for lesson in state.lessons {
      guard !lesson.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        (0..<1440).contains(lesson.startMinute), (1...720).contains(lesson.durationMinutes),
        (0...1440).contains(lesson.leadMinutes),
        lesson.weekdays.allSatisfy({ (1...7).contains($0) }),
        Set(lesson.weekdays).count == lesson.weekdays.count,
        !lesson.weekly || !lesson.weekdays.isEmpty
      else { throw StudyError.invalid("Lịch học có thời gian không hợp lệ.") }
    }
    for task in state.tasks {
      guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        unique(task.subtasks),
        task.subtasks.allSatisfy({
          !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }),
        !task.remind || task.due != nil
      else { throw StudyError.invalid("Công việc hoặc danh sách bước nhỏ không hợp lệ.") }
    }
    for card in state.cards {
      guard card.hasValidContent, (0...3650).contains(card.intervalDays),
        (1.3...3.0).contains(card.ease),
        (0...10_000_000).contains(card.reviews), (0...10_000_000).contains(card.repetitions),
        (0...10_000_000).contains(card.lapses), (0...1).contains(card.learningStep)
      else {
        throw StudyError.invalid("Dữ liệu ôn tập không hợp lệ.")
      }
    }
    for session in state.sessions {
      guard (60...14400).contains(session.plannedSeconds),
        session.segments.allSatisfy({ $0.end >= $0.start }),
        session.segments.reduce(0, { $0 + $1.seconds }) <= session.plannedSeconds + 1
      else {
        throw StudyError.invalid("Phiên tập trung không hợp lệ.")
      }
      for pair in zip(session.segments, session.segments.dropFirst())
      where pair.1.start < pair.0.end {
        throw StudyError.invalid("Các khoảng tập trung bị chồng chéo.")
      }
    }
    if let active = state.activeFocus {
      guard (60...14400).contains(active.plannedSeconds),
        active.savedSeconds <= active.plannedSeconds + 1,
        active.segments.allSatisfy({ $0.end >= $0.start }),
        !state.sessions.contains(where: { $0.id == active.id })
      else { throw StudyError.invalid("Đồng hồ tập trung không hợp lệ.") }
      for pair in zip(active.segments, active.segments.dropFirst()) where pair.1.start < pair.0.end
      {
        throw StudyError.invalid("Phiên đang chạy có khoảng trùng nhau.")
      }
      if let running = active.runningSince, let last = active.segments.last, running < last.end {
        throw StudyError.invalid("Mốc tiếp tục phiên không hợp lệ.")
      }
    }
    guard (1...240).contains(state.preferences.dailyFocusMinutes),
      (1...100).contains(state.preferences.newCardsPerDay),
      (1...120).contains(state.preferences.focusMinutes),
      (1...30).contains(state.preferences.breakMinutes),
      (1...100).contains(state.preferences.dailyReviewGoal)
    else {
      throw StudyError.invalid("Thiết lập trong bản sao lưu không hợp lệ.")
    }
  }
}

/// The app owns this file. Widgets only read a separate, reduced snapshot.
struct DiskStore {
  let directory: URL
  var file: URL { directory.appendingPathComponent("mam-study.json") }
  var previous: URL { directory.appendingPathComponent("mam-study.previous.json") }
  var beforeRestore: URL { directory.appendingPathComponent("mam-study.before-restore.json") }
  func load() throws -> StudyState {
    guard FileManager.default.fileExists(atPath: file.path) else { return StudyState() }
    return try StateCodec.decode(Data(contentsOf: file))
  }
  func save(_ state: StudyState) throws {
    try StateCodec.validate(state)
    let data = try StateCodec.encode(state)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: file.path) {
      let old = try Data(contentsOf: file)
      // Never rotate invalid bytes into the known-good backup.
      _ = try StateCodec.decode(old)
      try old.write(to: previous, options: .atomic)
    }
    try data.write(to: file, options: .atomic)
  }
}

struct WidgetDeadline: Identifiable, Codable {
  var id: UUID
  var title: String
  var due: Date
  var isExam: Bool
}

struct WidgetSnapshot: Codable {
  var updatedAt: Date
  var lessons: [Lesson]
  var pendingTasks: Int
  var dueCards: Int
  var todayFocusMinutes: Int
  var goalMinutes: Int
  var currentStreak: Int? = nil
  var lastStudyDay: Date? = nil
  var deadlines: [WidgetDeadline]? = nil
}
